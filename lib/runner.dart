import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'config_store.dart';
import 'main.dart';

/// Boots the real app on native platforms. Never imported on web.
Future<void> runNativeApp() async {
  WidgetsFlutterBinding.ensureInitialized();
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
