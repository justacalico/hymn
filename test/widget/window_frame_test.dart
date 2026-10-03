import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hymn/ui/theme.dart';
import 'package:hymn/ui/window_frame.dart';

/// Installs a fake `window_manager` channel and returns the list of method
/// calls it receives. [maximized] drives the `isMaximized` reply.
List<String> mockWindowManager({bool maximized = false}) {
  final calls = <String>[];
  var maximizedState = maximized;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('window_manager'),
          (call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'isMaximized':
        return maximizedState;
      case 'maximize':
        maximizedState = true;
      case 'unmaximize':
        maximizedState = false;
    }
    return null;
  });
  return calls;
}

/// Makes the fake channel throw MissingPluginException, mimicking a build
/// where the window_manager plugin was never registered.
void throwingWindowManagerMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('window_manager'),
          (call) async {
    throw MissingPluginException('no ${call.method}');
  });
}

/// Simulates a native -> Dart window event, e.g. the user maximizing the
/// window through the OS instead of the caption buttons.
Future<void> sendWindowEvent(String name) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'window_manager',
    const StandardMethodCodec()
        .encodeMethodCall(MethodCall('onEvent', {'eventName': name})),
    null,
  );
}

Future<void> pumpFrame(WidgetTester tester, {Widget? child}) {
  return tester.pumpWidget(MaterialApp(
    theme: HymnTheme.dark(),
    home: WindowFrame(child: child ?? const Scaffold(body: Text('body'))),
  ));
}

void main() {
  testWidgets('desktop frame renders the title bar above content',
      (tester) async {
    final calls = mockWindowManager();
    await pumpFrame(tester);
    await tester.pump();
    expect(find.byType(DesktopTitleBar), findsOneWidget);
    expect(find.text('Hymn'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(calls, contains('isMaximized'));
  });

  testWidgets('non-desktop passes the child through', (tester) async {
    WindowFrame.desktopOverride = false;
    addTearDown(() => WindowFrame.desktopOverride = null);
    await pumpFrame(tester);
    expect(find.byType(DesktopTitleBar), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('renders even when the window channel is missing',
      (tester) async {
    throwingWindowManagerMock();
    await pumpFrame(tester);
    await tester.pump();
    expect(find.byType(DesktopTitleBar), findsOneWidget);
  });

  testWidgets('caption buttons drive the window channel', (tester) async {
    final calls = mockWindowManager();
    await pumpFrame(tester);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.crop_square));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.crop_square));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(calls, containsAll(
        ['minimize', 'maximize', 'unmaximize', 'close']));
  });

  testWidgets('starts maximized when the window already is',
      (tester) async {
    mockWindowManager(maximized: true);
    await pumpFrame(tester);
    await tester.pump();
    expect(find.byIcon(Icons.filter_none), findsOneWidget);
  });

  testWidgets('window events swap the maximize icon', (tester) async {
    mockWindowManager();
    await pumpFrame(tester);
    await tester.pump();
    await sendWindowEvent('maximize');
    await tester.pump();
    expect(find.byIcon(Icons.filter_none), findsOneWidget);
    await sendWindowEvent('unmaximize');
    await tester.pump();
    expect(find.byIcon(Icons.crop_square), findsOneWidget);
  });
}
