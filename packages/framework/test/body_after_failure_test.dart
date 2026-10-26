import 'dart:convert';
import 'dart:io' show ContentType;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  test('the body can be read after a failed parse', () async {
    Object? bodySeen;
    var app = Angel()
      ..post('/', (req, res) async {
        await req.parseBody();
        return 'parsed';
      })
      ..errorHandler = (e, req, res) {
        // An error handler may read the body, e.g. to log it.
        bodySeen = req.bodyAsMap;
        return {'status': e.statusCode};
      };

    var rq = MockHttpRequest('POST', Uri(path: '/'))
      ..headers.contentType = ContentType.json
      ..write('{not json');
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var body = await rq.response.transform(utf8.decoder).join();

    expect(rq.response.statusCode, 400);
    expect(json.decode(body), {'status': 400});
    expect(bodySeen, isEmpty);
  });

  test('parseBody fails again after a failed parse', () async {
    var failures = 0;
    var app = Angel()
      ..post('/', (req, res) async {
        for (var i = 0; i < 2; i++) {
          try {
            await req.parseBody();
          } on Object {
            failures++;
          }
        }
        return 'parsed: ${req.hasParsedBody}';
      });

    var rq = MockHttpRequest('POST', Uri(path: '/'))
      ..headers.contentType = ContentType.json
      ..write('{not json');
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    expect(await rq.response.transform(utf8.decoder).join(), '"parsed: false"');
    expect(failures, 2);
  });
}
