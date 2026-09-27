import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Lets the client trust self-signed certificates, which is the norm on
/// home NAS installs that never see a real CA.
void allowSelfSignedCerts(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    adapter.createHttpClient = () {
      return HttpClient()
        ..badCertificateCallback = (_, _, _) => true;
    };
  }
}
