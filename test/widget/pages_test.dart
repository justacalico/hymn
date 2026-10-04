import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/api/models.dart';
import 'package:hymn/app_state.dart';
import 'package:hymn/ui/pages/apps_page.dart';
import 'package:hymn/ui/pages/dashboard_page.dart';
import 'package:hymn/ui/pages/disks_page.dart';
import 'package:hymn/ui/pages/onboarding_page.dart';
import 'package:hymn/ui/pages/settings_page.dart';
import 'package:hymn/ui/pages/shares_page.dart';
import 'package:hymn/ui/pages/snapshots_page.dart';
import 'package:hymn/ui/pages/stats_page.dart';
import 'package:hymn/ui/pages/storage_page.dart';

import '../fakes.dart';

void mockUrlLauncher() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final name in const [
    'plugins.flutter.io/url_launcher',
    'plugins.flutter.io/url_launcher_linux',
    'plugins.flutter.io/url_launcher_windows',
    'plugins.flutter.io/url_launcher_macos',
    'plugins.flutter.io/url_launcher_android',
    'plugins.flutter.io/url_launcher_ios',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(name), (call) async => true);
  }
}

void main() {
  mockUrlLauncher();

  group('OnboardingPage', () {
    testWidgets('validates empty fields', (tester) async {
      final state = await makeState();
      await pumpPage(tester, state, OnboardingPage());
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the server address'), findsOneWidget);
      expect(find.text('Enter the API key'), findsOneWidget);
    });

    testWidgets('connects with url and key', (tester) async {
      final state = await makeState();
      await pumpPage(tester, state, OnboardingPage());
      await tester.enterText(
          find.byType(TextFormField).first, 'https://nas.home');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'my-api-key');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(state.status, ConnectionStatus.connected);
      expect(state.client, isNotNull);
    });

    testWidgets('shows error on failed connect', (tester) async {
      final nas = FakeNas()..failAll = true;
      final state = await makeState(nas: nas);
      await pumpPage(tester, state, OnboardingPage());
      await tester.enterText(
          find.byType(TextFormField).first, 'https://nas.home');
      await tester.enterText(find.byType(TextFormField).at(1), 'bad-key');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(state.status, ConnectionStatus.failed);
      expect(find.textContaining('fake failure'), findsOneWidget);
    });

    testWidgets('obscure and self-signed toggles work', (tester) async {
      final state = await makeState();
      await pumpPage(tester, state, OnboardingPage());
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      await tester.tap(find.text('Allow self-signed certificates'));
      await tester.pump();
    });
  });

  group('DashboardPage', () {
    testWidgets('renders stat cards and panels', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, DashboardPage());
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Storage pools'), findsOneWidget);
      expect(find.text('Total storage'), findsOneWidget);
      expect(find.text('Shares'), findsOneWidget);
      expect(find.text('Uptime'), findsOneWidget);
      expect(find.text('tank'), findsWidgets);
      expect(find.text('CPU'), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('alerts banner opens dismiss sheet', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, DashboardPage());
      expect(find.textContaining('active alert'), findsOneWidget);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('Pool tank is using over 80% capacity'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
    });

    testWidgets('no alerts hides banner', (tester) async {
      final nas = FakeNas()..overrides['getAlerts'] = <NasAlert>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, DashboardPage());
      expect(find.textContaining('active alert'), findsNothing);
    });

    testWidgets('failed load shows empty state with retry', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      nas.failAll = true;
      await pumpPage(tester, state, DashboardPage());
      expect(find.text('Could not load data'), findsOneWidget);
      nas.failAll = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
    });

    testWidgets('compact layout stacks cards', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, DashboardPage(),
          size: const Size(400, 900));
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });

  group('DisksPage', () {
    testWidgets('lists disks with usage status', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, DisksPage());
      expect(find.text('Disks'), findsOneWidget);
      expect(find.text('sda'), findsOneWidget);
      expect(find.text('sdd'), findsOneWidget);
      expect(find.textContaining('WDC WD40EFRX'), findsOneWidget);
      expect(find.textContaining('S/N ABC123'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final nas = FakeNas()..overrides['getDisks'] = <Disk>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, DisksPage());
      expect(find.text('No disks detected'), findsOneWidget);
    });
  });

  group('StoragePage', () {
    testWidgets('renders pool with datasets', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, StoragePage());
      expect(find.text('tank'), findsOneWidget);
      expect(find.textContaining('RAIDZ1'), findsWidgets);
      expect(find.text('media'), findsOneWidget);
      expect(find.text('backups'), findsOneWidget);
    });

    testWidgets('create dataset sheet validates and submits', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.text('New dataset'));
      await tester.pumpAndSettle();
      expect(find.text('New dataset in tank'), findsOneWidget);
      // empty name -> error toast
      await tester.tap(find.text('Create dataset'));
      await tester.pump();
      expect(nas.calls, isNot(contains('createDataset')));
      await tester.enterText(
          find.byType(TextField).first, 'photos');
      await tester.tap(find.text('Create dataset'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('createDataset'));
    });

    testWidgets('create pool flow', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(find.text('Create pool'), findsWidgets);
      // submit without name
      await tester.tap(find.text('Create pool').last);
      await tester.pump();
      expect(nas.calls, isNot(contains('createPool')));
      await tester.enterText(
          find.byType(TextField).first, 'tank2');
      // select the sdd checkbox (not enough for RAIDZ1)
      await tester.tap(find.text('sdd'));
      await tester.pump();
      await tester.tap(find.text('Create pool').last);
      await tester.pump();
      // RAIDZ1 needs 3 disks -> still rejected
      expect(nas.calls, isNot(contains('createPool')));
      // switch to STRIPE and resubmit
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Stripe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create pool').last);
      await tester.pumpAndSettle();
      expect(nas.calls, contains('createPool'));
    });

    testWidgets('scrub and export via pool menu', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run scrub'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('scrubPool'));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export pool'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('exportPool'));
    });

    testWidgets('delete dataset requires confirm', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Delete tank/media?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteDataset'));
    });

    testWidgets('empty pools show empty state', (tester) async {
      final nas = FakeNas()..overrides['getPools'] = <Pool>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, StoragePage());
      expect(find.text('No storage pools'), findsOneWidget);
    });
  });

  group('SharesPage', () {
    testWidgets('lists smb and nfs shares', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, SharesPage());
      expect(find.text('media'), findsOneWidget);
      expect(find.text('/mnt/tank/backups'), findsOneWidget);
      expect(find.textContaining('SMB / WINDOWS'), findsOneWidget);
    });

    testWidgets('create smb share', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      await tester.tap(find.text('SMB'));
      await tester.pumpAndSettle();
      // submit with nothing selected -> rejected
      await tester.tap(find.text('Create share'));
      await tester.pump();
      expect(nas.calls, isNot(contains('createSmbShare')));
      await tester.enterText(find.byType(TextField).first, 'movies');
      await tester.tap(find.text('Path'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/mnt/tank/media').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create share'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('createSmbShare'));
    });

    testWidgets('create nfs share', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      await tester.tap(find.text('NFS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Path'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/mnt/tank/media').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField).last, '192.168.1.0/24');
      await tester.tap(find.text('Create share'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('createNfsShare'));
    });

    testWidgets('delete smb share', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SharesPage());
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteSmbShare'));
    });
  });

  group('SnapshotsPage', () {
    testWidgets('lists grouped snapshots', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, SnapshotsPage());
      expect(find.text('auto-2026-09-01'), findsOneWidget);
      expect(find.textContaining('TANK/MEDIA'), findsWidgets);
    });

    testWidgets('create snapshot', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SnapshotsPage());
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create snapshot'));
      await tester.pump();
      expect(nas.calls, isNot(contains('createSnapshot')));
      await tester.tap(find.text('Dataset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tank/media').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create snapshot'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('createSnapshot'));
    });

    testWidgets('rollback and delete', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SnapshotsPage());
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Roll back'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('rollbackSnapshot'));
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteSnapshot'));
    });
  });

  group('AppsPage', () {
    testWidgets('lists installed apps and catalog', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, AppsPage());
      expect(find.text('plex'), findsOneWidget);
      expect(find.text('immich'), findsOneWidget);
      expect(find.text('Installed on pool tank'), findsOneWidget);
      expect(find.text('Jellyfin'), findsOneWidget);
    });

    testWidgets('stop, start and delete', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, AppsPage());
      // stop the running app (plex card)
      await tester.tap(find.byIcon(Icons.stop_circle_outlined).first);
      await tester.pumpAndSettle();
      expect(nas.calls, contains('stopApp'));
      // start stopped app
      await tester.tap(find.byIcon(Icons.play_circle_outline).first);
      await tester.pumpAndSettle();
      expect(nas.calls, contains('startApp'));
      // delete
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(nas.calls, contains('deleteApp'));
    });

    testWidgets('open portal launches url', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, AppsPage());
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pump();
    });

    testWidgets('empty catalog', (tester) async {
      final nas = FakeNas()
        ..overrides['getApps'] = <NasApp>[]
        ..overrides['getAvailableApps'] = <AvailableApp>[];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, AppsPage());
      expect(find.text('No apps installed'), findsOneWidget);
    });
  });

  group('StatsPage', () {
    testWidgets('renders live charts', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, StatsPage());
      await tester.pump();
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('CPU'), findsWidgets);
      expect(find.text('MEMORY'), findsOneWidget);
      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('DISK I/O'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Ryzen'), 200);
    });
  });

  group('SettingsPage', () {
    testWidgets('shows server info and services', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, SettingsPage());
      expect(find.text('nas.home'), findsWidgets);
      expect(find.text('CIFS'), findsOneWidget);
      expect(find.text('NFS'), findsOneWidget);
      expect(find.text('Reboot'), findsOneWidget);
      expect(find.text('Shut down'), findsOneWidget);
    });

    testWidgets('service toggle calls api', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SettingsPage());
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(nas.calls, contains('stopService'));
    });

    testWidgets('reboot confirms then calls api', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SettingsPage());
      await tester.ensureVisible(find.text('Reboot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reboot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reboot').last);
      await tester.pumpAndSettle();
      expect(nas.calls, contains('reboot'));
    });

    testWidgets('shutdown confirms then calls api', (tester) async {
      final nas = FakeNas();
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, SettingsPage());
      await tester.ensureVisible(find.text('Shut down'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shut down'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shut down').last);
      await tester.pumpAndSettle();
      expect(nas.calls, contains('shutdown'));
    });

    testWidgets('theme segmented control', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, SettingsPage());
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(state.theme, ThemeSetting.dark);
      await tester.tap(find.text('OLED'));
      await tester.pumpAndSettle();
      expect(state.theme, ThemeSetting.oled);
    });

    testWidgets('disconnect clears config', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, SettingsPage());
      await tester.scrollUntilVisible(find.text('Disconnect'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect').last);
      await tester.pumpAndSettle();
      expect(state.client, isNull);
    });
  });
}
