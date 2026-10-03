import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/app_state.dart';


import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bootstrap with no config lands on onboarding state', () async {
    final state = await makeState();
    expect(state.ready, isTrue);
    expect(state.configured, isFalse);
    expect(state.client, isNull);
    expect(state.status, ConnectionStatus.unknown);
  });

  test('bootstrap restores saved config and connects', () async {
    final state = await makeState(prefs: {
      'truenas_url': 'https://nas.home',
      'truenas_api_key': 'saved-key',
    });
    expect(state.ready, isTrue);
    expect(state.status, ConnectionStatus.connected);
    expect(state.client, isNotNull);
    expect(state.config?.url, 'https://nas.home');
  });

  test('bootstrap with saved url but missing key fails', () async {
    final state = await makeState(prefs: {'truenas_url': 'https://nas.home'});
    expect(state.status, ConnectionStatus.failed);
    expect(state.error, contains('API key'));
  });

  test('connect success stores client and persists config', () async {
    final state = await makeState();
    await state.connect(testConfig);
    expect(state.status, ConnectionStatus.connected);
    expect(state.client, isNotNull);
    expect(state.store.hasConfig, isTrue);
  });

  test('connect failure surfaces the error', () async {
    final nas = FakeNas()..failAll = true;
    final state = await makeState(nas: nas);
    await state.connect(testConfig);
    expect(state.status, ConnectionStatus.failed);
    expect(state.error, isNotNull);
    expect(state.client, isNull);
  });

  test('disconnect clears everything', () async {
    final state = await connectedState();
    await state.disconnect();
    expect(state.client, isNull);
    expect(state.config, isNull);
    expect(state.store.hasConfig, isFalse);
    expect(state.navIndex, 0);
  });

  test('nav selection notifies', () async {
    final state = await makeState();
    var notified = 0;
    state.addListener(() => notified++);
    state.selectNav(3);
    expect(state.navIndex, 3);
    expect(notified, 1);
    state.selectNav(3); // no-op
    expect(notified, 1);
  });

  test('theme persists through the store', () async {
    final state = await makeState();
    await state.setTheme(ThemeSetting.dark);
    expect(state.theme, ThemeSetting.dark);
    expect(state.store.themeMode, 'dark');
  });

  test('ThemeSettingX.parse handles unknowns', () {
    expect(ThemeSettingX.parse('dark'), ThemeSetting.dark);
    expect(ThemeSettingX.parse('oled'), ThemeSetting.oled);
    expect(ThemeSettingX.parse('bogus'), ThemeSetting.system);
  });
}
