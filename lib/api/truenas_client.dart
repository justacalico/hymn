/// TrueNAS SCALE API client.
///
/// Talks directly to the NAS over its REST API (`/api/v2.0`) using an API
/// key for authentication. There is no backend in the middle: the phone or
/// desktop app is the client. A websocket channel (`/api/current`) carries
/// the live `reporting.realtime` stream for the dashboard and stats pages.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'io_adapter_stub.dart' if (dart.library.io) 'io_adapter.dart';
import 'models.dart';

class TrueNasException implements Exception {
  final String message;
  final int? statusCode;

  const TrueNasException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null
      ? 'TrueNAS error ($statusCode): $message'
      : 'TrueNAS error: $message';
}

/// Connection settings entered on the onboarding screen.
class ConnectionConfig {
  final String url;
  final String apiKey;
  final bool allowSelfSigned;

  const ConnectionConfig({
    required this.url,
    required this.apiKey,
    this.allowSelfSigned = true,
  });

  /// Normalized base URL without a trailing slash.
  String get baseUrl {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  String get wsUrl {
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return 'wss://${base.substring(8)}/api/current';
    }
    return 'ws://${base.substring(7)}/api/current';
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'allowSelfSigned': allowSelfSigned,
      };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) =>
      ConnectionConfig(
        url: json['url']?.toString() ?? '',
        apiKey: '',
        allowSelfSigned: json['allowSelfSigned'] != false,
      );
}

/// Callback used to substitute the websocket factory in tests.
typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

/// Default websocket connector; a top-level function so tests can invoke it
/// without opening a real socket.
WebSocketChannel defaultWebSocketConnector(Uri uri) =>
    WebSocketChannel.connect(uri);

class TrueNasClient implements TrueNasApi {
  final ConnectionConfig config;
  final Dio _dio;
  final WebSocketConnector _wsConnector;

  TrueNasClient(
    this.config, {
    Dio? dio,
    this._wsConnector = defaultWebSocketConnector,
  }) : _dio = dio ?? _buildDio(config);

  static Dio _buildDio(ConnectionConfig config) {
    final dio = Dio(BaseOptions(
      baseUrl: '${config.baseUrl}/api/v2.0',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
      },
    ));
    if (config.allowSelfSigned) {
      allowSelfSignedCerts(dio);
    }
    return dio;
  }

  Future<T> _request<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return response.data as T;
    } on DioException catch (e) {
      throw TrueNasException(
        e.response?.data is Map
            ? (e.response!.data['error']?.toString() ??
                e.response!.data['message']?.toString() ??
                e.message ??
                'request failed')
            : e.message ?? 'request failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<List<dynamic>> _get(String path,
          {Map<String, dynamic>? query}) async =>
      _request<List<dynamic>>('GET', path, query: query);

  /// Checks connectivity and credentials. Returns the system version.
  @override
  Future<String> healthCheck() async {
    final info = await getSystemInfo();
    if (info.version.isEmpty) {
      throw const TrueNasException('server did not report a version');
    }
    return info.version;
  }

  // System

  @override
  Future<SystemInfo> getSystemInfo() async =>
      SystemInfo.fromJson(await _request('GET', '/system/info'));

  @override
  Future<NasVersion> getVersion() async =>
      NasVersion.fromJson(await _request('GET', '/system/version'));

  @override
  Future<void> reboot() => _request('POST', '/system/reboot');

  @override
  Future<void> shutdown() => _request('POST', '/system/shutdown');

  // Alerts

  @override
  Future<List<NasAlert>> getAlerts() async =>
      (await _get('/alert/list')).map((a) => NasAlert.fromJson(a)).toList();

  @override
  Future<void> dismissAlert(String uuid) =>
      _request('POST', '/alert/dismiss', body: jsonEncode(uuid));

  // Jobs

  @override
  Future<List<NasJob>> getJobs() async =>
      (await _get('/core/get_jobs')).map((j) => NasJob.fromJson(j)).toList();

  // Pools

  @override
  Future<List<Pool>> getPools() async =>
      (await _get('/pool')).map((p) => Pool.fromJson(p)).toList();

  @override
  Future<void> createPool({
    required String name,
    required String type,
    required List<String> disks,
    List<String> spareDisks = const [],
  }) =>
      _request('POST', '/pool', body: {
        'name': name,
        'encryption': false,
        'topology': {
          'data': [
            {'type': type, 'disks': disks}
          ],
          'spare': spareDisks,
        },
      });

  @override
  Future<void> exportPool(int id, {bool delete = false}) =>
      _request('POST', '/pool/id/$id/export', body: {
        'cascade': true,
        'destroy': delete,
        'restart_services': false,
      });

  @override
  Future<void> scrubPool(int id) =>
      _request('POST', '/pool/id/$id/scrub', body: {});

  // Datasets

  @override
  Future<List<Dataset>> getDatasets() async =>
      (await _get('/pool/dataset')).map((d) => Dataset.fromJson(d)).toList();

  @override
  Future<void> createDataset({
    required String name,
    String compression = 'LZ4',
    String shareType = 'GENERIC',
    String comments = '',
    int? quota,
    bool readonly = false,
  }) =>
      _request('POST', '/pool/dataset', body: {
        'name': name,
        'type': 'FILESYSTEM',
        'comments': comments,
        'compression': compression,
        'quota': quota,
        'readonly': readonly,
        'share_type': shareType,
      });

  @override
  Future<void> updateDataset(String id,
          {String? comments, String? compression, int? quota}) =>
      _request('PUT', '/pool/dataset/id/${Uri.encodeComponent(id)}', body: {
        'comments': ?comments,
        'compression': ?compression,
        'quota': ?quota,
      });

  @override
  Future<void> deleteDataset(String id, {bool recursive = false}) => _request(
        'DELETE',
        '/pool/dataset/id/${Uri.encodeComponent(id)}',
        body: {'recursive': recursive},
      );

  // Disks

  @override
  Future<List<Disk>> getDisks() async =>
      (await _get('/disk')).map((d) => Disk.fromJson(d)).toList();

  @override
  Future<List<Disk>> getUnusedDisks() async =>
      (await _get('/disk/get_unused')).map((d) => Disk.fromJson(d)).toList();

  // Shares

  @override
  Future<List<SmbShare>> getSmbShares() async =>
      (await _get('/sharing/smb')).map((s) => SmbShare.fromJson(s)).toList();

  @override
  Future<void> createSmbShare({
    required String path,
    required String name,
    String comment = '',
    bool enabled = true,
    bool readOnly = false,
    bool browsable = true,
    bool guestOk = false,
  }) =>
      _request('POST', '/sharing/smb', body: {
        'path': path,
        'name': name,
        'comment': comment,
        'enabled': enabled,
        'ro': readOnly,
        'browsable': browsable,
        'purpose': 'DEFAULT_SHARE',
        'options': {'guestok': guestOk},
      });

  @override
  Future<void> deleteSmbShare(int id) =>
      _request('DELETE', '/sharing/smb/id/$id');

  @override
  Future<List<NfsShare>> getNfsShares() async =>
      (await _get('/sharing/nfs')).map((s) => NfsShare.fromJson(s)).toList();

  @override
  Future<void> createNfsShare({
    required String path,
    String comment = '',
    bool enabled = true,
    bool readOnly = false,
    List<String> networks = const [],
    List<String> hosts = const [],
  }) =>
      _request('POST', '/sharing/nfs', body: {
        'path': path,
        'comment': comment,
        'enabled': enabled,
        'ro': readOnly,
        'networks': networks,
        'hosts': hosts,
      });

  @override
  Future<void> deleteNfsShare(int id) =>
      _request('DELETE', '/sharing/nfs/id/$id');

  // Snapshots

  @override
  Future<List<Snapshot>> getSnapshots({String? dataset}) async =>
      (await _get('/zfs/snapshot', query: {
        'limit': 0,
        'dataset': ?dataset,
      }))
          .map((s) => Snapshot.fromJson(s))
          .toList();

  @override
  Future<void> createSnapshot({
    required String dataset,
    required String name,
    bool recursive = false,
  }) =>
      _request('POST', '/zfs/snapshot', body: {
        'dataset': dataset,
        'name': name,
        'recursive': recursive,
      });

  @override
  Future<void> deleteSnapshot(String id) => _request(
      'DELETE', '/zfs/snapshot/id/${Uri.encodeComponent(id)}');

  @override
  Future<void> rollbackSnapshot(String id) => _request(
      'POST', '/zfs/snapshot/id/${Uri.encodeComponent(id)}/rollback');

  // Apps

  @override
  Future<List<NasApp>> getApps() async =>
      (await _get('/app')).map((a) => NasApp.fromJson(a)).toList();

  @override
  Future<List<AvailableApp>> getAvailableApps() async =>
      (await _get('/app/available'))
          .map((a) => AvailableApp.fromJson(a))
          .toList();

  @override
  Future<List<String>> getAppCategories() async =>
      (await _get('/app/categories')).map((c) => c.toString()).toList();

  @override
  Future<String?> getAppsPool() async {
    final config = await _request<Map<String, dynamic>>('GET', '/app/config');
    return config['pool']?.toString();
  }

  @override
  Future<void> setAppsPool(String pool) =>
      _request('PUT', '/docker', body: {'pool': pool});

  @override
  Future<void> installApp({
    required String name,
    required String catalog,
    required String train,
    required String version,
    Map<String, dynamic> values = const {},
  }) =>
      _request('POST', '/app', body: {
        'catalog': catalog,
        'item': name,
        'train': train,
        'version': version,
        'values': values,
      });

  @override
  Future<void> startApp(String id) =>
      _request('POST', '/app/id/$id/start');

  @override
  Future<void> stopApp(String id) =>
      _request('POST', '/app/id/$id/stop');

  @override
  Future<void> deleteApp(String id, {bool removeImages = true}) =>
      _request('DELETE', '/app/id/$id',
          body: {'remove_images': removeImages, 'remove_ix_volumes': true});

  // Users & groups

  @override
  Future<List<NasUser>> getUsers() async =>
      (await _get('/user')).map((u) => NasUser.fromJson(u)).toList();

  @override
  Future<int> createUser({
    required String username,
    required String fullName,
    required String password,
    String? email,
    bool smb = true,
    String home = '/var/empty',
    String shell = '/usr/sbin/nologin',
  }) async {
    final id = await _request<int>('POST', '/user', body: {
      'username': username,
      'full_name': fullName,
      'password': password,
      'email': email,
      'group_create': true,
      'groups': <int>[],
      'home': home,
      'shell': shell,
      'smb': smb,
      'locked': false,
      'password_disabled': false,
    });
    return id;
  }

  @override
  Future<void> updateUser(int id,
          {String? fullName,
          String? password,
          String? email,
          bool? smb,
          bool? locked}) =>
      _request('PUT', '/user/id/$id', body: {
        'full_name': ?fullName,
        'password': ?password,
        'email': ?email,
        'smb': ?smb,
        'locked': ?locked,
      });

  @override
  Future<void> deleteUser(int id, {bool deleteGroup = false}) =>
      _request('DELETE', '/user/id/$id', body: {'delete_group': deleteGroup});

  @override
  Future<List<NasGroup>> getGroups() async =>
      (await _get('/group')).map((g) => NasGroup.fromJson(g)).toList();

  @override
  Future<int> createGroup(String name, {bool smb = true}) async =>
      _request<int>('POST', '/group', body: {'name': name, 'smb': smb});

  @override
  Future<void> deleteGroup(int id, {bool deleteUsers = false}) =>
      _request('DELETE', '/group/id/$id', body: {'delete_users': deleteUsers});

  // Services

  @override
  Future<List<NasService>> getServices() async =>
      (await _get('/service')).map((s) => NasService.fromJson(s)).toList();

  @override
  Future<void> startService(String name) =>
      _request('POST', '/service/start', body: {'service': name});

  @override
  Future<void> stopService(String name) =>
      _request('POST', '/service/stop', body: {'service': name});

  @override
  Future<void> restartService(String name) =>
      _request('POST', '/service/restart', body: {'service': name});

  @override
  Future<void> setServiceEnabled(String name, bool enabled) =>
      _request('PUT', '/service/id/$name', body: {'enable': enabled});

  /// Streams `reporting.realtime` samples over the TrueNAS websocket API.
  /// Falls back to polling [getSystemInfo] when the socket cannot be opened.
  @override
  Stream<RealtimeSample> realtimeStats() async* {
    WebSocketChannel? channel;
    try {
      channel = _wsConnector(Uri.parse(config.wsUrl));
      await channel.ready;
    } catch (_) {
      channel = null;
    }

    if (channel == null) {
      // Polling fallback: approximate from load average like the original app.
      while (true) {
        try {
          final info = await getSystemInfo();
          final load =
              info.loadAverage.isNotEmpty ? info.loadAverage.first : 0.0;
          final cpu = info.cores > 0
              ? (load / info.cores * 100).clamp(0.0, 100.0)
              : 0.0;
          final usedPct = info.cores > 0
              ? (0.3 + load / info.cores * 0.3).clamp(0.0, 0.9)
              : 0.3;
          yield RealtimeSample(
            cpuUsage: cpu.toDouble(),
            memoryTotal: info.physicalMemory,
            memoryUsed: (info.physicalMemory * usedPct).round(),
          );
        } catch (_) {
          // transient failure, try again next tick
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }

    var id = 0;
    String nextId() => (++id).toString();
    final completer = Completer<void>();
    final controller = StreamController<RealtimeSample>();

    channel.sink.add(jsonEncode({
      'id': nextId(),
      'msg': 'connect',
      'version': '1',
      'support': ['1'],
    }));

    var authed = false;
    channel.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          final msg = decoded['msg'];
          if (msg == 'connected') {
            channel!.sink.add(jsonEncode({
              'id': nextId(),
              'msg': 'method',
              'method': 'auth.login_with_api_key',
              'params': [config.apiKey],
            }));
          } else if (msg == 'result' && !authed) {
            if (decoded['error'] == null) {
              authed = true;
              channel!.sink.add(jsonEncode({
                'id': nextId(),
                'msg': 'method',
                'method': 'core.subscribe',
                'params': ['reporting.realtime'],
              }));
            } else {
              controller.addError(const TrueNasException(
                  'websocket authentication failed'));
            }
          } else if ((msg == 'added' || msg == 'changed') &&
              decoded['collection'] == 'reporting.realtime') {
            final fields = decoded['fields'];
            if (fields is Map<String, dynamic>) {
              controller.add(RealtimeSample.fromJson(fields));
            }
          }
        } catch (_) {
          // ignore malformed frames
        }
      },
      onError: (Object e) =>
          controller.addError(TrueNasException('websocket error: $e')),
      onDone: () {
        if (!controller.isClosed) controller.close();
        if (!completer.isCompleted) completer.complete();
      },
    );

    yield* controller.stream;
  }
}
