import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/api/truenas_client.dart';
import 'package:hymn/config_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ConfigStore, SharedPreferences)> makeStore(
      [Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return (ConfigStore(prefs), prefs);
  }

  test('empty store has no config', () async {
    final (store, _) = await makeStore();
    expect(store.hasConfig, isFalse);
    expect(store.load(), isNull);
    expect(await store.loadWithKey(), isNull);
  });

  test('save + load round-trips (secure storage falls back to prefs)', () async {
    final (store, prefs) = await makeStore();
    // flutter_secure_storage has no plugin in tests -> falls back to prefs.
    await store.save(const ConnectionConfig(
      url: 'https://nas.home',
      apiKey: 'k3y',
      allowSelfSigned: false,
    ));
    expect(store.hasConfig, isTrue);
    final config = await store.loadWithKey();
    expect(config?.url, 'https://nas.home');
    expect(config?.allowSelfSigned, isFalse);
    // key was written through the prefs fallback
    expect(prefs.getString('truenas_api_key'), isNotNull);
  });

  test('theme mode persists', () async {
    final (store, _) = await makeStore();
    expect(store.themeMode, 'system');
    await store.setThemeMode('dark');
    expect(store.themeMode, 'dark');
  });

  test('clear removes everything', () async {
    final (store, _) = await makeStore({
      'truenas_url': 'https://x',
      'truenas_api_key': 'k',
      'allow_self_signed': false,
      'theme_mode': 'dark',
    });
    await store.clear();
    expect(store.hasConfig, isFalse);
    expect(store.load(), isNull);
  });

  test('load maps stored prefs into a config', () async {
    final (store, _) = await makeStore({
      'truenas_url': 'https://nas',
      'truenas_api_key': 'saved-key',
      'allow_self_signed': true,
    });
    final config = await store.loadWithKey();
    expect(config?.url, 'https://nas');
    expect(config?.apiKey, 'saved-key');
    expect(config?.allowSelfSigned, isTrue);
  });
}
