import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'config_store.dart';
import 'main.dart';

/// Boots the real app on native platforms. Never imported on web.
Future<void> runNativeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initDesktopWindow();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(ConfigStore(prefs));
  unawaited(state.bootstrap());
  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const HymnApp(),
    ),
  );
}

/// Desktop builds hide the native title bar so the Flutter-drawn one can
/// take its place. Mobile has no window to configure.
Future<void> _initDesktopWindow() async {
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    title: 'Hymn',
    minimumSize: Size(480, 600),
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );
  await windowManager.waitUntilReadyToShow(options);
}
