import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/api/models.dart';
import 'package:hymn/ui/landing.dart';
import 'package:hymn/ui/pages/dashboard_page.dart';
import 'package:hymn/ui/pages/onboarding_page.dart';
import 'package:hymn/ui/pages/storage_page.dart';
import 'package:hymn/ui/shell.dart';

import 'fakes.dart';

/// Golden screenshots — also the source of the README/store images.
/// Regenerate with: flutter test --update-goldens
void main() {
  group('goldens', () {
    testWidgets('onboarding', (tester) async {
      final state = await makeState();
      await pumpPage(tester, state, OnboardingPage(),
          size: const Size(430, 900));
      await expectLater(find.byType(OnboardingPage),
          matchesGoldenFile('goldens/onboarding.png'));
    });

    testWidgets('dashboard wide', (tester) async {
      final nas = FakeNas()
        // keep relative timestamps out of the golden so it stays stable
        ..overrides['getAlerts'] = <NasAlert>[]
        ..overrides['getJobs'] = <NasJob>[fakeDoneJob];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, const DashboardPage(),
          size: const Size(1280, 900));
      await expectLater(find.byType(DashboardPage),
          matchesGoldenFile('goldens/dashboard.png'));
    });

    testWidgets('storage compact', (tester) async {
      final state = await connectedState();
      await pumpPage(tester, state, const StoragePage(),
          size: const Size(430, 900));
      await expectLater(find.byType(StoragePage),
          matchesGoldenFile('goldens/storage.png'));
    });

    testWidgets('shell wide', (tester) async {
      final nas = FakeNas()
        ..overrides['getAlerts'] = <NasAlert>[]
        ..overrides['getJobs'] = <NasJob>[fakeDoneJob];
      final state = await connectedState(nas: nas);
      await pumpPage(tester, state, AppShell(),
          size: const Size(1400, 900));
      await expectLater(
          find.byType(MaterialApp), matchesGoldenFile('goldens/shell.png'));
    });

    testWidgets('landing wide', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(HymnLandingApp());
      await tester.pumpAndSettle();
      await expectLater(
          find.byType(HymnLandingApp), matchesGoldenFile('goldens/landing.png'));
    });
  });
}
