import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the Inter font family so golden screenshots render real text
/// instead of Ahem placeholder boxes.
Future<void> loadAppFonts() async {
  final loader = FontLoader('Inter');
  for (final path in const [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();

  // Material icons font ships with the SDK; without it goldens render tofu.
  // dart lives at <flutter>/bin/cache/dart-sdk/bin/dart
  final dartBin = File(Platform.resolvedExecutable).parent; // .../dart-sdk/bin
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      dartBin.parent.parent.parent.parent.path;
  final iconsPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(
          ByteData.view(File(iconsPath).readAsBytesSync().buffer)));
    await iconLoader.load();
  }
}

/// Gives every test a fake window_manager channel. Without it, calls like
/// `isMaximized` hang the messenger instead of throwing, which stalls
/// anything that awaits them (including `main()`).
void mockWindowManager() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('window_manager'),
          (call) async {
    return switch (call.method) {
      'isVisible' ||
      'isMaximized' ||
      'isMinimized' ||
      'isFullScreen' ||
      'isAlwaysOnTop' ||
      'isFocused' ||
      'isPreventClose' ||
      'isSkipTaskbar' ||
      'isMinimizable' ||
      'isMaximizable' ||
      'isClosable' ||
      'isResizable' =>
        false,
      'getId' => 0,
      'getDevicePixelRatio' || 'getTitleBarHeight' => 1.0,
      _ => null,
    };
  });
}

FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();
  mockWindowManager();
  return testMain();
}
