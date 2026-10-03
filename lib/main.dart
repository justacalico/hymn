import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'runner_stub.dart' if (dart.library.io) 'runner.dart';
import 'ui/landing.dart';
import 'ui/pages/onboarding_page.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/window_frame_stub.dart'
    if (dart.library.io) 'ui/window_frame.dart';

void main() {
  if (kIsWeb) {
    // coverage:ignore-start
    runApp(const HymnLandingApp());
    return;
    // coverage:ignore-end
  }
  runZonedGuardedApp();
}

/// Kept behind a function so the web tree never touches dart:io types.
void runZonedGuardedApp() {
  // ignore: avoid_print
  runZonedGuarded(runNativeApp, (e, s) => debugPrint('Unhandled: $e'));
}

class HymnApp extends StatelessWidget {
  const HymnApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Hymn',
      debugShowCheckedModeBanner: false,
      theme: HymnTheme.light(),
      darkTheme: HymnTheme.dark(),
      themeMode: switch (state.theme) {
        ThemeSetting.system => ThemeMode.system,
        ThemeSetting.light => ThemeMode.light,
        ThemeSetting.dark => ThemeMode.dark,
      },
      home: WindowFrame(child: _buildHome(state)),
    );
  }

  Widget _buildHome(AppState state) {
    if (!state.ready || state.status == ConnectionStatus.connecting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.client == null) {
      return const OnboardingPage();
    }
    return const AppShell();
  }
}
