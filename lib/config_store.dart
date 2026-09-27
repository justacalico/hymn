/// Persists the NAS connection details between launches.
///
/// The URL and preferences live in shared preferences; the API key goes to
/// the platform keychain via flutter_secure_storage, falling back to shared
/// preferences when secure storage is unavailable (headless Linux, tests).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/truenas_client.dart';

class ConfigStore {
  static const _urlKey = 'truenas_url';
  static const _selfSignedKey = 'allow_self_signed';
  static const _apiKeyKey = 'truenas_api_key';
  static const _themeKey = 'theme_mode';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  ConfigStore(this._prefs, [FlutterSecureStorage? secure])
      : _secure = secure ?? const FlutterSecureStorage();

  bool get hasConfig => (_prefs.getString(_urlKey) ?? '').isNotEmpty;

  ConnectionConfig? load() {
    final url = _prefs.getString(_urlKey);
    if (url == null || url.isEmpty) return null;
    return ConnectionConfig(
      url: url,
      apiKey: _prefs.getString(_apiKeyKey) ?? '',
      allowSelfSigned: _prefs.getBool(_selfSignedKey) ?? true,
    );
  }

  /// Reads the API key from secure storage. Call after [load]; the key is
  /// merged into the returned config.
  Future<ConnectionConfig?> loadWithKey() async {
    final config = load();
    if (config == null) return null;
    var key = '';
    try {
      key = await _secure.read(key: _apiKeyKey) ?? '';
    } catch (_) {
      key = _prefs.getString(_apiKeyKey) ?? '';
    }
    return ConnectionConfig(
      url: config.url,
      apiKey: key,
      allowSelfSigned: config.allowSelfSigned,
    );
  }

  Future<void> save(ConnectionConfig config) async {
    await _prefs.setString(_urlKey, config.url);
    await _prefs.setBool(_selfSignedKey, config.allowSelfSigned);
    try {
      await _secure.write(key: _apiKeyKey, value: config.apiKey);
      await _prefs.remove(_apiKeyKey);
    } catch (_) {
      await _prefs.setString(_apiKeyKey, config.apiKey);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(_urlKey);
    await _prefs.remove(_selfSignedKey);
    await _prefs.remove(_apiKeyKey);
    try {
      await _secure.delete(key: _apiKeyKey);
    } catch (_) {}
  }

  String get themeMode => _prefs.getString(_themeKey) ?? 'system';

  Future<void> setThemeMode(String mode) => _prefs.setString(_themeKey, mode);
}
