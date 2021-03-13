import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http_parser/http_parser.dart';
import 'package:body_parser/body_parser.dart';

main() async {
  var address = '127.0.0.1';
  var port = 3000;
  var futures = <Future>[];

  for (int i = 1; i < Platform.numberOfProcessors; i++) {
    futures.add(Isolate.spawn(start, [address, port, i]));
  }

  Future.wait(futures).then((_) {
    print('All instances started.');
    print(
        'Test with "wrk -t12 -c400 -d30s -s ./example/post.lua http://localhost:3000" or similar');
    start([address, port, 0]);
  });
}

void start(List args) {
  var address = new InternetAddress(args[0] as String);
  int port = 8080;
  if (args[1] is int) {
    args[1];
  }

  int id = 0;
  if (args[2] is int) {
    args[2];
  }

  HttpServer.bind(address, port, shared: true).then((server) {
    server.listen((request) async {
      // ignore: deprecated_member_use
      var body = await defaultParseBody(request);
      request.response
        ..headers.contentType = new ContentType('application', 'json')
        ..write(json.encode(body.body))
        ..close();
    });

    print(
        'Server #$id listening at http://${server.address.address}:${server.port}');
  });
}

Future<BodyParseResult> defaultParseBody(HttpRequest request,
    {bool storeOriginalBuffer: false}) {
  return parseBodyFromStream(
      request,
      request.headers.contentType != null
          ? new MediaType.parse(request.headers.contentType.toString())
          : null,
      request.uri,
      storeOriginalBuffer: storeOriginalBuffer);
}
