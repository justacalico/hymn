import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/app_state.dart';
import 'package:hymn/main.dart';
import 'package:hymn/ui/landing.dart';
import 'package:hymn/ui/pages/onboarding_page.dart';
import 'package:hymn/ui/shell.dart';
import 'package:hymn/ui/theme.dart';
import 'package:provider/provider.dart';

import '../fakes.dart';

void main() {
  group('HymnApp', () {
    testWidgets('shows spinner while booting', (tester) async {
      final notReady = await makeState();
      // A fresh, un-bootstrapped state has ready=false.
      final fresh = AppState(notReady.store, clientFactory: (_) => FakeNas());
      await tester.pumpWidget(buildAppForTest(fresh));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows onboarding when unconfigured', (tester) async {
      final state = await makeState();
      await tester.pumpWidget(buildAppForTest(state));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsOneWidget);
    });

    testWidgets('shows shell when connected', (tester) async {
      final state = await connectedState();
      await tester.pumpWidget(buildAppForTest(state));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('dark theme selection flips themeMode', (tester) async {
      final state = await makeState();
      await state.setTheme(ThemeSetting.dark);
      await tester.pumpWidget(buildAppForTest(state));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
      expect(app.themeMode, ThemeMode.dark);
      await state.setTheme(ThemeSetting.light);
      await tester.pump();
      final app2 = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
      expect(app2.themeMode, ThemeMode.light);
    });

    testWidgets('oled theme stays dark but paints true black', (tester) async {
      final state = await makeState();
      await state.setTheme(ThemeSetting.oled);
      await tester.pumpWidget(buildAppForTest(state));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
      expect(app.themeMode, ThemeMode.dark);
      expect(app.darkTheme!.scaffoldBackgroundColor, Colors.black);
      expect(app.darkTheme!.cardColor, HymnTheme.oledCard);
    });
  });

  group('AppShell', () {
    testWidgets('wide layout shows navigation rail', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, AppShell(),
          size: const Size(1400, 900));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('compact layout shows bottom nav with More', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, AppShell(),
          size: const Size(400, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      // Open the More sheet and jump to Users.
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Users'), findsOneWidget);
      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();
      expect(state.navIndex, 6);
    });

    testWidgets('tapping rail switches pages without losing state',
        (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, AppShell(),
          size: const Size(1400, 900));
      await tester.tap(find.text('Disks'));
      await tester.pumpAndSettle();
      expect(state.navIndex, 2);
      expect(find.text('sda'), findsWidgets);
    });
  });

  group('landing page', () {
    testWidgets('renders product page on web', (tester) async {
      await tester.pumpWidget(HymnLandingApp());
      await tester.pumpAndSettle();
      expect(find.text('Hymn'), findsWidgets);
      expect(find.textContaining('without the'), findsOneWidget);
      expect(find.text('What it does'), findsOneWidget);
      expect(find.text('Get it'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.text('iOS'), findsOneWidget);
      expect(find.text('Linux'), findsOneWidget);
    });

    testWidgets('compact layout still works', (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HymnLandingApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('control panel'), findsOneWidget);
    });
  });
}

Widget buildAppForTest(AppState state) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: const HymnApp(),
  );
}
