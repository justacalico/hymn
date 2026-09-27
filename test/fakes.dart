import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/api/api.dart';
import 'package:hymn/api/models.dart';
import 'package:hymn/api/truenas_client.dart' show ConnectionConfig;
import 'package:hymn/app_state.dart';
import 'package:hymn/config_store.dart';
import 'package:hymn/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testConfig = ConnectionConfig(
  url: 'https://nas.test',
  apiKey: 'test-key',
);

/// Fake TrueNAS API: returns canned fixture data, records calls, and can be
/// told to fail. Anything not stubbed falls through to [_defaults].
class FakeNas implements TrueNasApi {
  final List<String> calls = [];
  final Map<String, dynamic> overrides = {};
  bool failAll = false;
  Object? failWith;

  T _data<T>(String method, T fallback) {
    calls.add(method);
    if (failAll) throw failWith ?? TrueNasExceptionFake(method);
    return (overrides[method] as T?) ?? fallback;
  }

  Future<T> _future<T>(String method, T fallback) async =>
      _data(method, fallback);

  @override
  Future<String> healthCheck() => _future('healthCheck', 'TrueNAS-SCALE-25.04.1');

  @override
  Future<SystemInfo> getSystemInfo() => _future('getSystemInfo', fakeSystemInfo);

  @override
  Future<NasVersion> getVersion() =>
      _future('getVersion', const NasVersion(version: '25.04.1', buildTime: '2026-01-01'));

  @override
  Future<void> reboot() => _future('reboot', null);

  @override
  Future<void> shutdown() => _future('shutdown', null);

  @override
  Future<List<NasAlert>> getAlerts() =>
      _future('getAlerts', [fakeAlert, fakeDismissedAlert]);

  @override
  Future<void> dismissAlert(String uuid) => _future('dismissAlert', null);

  @override
  Future<List<NasJob>> getJobs() =>
      _future('getJobs', [fakeRunningJob, fakeDoneJob]);

  @override
  Future<List<Pool>> getPools() => _future('getPools', [fakePool]);

  @override
  Future<void> createPool({
    required String name,
    required String type,
    required List<String> disks,
    List<String> spareDisks = const [],
  }) =>
      _future('createPool', null);

  @override
  Future<void> exportPool(int id, {bool delete = false}) =>
      _future('exportPool', null);

  @override
  Future<void> scrubPool(int id) => _future('scrubPool', null);

  @override
  Future<List<Dataset>> getDatasets() =>
      _future('getDatasets', [fakeDataset, fakeDatasetChild]);

  @override
  Future<void> createDataset({
    required String name,
    String compression = 'LZ4',
    String shareType = 'GENERIC',
    String comments = '',
    int? quota,
    bool readonly = false,
  }) =>
      _future('createDataset', null);

  @override
  Future<void> updateDataset(String id,
          {String? comments, String? compression, int? quota}) =>
      _future('updateDataset', null);

  @override
  Future<void> deleteDataset(String id, {bool recursive = false}) =>
      _future('deleteDataset', null);

  @override
  Future<List<Disk>> getDisks() =>
      _future('getDisks', [fakeDisk, fakeUnusedDisk]);

  @override
  Future<List<Disk>> getUnusedDisks() =>
      _future('getUnusedDisks', [fakeUnusedDisk]);

  @override
  Future<List<SmbShare>> getSmbShares() =>
      _future('getSmbShares', [fakeSmbShare]);

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
      _future('createSmbShare', null);

  @override
  Future<void> deleteSmbShare(int id) => _future('deleteSmbShare', null);

  @override
  Future<List<NfsShare>> getNfsShares() =>
      _future('getNfsShares', [fakeNfsShare]);

  @override
  Future<void> createNfsShare({
    required String path,
    String comment = '',
    bool enabled = true,
    bool readOnly = false,
    List<String> networks = const [],
    List<String> hosts = const [],
  }) =>
      _future('createNfsShare', null);

  @override
  Future<void> deleteNfsShare(int id) => _future('deleteNfsShare', null);

  @override
  Future<List<Snapshot>> getSnapshots({String? dataset}) =>
      _future('getSnapshots', [fakeSnapshot]);

  @override
  Future<void> createSnapshot({
    required String dataset,
    required String name,
    bool recursive = false,
  }) =>
      _future('createSnapshot', null);

  @override
  Future<void> deleteSnapshot(String id) => _future('deleteSnapshot', null);

  @override
  Future<void> rollbackSnapshot(String id) => _future('rollbackSnapshot', null);

  @override
  Future<List<NasApp>> getApps() => _future('getApps', [fakeApp, fakeStoppedApp]);

  @override
  Future<List<AvailableApp>> getAvailableApps() =>
      _future('getAvailableApps', [fakeAvailableApp]);

  @override
  Future<List<String>> getAppCategories() =>
      _future('getAppCategories', ['media', 'utilities']);

  @override
  Future<String?> getAppsPool() => _future('getAppsPool', 'tank');

  @override
  Future<void> setAppsPool(String pool) => _future('setAppsPool', null);

  @override
  Future<void> installApp({
    required String name,
    required String catalog,
    required String train,
    required String version,
    Map<String, dynamic> values = const {},
  }) =>
      _future('installApp', null);

  @override
  Future<void> startApp(String id) => _future('startApp', null);

  @override
  Future<void> stopApp(String id) => _future('stopApp', null);

  @override
  Future<void> deleteApp(String id, {bool removeImages = true}) =>
      _future('deleteApp', null);

  @override
  Future<List<NasUser>> getUsers() =>
      _future('getUsers', [fakeUser, fakeBuiltinUser]);

  @override
  Future<int> createUser({
    required String username,
    required String fullName,
    required String password,
    String? email,
    bool smb = true,
    String home = '/var/empty',
    String shell = '/usr/sbin/nologin',
  }) =>
      _future('createUser', 1001);

  @override
  Future<void> updateUser(int id,
          {String? fullName,
          String? password,
          String? email,
          bool? smb,
          bool? locked}) =>
      _future('updateUser', null);

  @override
  Future<void> deleteUser(int id, {bool deleteGroup = false}) =>
      _future('deleteUser', null);

  @override
  Future<List<NasGroup>> getGroups() =>
      _future('getGroups', [fakeGroup]);

  @override
  Future<int> createGroup(String name, {bool smb = true}) =>
      _future('createGroup', 2001);

  @override
  Future<void> deleteGroup(int id, {bool deleteUsers = false}) =>
      _future('deleteGroup', null);

  @override
  Future<List<NasService>> getServices() =>
      _future('getServices', [fakeSmbService, fakeStoppedService]);

  @override
  Future<void> startService(String name) => _future('startService', null);

  @override
  Future<void> stopService(String name) => _future('stopService', null);

  @override
  Future<void> restartService(String name) => _future('restartService', null);

  @override
  Future<void> setServiceEnabled(String name, bool enabled) =>
      _future('setServiceEnabled', null);

  @override
  Stream<RealtimeSample> realtimeStats() {
    calls.add('realtimeStats');
    return Stream.value(fakeSample);
  }
}

class TrueNasExceptionFake implements Exception {
  final String method;
  TrueNasExceptionFake(this.method);
  @override
  String toString() => 'fake failure in $method';
}

// ---------------- fixtures ----------------

final fakeSystemInfo = SystemInfo(
  version: '25.04.1',
  hostname: 'nas.home',
  uptimeSeconds: 3661,
  loadAverage: const [0.42, 0.38, 0.31],
  physicalMemory: 16 * 1024 * 1024 * 1024,
  cores: 8,
  cpuModel: 'AMD Ryzen 5',
  timezone: 'UTC',
);

final fakePool = Pool(
  id: 1,
  name: 'tank',
  status: 'ONLINE',
  healthy: true,
  size: 8 * 1024 * 1024 * 1024 * 1024,
  allocated: 3 * 1024 * 1024 * 1024 * 1024,
  free: 5 * 1024 * 1024 * 1024 * 1024,
  dataVDevs: const [
    VDev(name: 'raidz1-0', type: 'RAIDZ1', status: 'ONLINE', disks: ['sda', 'sdb', 'sdc']),
  ],
);

const fakeDataset = Dataset(
  id: 'tank/media',
  name: 'tank/media',
  pool: 'tank',
  mountpoint: '/mnt/tank/media',
  used: 2 * 1024 * 1024 * 1024,
  available: 6 * 1024 * 1024 * 1024,
  compression: 'LZ4',
  shareType: 'SMB',
);

const fakeDatasetChild = Dataset(
  id: 'tank/backups',
  name: 'tank/backups',
  pool: 'tank',
  mountpoint: '/mnt/tank/backups',
  used: 1024 * 1024 * 1024,
  available: 7 * 1024 * 1024 * 1024,
  quota: 4 * 1024 * 1024 * 1024,
  compression: 'GZIP-9',
  shareType: 'GENERIC',
);

const fakeDisk = Disk(
  name: 'sda',
  identifier: '{serial}ABC',
  size: 4 * 1024 * 1024 * 1024 * 1024,
  model: 'WDC WD40EFRX',
  serial: 'ABC123',
  type: 'HDD',
  rotationRate: 5400,
  pool: 'tank',
  bus: 'SATA',
  smartEnabled: true,
);

const fakeUnusedDisk = Disk(
  name: 'sdd',
  identifier: '{serial}DEF',
  size: 4 * 1024 * 1024 * 1024 * 1024,
  model: 'Samsung 870',
  serial: 'DEF456',
  type: 'SSD',
  pool: null,
  bus: 'SATA',
);

const fakeSmbShare = SmbShare(
  id: 1,
  name: 'media',
  path: '/mnt/tank/media',
  comment: 'Movies and shows',
  enabled: true,
  readOnly: false,
  browsable: true,
  guestOk: false,
);

const fakeNfsShare = NfsShare(
  id: 2,
  path: '/mnt/tank/backups',
  comment: 'Backup target',
  enabled: true,
  readOnly: false,
  networks: ['192.168.1.0/24'],
  hosts: ['workstation'],
);

final fakeSnapshot = Snapshot(
  id: 'tank/media@auto-2026-09-01',
  dataset: 'tank/media',
  name: 'auto-2026-09-01',
  created: DateTime(2026, 9, 1, 12),
  referenced: 512 * 1024 * 1024,
);

const fakeApp = NasApp(
  id: 'plex',
  name: 'plex',
  state: 'RUNNING',
  version: '1.0.0',
  appVersion: '1.41.0',
  portals: ['http://nas.home:32400'],
);

const fakeStoppedApp = NasApp(
  id: 'immich',
  name: 'immich',
  state: 'STOPPED',
  version: '1.2.0',
);

const fakeIconApp = NasApp(
  id: 'paperless',
  name: 'paperless',
  state: 'RUNNING',
  version: '2.0.0',
  iconUrl: 'https://invalid.invalid/icon.png',
);

const fakeAvailableApp = AvailableApp(
  name: 'jellyfin',
  title: 'Jellyfin',
  description: 'Media server',
  categories: ['media'],
  catalog: 'TRUENAS',
  train: 'community',
);

const fakeUser = NasUser(
  id: 7,
  uid: 1001,
  username: 'calico',
  fullName: 'Calico',
  email: 'c@example.com',
  builtin: false,
  smb: true,
  locked: false,
  home: '/var/empty',
  shell: '/usr/sbin/nologin',
);

const fakeBuiltinUser = NasUser(
  id: 1,
  uid: 0,
  username: 'root',
  fullName: 'root',
  builtin: true,
  smb: false,
  locked: false,
  home: '/root',
  shell: '/bin/bash',
);

const fakeGroup = NasGroup(
  id: 3,
  gid: 2001,
  name: 'media',
  builtin: false,
  smb: true,
  users: [1001],
);

const fakeSmbService = NasService(id: 1, service: 'cifs', enable: true, state: 'RUNNING');
const fakeStoppedService = NasService(id: 2, service: 'nfs', enable: false, state: 'STOPPED');

final fakeAlert = NasAlert(
  uuid: 'alert-1',
  level: 'WARNING',
  message: 'Pool tank is using over 80% capacity',
  source: 'system',
  datetime: DateTime(2026, 9, 20),
);

const fakeDismissedAlert = NasAlert(
  uuid: 'alert-2',
  level: 'INFO',
  message: 'Update available',
  source: 'system',
  dismissed: true,
);

final fakeRunningJob = NasJob(
  id: 10,
  method: 'pool.scrub',
  state: 'RUNNING',
  progress: 42,
  description: 'Scrubbing tank',
);

const fakeDoneJob = NasJob(
  id: 9,
  method: 'pool.dataset.create',
  state: 'SUCCESS',
  progress: 100,
);

const fakeSample = RealtimeSample(
  cpuUsage: 25.4,
  memoryTotal: 16 * 1024 * 1024 * 1024,
  memoryUsed: 8 * 1024 * 1024 * 1024,
  networkRxBytesPerSec: 1024 * 1024,
  networkTxBytesPerSec: 512 * 1024,
  diskReadBytesPerSec: 2 * 1024 * 1024,
  diskWriteBytesPerSec: 1024 * 1024,
);

// ---------------- test harness ----------------

Future<AppState> makeState({FakeNas? nas, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  final store = ConfigStore(instance);
  final fake = nas ?? FakeNas();
  final state = AppState(store, clientFactory: (_) => fake);
  await state.bootstrap();
  return state;
}

Future<AppState> connectedState({FakeNas? nas}) async {
  final fake = nas ?? FakeNas();
  final state = await makeState(nas: fake);
  await state.connect(testConfig, persist: false);
  return state;
}

Widget harness(
  AppState state,
  Widget child, {
  Size size = const Size(1280, 800),
}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: HymnTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// Pumps [child] inside the harness and settles loaders.
Future<void> pumpPage(
  WidgetTester tester,
  AppState state,
  Widget child, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(harness(state, child, size: size));
  await tester.pumpAndSettle();
}

// ---------------- fake HTTP adapter ----------------

/// Dio adapter that replays canned responses keyed on "METHOD /path".
class FakeAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responses;
  final List<RequestOptions> requests = [];

  FakeAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    // Drain the request body so callers can inspect it via [lastBody].
    if (requestStream != null) {
      _lastBody = await utf8.decodeStream(requestStream);
    } else {
      _lastBody = null;
    }
    final key = '${options.method} ${options.path}';
    if (!responses.containsKey(key)) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 404,
          data: {'error': 'no fake for $key'},
        ),
      );
    }
    final value = responses[key];
    if (value is Exception) throw value;
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String? _lastBody;
  String? get lastBody => _lastBody;

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(Map<String, dynamic> responses) {
  final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'));
  dio.httpClientAdapter = FakeAdapter(responses);
  return dio;
}
