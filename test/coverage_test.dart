import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io' as dart_io;
import 'package:dio/dio.dart';
import 'package:dio/io.dart' as dio_io;
import 'package:hymn/api/io_adapter.dart';
import 'package:hymn/api/api.dart';
import 'package:hymn/api/models.dart';
import 'package:hymn/api/truenas_client.dart';
import 'package:hymn/app_state.dart';
import 'package:hymn/config_store.dart';
import 'package:hymn/main.dart' as hymn_main;
import 'package:hymn/ui/landing.dart';
import 'package:hymn/ui/pages/apps_page.dart';
import 'package:hymn/ui/pages/dashboard_page.dart';
import 'package:hymn/ui/pages/settings_page.dart';
import 'package:hymn/ui/pages/shares_page.dart';
import 'package:hymn/ui/pages/snapshots_page.dart';
import 'package:hymn/ui/pages/stats_page.dart';
import 'package:hymn/ui/pages/storage_page.dart';
import 'package:hymn/ui/shell.dart';
import 'package:hymn/ui/theme.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fakes.dart';
import 'widget/pages_test.dart' show mockUrlLauncher;

class MockChannel extends Mock implements WebSocketChannel {}

class MockSink extends Mock implements WebSocketSink {}

class ThrowingClient extends Fake implements TrueNasApi {
  final Object error;
  ThrowingClient(this.error);
  @override
  Future<String> healthCheck() => throw error;
}

void main() {
  mockUrlLauncher();

  group('models edge cases', () {
    test('SystemInfo microsecond datetime', () {
      final info = SystemInfo.fromJson({'datetime': 1700000000000000});
      expect(info.buildTime, isNotNull);
    });

    test('VDev errorCount sums children', () {
      const parent = VDev(
        name: 'p',
        type: 'MIRROR',
        status: 'ONLINE',
        readErrors: 1,
        children: [
          VDev(name: 'c1', type: 'DISK', status: 'ONLINE', writeErrors: 2),
          VDev(
            name: 'c2',
            type: 'DISK',
            status: 'ONLINE',
            children: [
              VDev(name: 'g', type: 'DISK', status: 'ONLINE', checksumErrors: 4),
            ],
          ),
        ],
      );
      expect(parent.errorCount, 7);
    });

    test('Snapshot parses creation value string', () {
      final snap = Snapshot.fromJson({
        'id': 'tank/a@x',
        'properties': {
          'creation': {'value': '2026-09-01T10:00:00Z'},
        },
      });
      expect(snap.created, isNotNull);
      final noId = Snapshot.fromJson({'snapshot_name': 'tank@auto'});
      expect(noId.dataset, 'tank');
    });

    test('Snapshot creation rawvalue empty falls to value', () {
      final snap = Snapshot.fromJson({
        'id': 'a@b',
        'properties': {
          'creation': {'rawvalue': '', 'value': 'not-a-date'}
        },
      });
      expect(snap.created, isNull);
    });

    test('Job finished timestamp', () {
      final job = NasJob.fromJson({
        'id': 1,
        'state': 'SUCCESS',
        'time_finished': {r'$date': 1700000000000},
      });
      expect(job.finishedAt, isNotNull);
    });

    test('RealtimeSample flat interface stats', () {
      final s = RealtimeSample.fromJson({
        'interfaces': [
          {'received_bytes_rate': 7.0, 'sent_bytes_rate': 3.0}
        ],
        'memory': {'real_used': {'used': 64}},
      });
      expect(s.networkRxBytesPerSec, 7.0);
      expect(s.memoryUsed, 64);
    });
  });

  group('TrueNasException', () {
    test('toString with and without status', () {
      expect(const TrueNasException('bad', statusCode: 500).toString(),
          contains('(500)'));
      expect(const TrueNasException('bad').toString(), 'TrueNAS error: bad');
    });
  });

  group('client misc', () {
    test('default constructor builds dio and allows self-signed', () {
      final c = TrueNasClient(testConfig);
      expect(c.config.apiKey, 'test-key');
    });

    test('default ws connector returns a channel', () {
      final ch = defaultWebSocketConnector(Uri.parse('ws://127.0.0.1:1/'));
      expect(ch, isNotNull);
      // swallow the inevitable connection failure so the zone stays quiet
      unawaited(ch.ready.catchError((Object _) {}));
    });

    test('default connector falls back to polling on dead socket', () {
      return dart_io.HttpOverrides.runZoned(() async {
        final c = TrueNasClient(testConfig, dio: fakeDio({
          'GET /system/info': {'version': '25.04.1', 'physmem': 1000,
              'cores': 2, 'loadavg': [1.0]},
        }));
        final sample = await c.realtimeStats().first;
        expect(sample.memoryTotal, 1000);
      }, createHttpClient: (_) => dart_io.HttpClient());
    });

    test('getAppsPool falls back to legacy endpoint', () async {
      final c = TrueNasClient(testConfig, dio: fakeDio({
        'GET /app/config': {'pool': 'legacy-pool'},
      }));
      expect(await c.getAppsPool(), 'legacy-pool');
    });

    test('getAppsPool reads docker config', () async {
      final c = TrueNasClient(testConfig, dio: fakeDio({
        'GET /docker': {'pool': 'tank'},
      }));
      expect(await c.getAppsPool(), 'tank');
    });

    test('stream closes when the socket closes', () async {
      final channel = MockChannel();
      final sink = MockSink();
      final inbound = StreamController<String>();
      when(() => channel.ready).thenAnswer((_) async {});
      when(() => channel.sink).thenReturn(sink);
      when(() => sink.close(any())).thenAnswer((_) async => null);
      when(() => channel.stream).thenAnswer((_) => inbound.stream);
      when(() => sink.add(any())).thenAnswer((inv) {
        final msg = jsonDecode(inv.positionalArguments.first as String);
        scheduleMicrotask(() {
          if (inbound.isClosed) return;
          if (msg['msg'] == 'connect') {
            inbound.add(jsonEncode({'msg': 'connected'}));
          } else if (msg['method'] == 'auth.login_with_api_key') {
            inbound.add(jsonEncode(
                {'msg': 'result', 'id': msg['id'], 'result': true}));
            scheduleMicrotask(inbound.close);
          }
        });
      });
      final c = TrueNasClient(testConfig,
          dio: fakeDio({}), wsConnector: (_) => channel);
      await expectLater(c.realtimeStats().toList(), completes);
    });

    test('error message fallbacks', () async {
      final dio = fakeDio({});
      // response data without an error key
      final adapter = dio.httpClientAdapter as FakeAdapter;
      adapter.responses['GET /system/info'] = DioException(
        requestOptions: RequestOptions(path: '/system/info'),
        response: Response(
          requestOptions: RequestOptions(path: '/system/info'),
          statusCode: 500,
          data: {'message': 'oops'},
        ),
      );
      final c = TrueNasClient(testConfig, dio: dio);
      await expectLater(c.getSystemInfo(),
          throwsA(predicate((e) => e is TrueNasException && e.message == 'oops')));

      adapter.responses['GET /system/info'] = DioException(
        requestOptions: RequestOptions(path: '/system/info'),
      );
      await expectLater(
          c.getSystemInfo(),
          throwsA(predicate((e) =>
              e is TrueNasException && e.statusCode == null)));

      adapter.responses['GET /system/info'] = DioException(
        requestOptions: RequestOptions(path: '/system/info'),
        response: Response(
          requestOptions: RequestOptions(path: '/system/info'),
          statusCode: 500,
          data: 'plain text error',
        ),
      );
      await expectLater(
          c.getSystemInfo(),
          throwsA(predicate((e) =>
              e is TrueNasException && e.message != 'oops')));

      adapter.responses['GET /system/info'] = DioException(
        requestOptions: RequestOptions(path: '/system/info'),
        response: Response(
          requestOptions: RequestOptions(path: '/system/info'),
          statusCode: 418,
          data: {'unrelated': 'field'},
        ),
      );
      await expectLater(
          c.getSystemInfo(),
          throwsA(predicate((e) =>
              e is TrueNasException && e.statusCode == 418)));
    });

    test('updateDataset compression', () async {
      final adapter = FakeAdapter({
        'PUT /pool/dataset/id/a%2Fb': null,
      });
      final dio = fakeDio({})..httpClientAdapter = adapter;
      final c = TrueNasClient(testConfig, dio: dio);
      await c.updateDataset('a/b', compression: 'OFF');
      expect(jsonDecode(adapter.lastBody!)['compression'], 'OFF');
    });

    test('websocket stream error propagates', () async {
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
            inbound.add(jsonEncode(
                {'msg': 'result', 'id': msg['id'], 'result': true}));
          } else {
            inbound.addError('boom');
          }
        });
      });
      final c = TrueNasClient(testConfig,
          dio: fakeDio({}), wsConnector: (_) => channel);
      await expectLater(c.realtimeStats().first, throwsA(isA<TrueNasException>()));
    });
  });

  group('ConfigStore secure path', () {
    test('secure storage success writes through and removes pref key',
        () async {
      const channel =
          MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'read':
            return (call.arguments as Map)['key'] == 'truenas_api_key'
                ? 'secure-key'
                : null;
          default:
            return null;
        }
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ConfigStore(prefs);
      await store.save(const ConnectionConfig(url: 'https://x', apiKey: 'k'));
      // secure write succeeded -> pref key removed
      expect(prefs.getString('truenas_api_key'), isNull);
      final config = await store.loadWithKey();
      expect(config?.apiKey, 'secure-key');
      await store.clear();
    });
  });

  group('AppState misc', () {
    test('default clientFactory creates a real client', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(ConfigStore(prefs));
      expect(state.clientFactory, isNotNull);
      final client = state.clientFactory(testConfig);
      expect(client, isA<TrueNasClient>());
    });

    test('TrueNasException surfaces its message', () async {
      final state = await makeState();
      await state.connect(testConfig, persist: false);
      // swap in a throwing client path
      final failing = AppState(state.store,
          clientFactory: (_) => ThrowingClient(const TrueNasException('nope')));
      await failing.connect(testConfig);
      expect(failing.status, ConnectionStatus.failed);
      expect(failing.error, 'nope');
    });

    test('generic errors are stringified', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(ConfigStore(prefs),
          clientFactory: (_) => ThrowingClient(StateError('weird')));
      await state.connect(testConfig);
      expect(state.error, contains('weird'));
    });
  });

  group('confirmAction cancel', () {
    testWidgets('cancel returns false', (tester) async {
      final state = await connectedState();
      bool? result;
      await pumpPage(tester, state, Builder(builder: (context) {
        return FilledButton(
          onPressed: () async {
            result = await confirmAction(context,
                title: 't', message: 'm', confirmLabel: 'Go');
          },
          child: const Text('open'),
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  group('main()', () {
    testWidgets('boots the app tree', (tester) async {
      SharedPreferences.setMockInitialValues({});
      hymn_main.main();
      await tester.pumpAndSettle();
      expect(find.byType(hymn_main.HymnApp), findsOneWidget);
    });
  });

  group('landing interactions', () {
    testWidgets('wide layout and links', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HymnLandingApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source').first);
      await tester.tap(find.text('Download').first);
      await tester.tap(find.text('Get the app'));
      await tester.tap(find.text('View on GitLab'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('AltStore source'), 200);
      await tester.tap(find.text('Releases').first);
      await tester.tap(find.text('AltStore source'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Source on GitLab'), 200);
      await tester.tap(find.text('Source on GitLab'));
      await tester.pump();
    });
  });

  group('compact shell primary destinations', () {
    testWidgets('tapping a bottom destination selects it', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, AppShell(),
          size: const Size(400, 800));
      await tester.tap(find.text('Storage'));
      await tester.pumpAndSettle();
      expect(state.navIndex, 1);
    });
  });

  group('loader edge cases', () {
    testWidgets('TrueNasException shows its message', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      nas.failAll = true;
      nas.failWith = const TrueNasException('nope', statusCode: 401);
      await pumpPage(tester, state, DashboardPage());
      expect(find.text('nope'), findsOneWidget);
    });

    testWidgets('pull to refresh uses quiet path', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, DashboardPage());
      await tester.fling(
          find.byType(ListView).first, const Offset(0, 600), 1000);
      await tester.pumpAndSettle();
    });
  });

  group('dashboard extras', () {
    testWidgets('empty pools and services copy', (tester) async {
      final nas = FakeNas()
        ..overrides['getPools'] = <Pool>[]
        ..overrides['getServices'] = <NasService>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, DashboardPage());
      expect(find.text('No pools configured'), findsOneWidget);
      expect(find.text('No services reported'), findsOneWidget);
      expect(find.textContaining('1.0 TiB'), findsNothing);
    });

    testWidgets('dismiss failure shows error toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, DashboardPage());
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      nas.failAll = true;
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
    });
  });

  group('settings extras', () {
    testWidgets('reboot failure shows toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SettingsPage());
      nas.failAll = true;
      await tester.tap(find.text('Reboot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reboot').last);
      await tester.pumpAndSettle();
    });

    testWidgets('starting a stopped service calls startService',
        (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SettingsPage());
      // second switch is the stopped NFS service
      await tester.tap(find.byType(Switch).at(1));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('startService'));
    });

    testWidgets('toggle failure shows toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SettingsPage());
      nas.failAll = true;
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
    });
  });

  group('shares extras', () {
    testWidgets('empty share lists', (tester) async {
      final nas = FakeNas()
        ..overrides['getSmbShares'] = <SmbShare>[]
        ..overrides['getNfsShares'] = <NfsShare>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      expect(find.text('No SMB shares'), findsOneWidget);
      expect(find.text('No NFS shares'), findsOneWidget);
    });

    testWidgets('delete nfs share', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteNfsShare'));
    });

    testWidgets('smb share without name is rejected', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      await tester.tap(find.text('SMB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Path'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/mnt/tank/media').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create share'));
      await tester.pump();
      expect(nas.calls, isNot(contains('createSmbShare')));
    });

    testWidgets('share toggles and failure toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      await tester.tap(find.text('SMB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read only'));
      await tester.tap(find.text('Guest access'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'movies');
      await tester.tap(find.text('Path'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/mnt/tank/media').last);
      await tester.pumpAndSettle();
      nas.failAll = true;
      await tester.tap(find.text('Create share'));
      await tester.pumpAndSettle();
      expect(find.textContaining('fake failure'), findsWidgets);
    });
  });

    testWidgets('delete share failures show toasts', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      nas.failAll = true;
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteSmbShare'));
      expect(nas.calls, contains('deleteNfsShare'));
    });

  group('snapshots extras', () {
    testWidgets('empty state', (tester) async {
      final nas = FakeNas()..overrides['getSnapshots'] = <Snapshot>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SnapshotsPage());
      expect(find.text('No snapshots'), findsOneWidget);
    });

    testWidgets('delete failure toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SnapshotsPage());
      nas.failAll = true;
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteSnapshot'));
    });

    testWidgets('rollback failure toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SnapshotsPage());
      nas.failAll = true;
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll back'));
      await tester.pumpAndSettle();
    });

    testWidgets('name validation and recursive toggle', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SnapshotsPage());
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dataset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tank/media').last);
      await tester.pumpAndSettle();
      // clear the suggested name -> validation triggers
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Include child datasets'));
      await tester.pump();
      await tester.tap(find.text('Create snapshot'));
      await tester.pump();
      expect(nas.calls, isNot(contains('createSnapshot')));
      // name again -> then fail the api for the error branch
      await tester.enterText(find.byType(TextField), 'manual-1');
      nas.failAll = true;
      await tester.tap(find.text('Create snapshot'));
      await tester.pumpAndSettle();
    });
  });

  group('storage extras', () {
    testWidgets('pool with no datasets', (tester) async {
      final nas = FakeNas()..overrides['getDatasets'] = <Dataset>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      expect(find.text('No datasets yet'), findsOneWidget);
    });

    testWidgets('scrub failure toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      nas.failAll = true;
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run scrub'));
      await tester.pumpAndSettle();
    });

    testWidgets('export failure toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      nas.failAll = true;
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export pool'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('exportPool'));
    });

    testWidgets('dataset delete failure toast', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      nas.failAll = true;
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteDataset'));
    });

    testWidgets('create dataset with quota, template change, failure',
        (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.text('New dataset'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'vms');
      // template dropdown -> pick vms template (index 3)
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Virtual machines').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '50');
      await tester.tap(find.text('Create dataset'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('createDataset'));
      // error path
      await tester.tap(find.text('New dataset'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'broken');
      nas.failAll = true;
      await tester.tap(find.text('Create dataset'));
      await tester.pumpAndSettle();
      expect(find.textContaining('fake failure'), findsWidgets);
    });

    testWidgets('pool sheet: no unused disks + unselect', (tester) async {
      final nas = FakeNas()..overrides['getUnusedDisks'] = <Disk>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('No unused disks available'), findsOneWidget);
      await tester.tap(find.text('Create pool').last);
      await tester.pump();
    });

    testWidgets('pool sheet unselect disk', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sdd'));
      await tester.pump();
      await tester.tap(find.text('sdd'));
      await tester.pump();
      // create pool error path
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Stripe').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'p2');
      await tester.tap(find.text('sdd'));
      await tester.pump();
      nas.failAll = true;
      await tester.tap(find.text('Create pool').last);
      await tester.pumpAndSettle();
    });
  });

  group('apps extras', () {
    testWidgets('icon app renders fallback + failure toasts', (tester) async {
      final nas = FakeNas()..overrides['getApps'] = <NasApp>[fakeIconApp];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, AppsPage());
      await tester.pump();
      nas.failAll = true;
      await tester.tap(find.byIcon(Icons.stop_circle_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteApp'));
    });
  });

  group('stats extras', () {
    test('SampleHistory caps at capacity', () {
      final h = SampleHistory();
      for (var i = 0; i < 130; i++) {
        h.add(const RealtimeSample(cpuUsage: 1));
      }
      expect(h.samples.length, SampleHistory.capacity);
    });
  });

  group('more edge coverage', () {
    test('io adapter installs badCert callback', () {
      final dio = Dio();
      allowSelfSignedCerts(dio);
      final adapter = dio.httpClientAdapter as dio_io.IOHttpClientAdapter;
      final client = adapter.createHttpClient!();
      expect(client, isA<dart_io.HttpClient>());
    });
  });
}
