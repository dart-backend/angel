/// Command-line client library for the Angel framework.
library;

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'angel3_client.dart';
import 'base_angel_client.dart';
export 'angel3_client.dart';

/// Queries an Angel server via REST.
class Rest extends BaseAngelClient {
  //final _log = Logger('REST');
  final List<Service> _services = [];

  Rest(String path) : super(http.Client() as http.BaseClient, path);

  @override
  Service<Id, Data> service<Id, Data>(
    String path, {
    AngelDeserializer<Data>? deserializer,
  }) {
    var url = baseUrl.replace(path: p.join(baseUrl.path, path));
    var s = RestService<Id, Data>(
      client,
      this,
      url,
      deserializer: deserializer,
    );
    _services.add(s);
    return s;
  }

  @override
  Stream<String> authenticateViaPopup(
    String url, {
    String eventName = 'token',
  }) {
    throw UnimplementedError(
      'Opening popup windows is not supported in the `dart:io` client.',
    );
  }

  @override
  Future close() async {
    await super.close();
    await Future.wait(_services.map((s) => s.close())).then((_) {
      _services.clear();
    });
  }
}

/// Queries an Angel service via REST.
class RestService<Id, Data> extends BaseAngelService<Id, Data> {
  RestService(super.client, super.app, super.url, {super.deserializer});
}
