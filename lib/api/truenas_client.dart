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
WebSocketChannel defaultWebSocketConnector(Uri uri) => connectWebSocket(uri);

class TrueNasClient implements TrueNasApi {
  final ConnectionConfig config;
  final Dio _dio;
  final WebSocketConnector _wsConnector;

  TrueNasClient(
    this.config, {
    Dio? dio,
    WebSocketConnector? wsConnector,
  })  : _dio = dio ?? _buildDio(config),
        _wsConnector = wsConnector ??
            ((uri) => connectWebSocket(uri,
                allowSelfSigned: config.allowSelfSigned));

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
        'restart_services': true,
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
    try {
      final config = await _request<Map<String, dynamic>>('GET', '/docker');
      return config['pool']?.toString();
    } on TrueNasException {
      // older SCALE releases expose this under app.config
      final config = await _request<Map<String, dynamic>>('GET', '/app/config');
      return config['pool']?.toString();
    }
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
        'app_name': name,
        'catalog_app': name,
        'catalog': catalog,
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
    StreamSubscription<dynamic>? subscription;
    try {
      channel = _wsConnector(Uri.parse(config.wsUrl));
      await channel.ready.timeout(const Duration(seconds: 10));
    } catch (_) {
      channel = null;
    }

    if (channel == null) {
      // Polling fallback: CPU from load average, which is the only realtime
      // figure system.info exposes. Memory and network stay zero rather than
      // showing fabricated numbers.
      while (true) {
        try {
          final info = await getSystemInfo();
          final load =
              info.loadAverage.isNotEmpty ? info.loadAverage.first : 0.0;
          final cpu = info.cores > 0
              ? (load / info.cores * 100).clamp(0.0, 100.0)
              : 0.0;
          yield RealtimeSample(
            cpuUsage: cpu.toDouble(),
            memoryTotal: info.physicalMemory,
          );
        } catch (_) {
          // transient failure, try again next tick
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      }
    }

    var id = 0;
    String nextId() => (++id).toString();
    final controller = StreamController<RealtimeSample>();
    final socket = channel;

    try {
      socket.sink.add(jsonEncode({
        'id': nextId(),
        'msg': 'connect',
        'version': '1',
        'support': ['1'],
      }));

      var authed = false;
      subscription = socket.stream.listen(
        (message) {
          try {
            final decoded =
                jsonDecode(message as String) as Map<String, dynamic>;
            final msg = decoded['msg'];
            if (msg == 'connected') {
              socket.sink.add(jsonEncode({
                'id': nextId(),
                'msg': 'method',
                'method': 'auth.login_with_api_key',
                'params': [config.apiKey],
              }));
            } else if (msg == 'result' && !authed) {
              if (decoded['error'] == null) {
                authed = true;
                socket.sink.add(jsonEncode({
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
        },
      );

      yield* controller.stream;
    } finally {
      await subscription?.cancel();
      unawaited(socket.sink.close());
    }
  }
}
