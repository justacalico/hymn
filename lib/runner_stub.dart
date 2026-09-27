/// Web builds ship only the landing page, so this is never called there.
/// It exists so conditional imports resolve on every platform.
Future<void> runNativeApp() async {}
