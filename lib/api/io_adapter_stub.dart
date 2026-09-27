import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Stub for platforms where dart:io is unavailable (web).
void allowSelfSignedCerts(Dio dio) {}

/// Web fallback uses the platform channel connector.
WebSocketChannel connectWebSocket(Uri uri, {bool allowSelfSigned = false}) =>
    WebSocketChannel.connect(uri);
