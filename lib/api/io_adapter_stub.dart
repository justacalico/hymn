import 'package:dio/dio.dart';

/// No-op on web: browsers decide certificate trust, not the app.
void allowSelfSignedCerts(Dio dio) {}
