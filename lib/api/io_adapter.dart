import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Allows HTTPS connections to servers with self-signed certificates,
/// which is the default on most TrueNAS installs.
void allowSelfSignedCerts(Dio dio) {
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    return HttpClient()
      ..badCertificateCallback = (_, _, _) => true;
  };
}

/// Opens a websocket honoring the same self-signed tolerance as REST.
WebSocketChannel connectWebSocket(Uri uri, {bool allowSelfSigned = false}) {
  HttpClient? client;
  if (allowSelfSigned) {
    // coverage:ignore-start
    client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    // coverage:ignore-end
  }
  return IOWebSocketChannel.connect(uri, customClient: client);
}
