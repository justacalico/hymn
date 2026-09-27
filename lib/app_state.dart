/// Single source of truth for app-wide state.
///
/// Created once in `main()` above `MaterialApp` and exposed through
/// provider. Owns the stored connection config, the live TrueNAS client,
/// the realtime stats stream, theme mode and the selected tab. Widgets only
/// ever watch this object; resizing a window swaps layout, never state.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/truenas_client.dart';
import 'config_store.dart';

enum ConnectionStatus { unknown, connecting, connected, failed }

class AppState extends ChangeNotifier {
  final ConfigStore store;
  final TrueNasClient Function(ConnectionConfig) clientFactory;

  ConnectionConfig? _config;
  TrueNasClient? _client;
  ConnectionStatus _status = ConnectionStatus.unknown;
  String? _error;
  ThemeSetting _theme = ThemeSetting.system;
  int _navIndex = 0;
  bool _checking = false;
  bool _ready = false;

  AppState(this.store, {TrueNasClient Function(ConnectionConfig)? clientFactory})
      : clientFactory = clientFactory ?? ((c) => TrueNasClient(c));

  ConnectionConfig? get config => _config;
  TrueNasClient? get client => _client;
  ConnectionStatus get status => _status;
  String? get error => _error;
  ThemeSetting get theme => _theme;
  int get navIndex => _navIndex;
  bool get configured => _config != null;
  bool get ready => _ready;

  /// Restores the saved config and opens a session. Called once at startup.
  Future<void> bootstrap() async {
    try {
      _theme = ThemeSettingX.parse(store.themeMode);
      _config = await store.loadWithKey();
      if (_config == null || _config!.apiKey.isEmpty) {
        _status = _config == null
            ? ConnectionStatus.unknown
            : ConnectionStatus.failed;
        _error = _config == null ? null : 'API key missing, please reconnect';
        return;
      }
      await connect(_config!, persist: false);
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> connect(ConnectionConfig config, {bool persist = true}) async {
    if (_checking) return;
    _checking = true;
    _status = ConnectionStatus.connecting;
    _error = null;
    notifyListeners();
    try {
      final client = clientFactory(config);
      await client.healthCheck();
      _client = client;
      _config = config;
      _status = ConnectionStatus.connected;
      if (persist) await store.save(config);
    } on TrueNasException catch (e) {
      _status = ConnectionStatus.failed;
      _error = e.message;
    } catch (e) {
      _status = ConnectionStatus.failed;
      _error = e.toString();
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _client = null;
    _config = null;
    _status = ConnectionStatus.unknown;
    _error = null;
    _navIndex = 0;
    await store.clear();
    notifyListeners();
  }

  void selectNav(int index) {
    if (_navIndex == index) return;
    _navIndex = index;
    notifyListeners();
  }

  Future<void> setTheme(ThemeSetting setting) async {
    _theme = setting;
    await store.setThemeMode(setting.name);
    notifyListeners();
  }
}

enum ThemeSetting { system, light, dark }

extension ThemeSettingX on ThemeSetting {
  static ThemeSetting parse(String value) => ThemeSetting.values.firstWhere(
        (t) => t.name == value,
        orElse: () => ThemeSetting.system,
      );
}
