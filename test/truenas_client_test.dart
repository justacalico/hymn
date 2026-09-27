import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/api/truenas_client.dart';

import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fakes.dart';

class MockChannel extends Mock implements WebSocketChannel {}

class MockSink extends Mock implements WebSocketSink {}

TrueNasClient clientFor(Map<String, dynamic> responses,
    {WebSocketConnector? ws}) {
  return TrueNasClient(testConfig, dio: fakeDio(responses),
      wsConnector: ws ?? (_) => throw const SocketExceptionStub());
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

void main() {
  group('ConnectionConfig', () {
    test('normalizes url', () {
      expect(const ConnectionConfig(url: 'nas.local', apiKey: 'k').baseUrl,
          'https://nas.local');
      expect(
          const ConnectionConfig(url: 'http://nas.local/', apiKey: 'k').baseUrl,
          'http://nas.local');
      expect(
          const ConnectionConfig(url: 'https://nas.local/', apiKey: 'k').wsUrl,
          'wss://nas.local/api/current');
      expect(const ConnectionConfig(url: 'http://nas.local', apiKey: 'k').wsUrl,
          'ws://nas.local/api/current');
    });

    test('json round-trip', () {
      const c = ConnectionConfig(url: 'u', apiKey: 'k', allowSelfSigned: false);
      final back = ConnectionConfig.fromJson(c.toJson());
      expect(back.url, 'u');
      expect(back.allowSelfSigned, isFalse);
    });
  });

  group('REST endpoints', () {
    test('healthCheck returns version', () async {
      final c = clientFor({
        'GET /system/info': {'version': '25.04.1', 'hostname': 'nas'},
      });
      expect(await c.healthCheck(), '25.04.1');
    });

    test('healthCheck rejects versionless servers', () {
      final c = clientFor({'GET /system/info': {}});
      expect(c.healthCheck(), throwsA(isA<TrueNasException>()));
    });

    test('errors map to TrueNasException with message', () {
      final c = clientFor({});
      expect(
        c.getSystemInfo(),
        throwsA(predicate((e) =>
            e is TrueNasException &&
            e.statusCode == 404 &&
            e.message.contains('no fake'))),
      );
    });

    test('system info and version', () async {
      final c = clientFor({
        'GET /system/info': {'version': '1', 'hostname': 'h'},
        'GET /system/version': {'version': '25.04.1', 'buildtime': 'x'},
      });
      expect((await c.getSystemInfo()).hostname, 'h');
      expect((await c.getVersion()).buildTime, 'x');
    });

    test('power actions post to the right endpoints', () async {
      final adapter = FakeAdapter({
        'POST /system/reboot': null,
        'POST /system/shutdown': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      await c.reboot();
      await c.shutdown();
      expect(adapter.requests.map((r) => r.path),
          containsAll(['/system/reboot', '/system/shutdown']));
    });

    test('alerts list and dismiss', () async {
      final adapter = FakeAdapter({
        'GET /alert/list': [
          {'uuid': 'u1', 'level': 'WARNING', 'message': 'm'}
        ],
        'POST /alert/dismiss': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      expect((await c.getAlerts()).single.level, 'WARNING');
      await c.dismissAlert('u1');
      expect(adapter.lastBody, '"u1"');
    });

    test('jobs', () async {
      final c = clientFor({
        'GET /core/get_jobs': [
          {'id': 1, 'method': 'm', 'state': 'RUNNING'}
        ]
      });
      expect((await c.getJobs()).single.method, 'm');
    });

    test('pool CRUD', () async {
      final adapter = FakeAdapter({
        'GET /pool': [
          {'id': 1, 'name': 'tank', 'topology': {}}
        ],
        'POST /pool': null,
        'POST /pool/id/1/export': null,
        'POST /pool/id/1/scrub': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);

      expect((await c.getPools()).single.name, 'tank');
      await c.createPool(name: 'tank2', type: 'RAIDZ1', disks: ['sda', 'sdb', 'sdc']);
      final body = jsonDecode(adapter.lastBody!) as Map;
      expect(body['topology']['data'][0]['disks'], ['sda', 'sdb', 'sdc']);
      expect(body['topology']['data'][0]['type'], 'RAIDZ1');
      await c.exportPool(1, delete: true);
      expect(jsonDecode(adapter.lastBody!)['destroy'], true);
      await c.scrubPool(1);
    });

    test('dataset CRUD', () async {
      final adapter = FakeAdapter({
        'GET /pool/dataset': [
          {'id': 'tank/a', 'name': 'tank/a', 'pool': 'tank'}
        ],
        'POST /pool/dataset': null,
        'PUT /pool/dataset/id/tank%2Fa': null,
        'DELETE /pool/dataset/id/tank%2Fa': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);

      expect((await c.getDatasets()).single.name, 'tank/a');
      await c.createDataset(name: 'tank/a', compression: 'GZIP-9', shareType: 'SMB');
      final body = jsonDecode(adapter.lastBody!) as Map;
      expect(body['share_type'], 'SMB');
      await c.updateDataset('tank/a', comments: 'hi', quota: 5);
      expect(jsonDecode(adapter.lastBody!)['quota'], 5);
      await c.deleteDataset('tank/a', recursive: true);
      expect(jsonDecode(adapter.lastBody!)['recursive'], true);
    });

    test('disks', () async {
      final c = clientFor({
        'GET /disk': [
          {'name': 'sda'}
        ],
        'GET /disk/get_unused': [
          {'name': 'sdb'}
        ],
      });
      expect((await c.getDisks()).single.name, 'sda');
      expect((await c.getUnusedDisks()).single.name, 'sdb');
    });

    test('smb shares', () async {
      final adapter = FakeAdapter({
        'GET /sharing/smb': [
          {'id': 1, 'name': 'media', 'path': '/p'}
        ],
        'POST /sharing/smb': null,
        'DELETE /sharing/smb/id/1': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);

      expect((await c.getSmbShares()).single.name, 'media');
      await c.createSmbShare(path: '/p', name: 's', guestOk: true);
      final body = jsonDecode(adapter.lastBody!) as Map;
      expect(body['options']['guestok'], true);
      expect(body['purpose'], 'DEFAULT_SHARE');
      await c.deleteSmbShare(1);
    });

    test('nfs shares', () async {
      final adapter = FakeAdapter({
        'GET /sharing/nfs': [
          {'id': 2, 'path': '/p'}
        ],
        'POST /sharing/nfs': null,
        'DELETE /sharing/nfs/id/2': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      expect((await c.getNfsShares()).single.path, '/p');
      await c.createNfsShare(path: '/p', hosts: ['a'], networks: ['n']);
      final body = jsonDecode(adapter.lastBody!) as Map;
      expect(body['hosts'], ['a']);
      await c.deleteNfsShare(2);
    });

    test('snapshots', () async {
      final adapter = FakeAdapter({
        'GET /zfs/snapshot': [
          {'id': 'tank/a@s1', 'properties': {}}
        ],
        'POST /zfs/snapshot': null,
        'DELETE /zfs/snapshot/id/tank%2Fa%40s1': null,
        'POST /zfs/snapshot/id/tank%2Fa%40s1/rollback': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      expect((await c.getSnapshots(dataset: 'tank/a')).single.name, 's1');
      await c.createSnapshot(dataset: 'tank/a', name: 's2', recursive: true);
      expect(jsonDecode(adapter.lastBody!)['recursive'], true);
      await c.rollbackSnapshot('tank/a@s1');
      await c.deleteSnapshot('tank/a@s1');
    });

    test('apps', () async {
      final adapter = FakeAdapter({
        'GET /app': [
          {'id': 'plex', 'state': 'RUNNING'}
        ],
        'GET /app/available': [
          {'name': 'jellyfin'}
        ],
        'GET /app/categories': ['media'],
        'GET /app/config': {'pool': 'tank'},
        'PUT /docker': null,
        'POST /app': null,
        'POST /app/id/plex/start': null,
        'POST /app/id/plex/stop': null,
        'DELETE /app/id/plex': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      expect((await c.getApps()).single.id, 'plex');
      expect((await c.getAvailableApps()).single.name, 'jellyfin');
      expect(await c.getAppCategories(), ['media']);
      expect(await c.getAppsPool(), 'tank');
      await c.setAppsPool('tank');
      expect(jsonDecode(adapter.lastBody!)['pool'], 'tank');
      await c.installApp(
          name: 'n', catalog: 'TRUENAS', train: 'community', version: '1');
      expect(jsonDecode(adapter.lastBody!)['app_name'], 'n');
      expect(jsonDecode(adapter.lastBody!)['catalog_app'], 'n');
      await c.startApp('plex');
      await c.stopApp('plex');
      await c.deleteApp('plex');
      expect(jsonDecode(adapter.lastBody!)['remove_images'], true);
    });

    test('users and groups', () async {
      final adapter = FakeAdapter({
        'GET /user': [
          {'id': 7, 'username': 'u'}
        ],
        'POST /user': 1001,
        'PUT /user/id/7': null,
        'DELETE /user/id/7': null,
        'GET /group': [
          {'id': 3, 'name': 'g'}
        ],
        'POST /group': 2001,
        'DELETE /group/id/3': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      expect((await c.getUsers()).single.username, 'u');
      expect(
          await c.createUser(username: 'u', fullName: 'U', password: 'p'), 1001);
      expect(jsonDecode(adapter.lastBody!)['group_create'], true);
      await c.updateUser(7, fullName: 'N', locked: true);
      expect(jsonDecode(adapter.lastBody!)['locked'], true);
      await c.deleteUser(7, deleteGroup: true);
      expect((await c.getGroups()).single.name, 'g');
      expect(await c.createGroup('g2'), 2001);
      await c.deleteGroup(3, deleteUsers: true);
      expect(jsonDecode(adapter.lastBody!)['delete_users'], true);
    });

    test('services', () async {
      final adapter = FakeAdapter({
        'GET /service': [
          {'id': 1, 'service': 'cifs', 'state': 'RUNNING'}
        ],
        'POST /service/start': null,
        'POST /service/stop': null,
        'POST /service/restart': null,
        'PUT /service/id/cifs': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://nas.test/api/v2.0'))
        ..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      expect((await c.getServices()).single.service, 'cifs');
      await c.startService('nfs');
      expect(jsonDecode(adapter.lastBody!)['service'], 'nfs');
      await c.stopService('nfs');
      await c.restartService('nfs');
      await c.setServiceEnabled('cifs', false);
      expect(jsonDecode(adapter.lastBody!)['enable'], false);
    });
  });

  group('realtimeStats', () {
    test('streams samples over websocket', () async {
      final channel = MockChannel();
      final sink = MockSink();
      final inbound = StreamController<String>();
      addTearDown(inbound.close);

      when(() => channel.ready).thenAnswer((_) async {});
      when(() => channel.sink).thenReturn(sink);
      when(() => sink.close(any())).thenAnswer((_) async => null);
      when(() => channel.stream).thenAnswer((_) => inbound.stream);
      when(() => sink.add(any())).thenAnswer((inv) {
        final msg = jsonDecode(inv.positionalArguments.first as String);
        scheduleMicrotask(() {
          if (msg['msg'] == 'connect') {
            inbound.add(jsonEncode({'msg': 'connected', 'session': 's'}));
          } else if (msg['method'] == 'auth.login_with_api_key') {
            inbound.add(jsonEncode({'msg': 'result', 'id': msg['id'], 'result': true}));
          } else if (msg['method'] == 'core.subscribe') {
            inbound.add(jsonEncode({
              'msg': 'added',
              'collection': 'reporting.realtime',
              'fields': {
                'cpu': {'user': 12.0, 'system': 3.0},
                'memory': {
                  'physical': {'total': 1000, 'used': 400}
                },
                'interfaces': [
                  {'stats': {'received_bytes_rate': 10.0, 'sent_bytes_rate': 5.0}}
                ],
              },
            }));
          }
        });
      });

      final c = TrueNasClient(testConfig,
          dio: fakeDio({}), wsConnector: (_) => channel);
      final sample = await c.realtimeStats().first;
      expect(sample.cpuUsage, 15.0);
      expect(sample.memoryTotal, 1000);
      expect(sample.networkRxBytesPerSec, 10.0);
    });

    test('emits error when websocket auth fails', () async {
      final channel = MockChannel();
      final sink = MockSink();
      final inbound = StreamController<String>();
      addTearDown(inbound.close);
      when(() => channel.ready).thenAnswer((_) async {});
      when(() => channel.sink).thenReturn(sink);
      when(() => sink.close(any())).thenAnswer((_) async => null);
      when(() => channel.stream).thenAnswer((_) => inbound.stream);
      when(() => sink.add(any())).thenAnswer((inv) {
        final msg = jsonDecode(inv.positionalArguments.first as String);
        scheduleMicrotask(() {
          if (msg['msg'] == 'connect') {
            inbound.add(jsonEncode({'msg': 'connected'}));
          } else if (msg['method'] == 'auth.login_with_api_key') {
            inbound.add(jsonEncode({
              'msg': 'result',
              'id': msg['id'],
              'error': {'error': 401}
            }));
          }
        });
      });

      final c = TrueNasClient(testConfig,
          dio: fakeDio({}), wsConnector: (_) => channel);
      expect(c.realtimeStats().first, throwsA(isA<TrueNasException>()));
    });

    test('falls back to polling when socket fails', () async {
      final c = clientFor({
        'GET /system/info': {
          'version': '25.04.1',
          'physmem': 1000000,
          'cores': 4,
          'loadavg': [2.0],
        }
      });
      final sample = await c.realtimeStats().first;
      expect(sample.cpuUsage, 50.0);
      expect(sample.memoryTotal, 1000000);
      expect(sample.memoryUsed, 0);
    });

    test('polling tolerates transient failures', () async {
      final c = clientFor({});
      // getSystemInfo throws -> the loop yields nothing but stays alive.
      final sub = c.realtimeStats().listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      unawaited(sub.cancel());
      await Future<void>.delayed(Duration.zero);
    });
  });
}
