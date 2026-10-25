/// Command-line client library for the Angel framework.
library;

import 'package:http/http.dart' as http;

import 'base_angel_client.dart';
export 'angel3_client.dart';

/// Queries an Angel server via REST.
class Rest extends BaseAngelClient {
  Rest(String path) : super(http.Client() as http.BaseClient, path);

  @override
  Stream<String> authenticateViaPopup(
    String url, {
    String eventName = 'token',
  }) {
    throw UnimplementedError(
      'Opening popup windows is not supported in the `dart:io` client.',
    );
  }
}
