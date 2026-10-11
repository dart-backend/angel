import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  var app = Angel();
  var http = AngelHttp(app);

  Future<RequestContext> request({
    bool asJson = true,
    bool parse = true,
    Map<String, dynamic>? bodyFields,
    List? bodyList,
  }) async {
    var rq = MockHttpRequest(
      'POST',
      Uri(path: '/'),
      persistentConnection: false,
    );

    if (bodyFields != null) {
      if (asJson) {
        rq
          ..headers.contentType = ContentType('application', 'json')
          ..write(json.encode(bodyFields));
      } else {
        var b = StringBuffer();
        var i = 0;
        for (var entry in bodyFields.entries) {
          if (i++ > 0) b.write('&');
          b.write(entry.key);
          b.write('=');
          b.write(Uri.encodeComponent(entry.value.toString()));
        }

        rq
          ..headers.contentType = ContentType(
            'application',
            'x-www-form-urlencoded',
          )
          ..write(json.encode(b.toString()));
      }
    } else if (bodyList != null) {
      rq
        ..headers.contentType = ContentType('application', 'json')
        ..write(json.encode(bodyList));
    }

    await rq.close();
    var req = await http.createRequestContext(rq, rq.response);
    if (parse) await req.parseBody();
    return req;
  }

  test('parses json maps', () async {
    var req = await request(bodyFields: {'hello': 'world'});
    expect(req.bodyAsObject, TypeMatcher<Map<String, dynamic>>());
    expect(req.bodyAsMap, {'hello': 'world'});
  });

  test('parses json lists', () async {
    var req = await request(bodyList: ['foo', 'bar']);
    expect(req.bodyAsObject, TypeMatcher<List>());
    expect(req.bodyAsList, ['foo', 'bar']);
  });

  test('parses empty json lists', () async {
    var req = await request(bodyList: []);
    expect(req.bodyAsList, isEmpty);
  });

  test('bodyAsList throws when body is not a list', () async {
    var req = await request(bodyFields: {'hello': 'world'});
    expect(() => req.bodyAsList, throwsStateError);
  });

  test('deserializeBody', () async {
    var req = await request(
      asJson: true,
      bodyFields: {'text': 'Hey', 'complete': false},
    );
    var todo = await req.deserializeBody(Todo.fromMap);
    expect(todo.text, 'Hey');
    expect(todo.completed, false);
  });

  test('decodeBody', () async {
    var req = await request(
      asJson: true,
      bodyFields: {'text': 'Hey', 'complete': false},
    );
    var todo = await req.decodeBody(TodoCodec());
    expect(todo.text, 'Hey');
    expect(todo.completed, false);
  });

  Future<RequestContext> rawRequest(String contentType, String body) async {
    var rq = MockHttpRequest('POST', Uri(path: '/'))
      ..headers.set('content-type', contentType)
      ..write(body);
    await rq.close();
    return http.createRequestContext(rq, rq.response);
  }

  test('a parseBody call made during another waits for it', () async {
    var req = await request(parse: false, bodyFields: {'a': 1});
    var first = req.parseBody();
    await req.parseBody();
    expect(req.bodyAsMap, {'a': 1});
    await first;
  });

  test('a failed parse fails later parseBody calls too', () async {
    var req = await rawRequest('application/json', '{bad');
    await expectLater(req.parseBody(), throwsFormatException);
    await expectLater(req.parseBody(), throwsFormatException);
    expect(req.hasParsedBody, isFalse);
  });

  test('uploads with a text Content-Type are files', () async {
    var req = await rawRequest(
      'multipart/form-data; boundary=XYZ',
      '--XYZ\r\n'
          'Content-Disposition: form-data; name="file"; filename="data.csv"\r\n'
          'Content-Type: text/csv\r\n\r\n'
          'a,b\r\n'
          '--XYZ\r\n'
          'Content-Disposition: form-data; name="field"\r\n\r\n'
          'value\r\n'
          '--XYZ--\r\n',
    );
    await req.parseBody();
    expect(req.bodyAsMap, {'field': 'value'});
    var file = req.uploadedFiles!.single;
    expect(file.filename, 'data.csv');
    expect(file.contentType.mimeType, 'text/csv');
    expect(utf8.decode(await file.readAsBytes()), 'a,b');
  });

  test('throws when body has not been parsed', () async {
    var req = await request(parse: false);
    expect(() => req.bodyAsObject, throwsStateError);
    expect(() => req.bodyAsMap, throwsStateError);
    expect(() => req.bodyAsList, throwsStateError);
  });

  test('can set body object exactly once', () async {
    var req = await request(parse: false);
    req.bodyAsObject = 23;
    expect(req.bodyAsObject, 23);
    expect(() => req.bodyAsObject = {45.6: '34'}, throwsStateError);
  });

  test('can set body map exactly once', () async {
    var req = await request(parse: false);
    req.bodyAsMap = {'hey': 'yes'};
    expect(req.bodyAsMap, {'hey': 'yes'});
    expect(() => req.bodyAsMap = {'hm': 'ok'}, throwsStateError);
  });

  test('can set body list exactly once', () async {
    var req = await request(parse: false);
    req.bodyAsList = [
      {'hey': 'yes'},
    ];
    expect(req.bodyAsList, [
      {'hey': 'yes'},
    ]);
    expect(
      () => req.bodyAsList = [
        {'hm': 'ok'},
      ],
      throwsStateError,
    );
  });

  test('a malformed form body is a 400', () async {
    var req = await rawRequest('application/x-www-form-urlencoded', 'a=%zz');
    await expectLater(
      req.parseBody(),
      throwsA(
        isA<AngelHttpException>().having((e) => e.statusCode, 'status', 400),
      ),
    );
  });

  for (var (name, body) in [
    (
      'a malformed Content-Disposition',
      '--XYZ\r\n'
          'Content-Disposition: form-data; name="a\r\n\r\n'
          'value\r\n'
          '--XYZ--\r\n',
    ),
    (
      'a body cut off before its closing boundary',
      '--XYZ\r\n'
          'Content-Disposition: form-data; name="a"\r\n\r\n'
          'value',
    ),
  ]) {
    test('a multipart body with $name is a 400', () async {
      var req = await rawRequest('multipart/form-data; boundary=XYZ', body);
      await expectLater(
        req.parseBody(),
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 400),
        ),
      );
    });
  }

  test('a multipart part without Content-Disposition is a 400', () async {
    var req = await rawRequest(
      'multipart/form-data; boundary=XYZ',
      '--XYZ\r\n'
          'Content-Type: text/plain\r\n\r\n'
          'value\r\n'
          '--XYZ--\r\n',
    );
    await expectLater(
      req.parseBody(),
      throwsA(
        isA<AngelHttpException>().having((e) => e.statusCode, 'status', 400),
      ),
    );
  });
}

class Todo {
  String? text;
  bool? completed;

  Todo({this.text, this.completed});

  static Todo fromMap(Map? m) =>
      Todo(text: m!['text'] as String?, completed: m['complete'] as bool?);
}

class TodoCodec extends Codec<Todo, Map?> {
  @override
  Converter<Map, Todo> get decoder => TodoDecoder();

  @override
  Converter<Todo, Map> get encoder => throw UnsupportedError('no encoder');
}

class TodoDecoder extends Converter<Map, Todo> {
  @override
  Todo convert(Map input) => Todo.fromMap(input);
}
