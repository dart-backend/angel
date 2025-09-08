import 'dart:async';
import 'dart:convert';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:logging/logging.dart';

import 'package:test/test.dart';

Future<String> readResponse(MockHttpResponse rs) {
  return rs.transform(utf8.decoder).join();
}

Future printResponse(MockHttpResponse rs) {
  return readResponse(rs).then((text) {
    print(text.isEmpty ? '<empty response>' : text);
  });
}

void main() {
  group('parameter_meta', parameterMetaTests);
}

void parameterMetaTests() {
  Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel(reflector: MirrorsReflector());
    http = AngelHttp(app);

    app.get(
      '/cookie',
      ioc((@CookieValue('token') String jwt) {
        return jwt;
      }),
    );

    app.get(
      '/header',
      ioc((@Header('x-foo') String header) {
        return header;
      }),
    );

    app.get(
      '/query',
      ioc((@Query('q') String query) {
        return query;
      }),
    );

    app.get(
      '/session',
      ioc((@Session('foo') String foo) {
        return foo;
      }),
    );

    app.get(
      '/match',
      ioc((@Query('mode', match: 'pos') String mode) {
        return 'YES $mode';
      }),
    );

    app.get(
      '/match',
      ioc((@Query('mode', match: 'neg') String mode) {
        return 'NO $mode';
      }),
    );

    app.get(
      '/match',
      ioc((@Query('mode') String mode) {
        return 'DEFAULT $mode';
      }),
    );

    app.logger = Logger('parameter_meta_test')
      ..onRecord.listen((rec) {
        print(rec);
        if (rec.error != null) print(rec.error);
        if (rec.stackTrace != null) print(rec.stackTrace);
      });
  });

  test('injects header or throws', () async {
    // Invalid request
    var rq = MockHttpRequest('GET', Uri.parse('/header'));
    await rq.close();
    var rs = rq.response;
    //TODO: Using await will hang. To be resolved.
    http.handleRequest(rq);

    await printResponse(rs);
    expect(rs.statusCode, 400);

    // Valid request
    rq = MockHttpRequest('GET', Uri.parse('/header'))
      ..headers.add('x-foo', 'bar');
    await rq.close();
    rs = rq.response;
    http.handleRequest(rq);

    var body = await readResponse(rs);
    print('Body: $body');
    expect(rs.statusCode, 200);
    expect(body, json.encode('bar'));
  });

  test('injects session or throws', () async {
    // Invalid request
    var rq = MockHttpRequest('GET', Uri.parse('/session'));
    await rq.close();
    var rs = rq.response;
    http
        .handleRequest(rq)
        .timeout(const Duration(seconds: 5))
        .catchError((_) => null);

    await printResponse(rs);
    expect(rs.statusCode, 500);

    rq = MockHttpRequest('GET', Uri.parse('/session'));
    rq.session['foo'] = 'bar';
    await rq.close();
    rs = rq.response;
    http.handleRequest(rq);

    await printResponse(rs);
    expect(rs.statusCode, 200);
  });

  // Originally, the plan was to test cookie, session, header, etc.,
  // but that behavior has been consolidated into `getValue`. Thus,
  // they will all function the same way.

  test('pattern matching', () async {
    var rq = MockHttpRequest('GET', Uri.parse('/match?mode=pos'));
    await rq.close();
    var rs = rq.response;
    http.handleRequest(rq);
    var body = await readResponse(rs);
    print('Body: $body');
    expect(rs.statusCode, 200);
    expect(body, json.encode('YES pos'));

    rq = MockHttpRequest('GET', Uri.parse('/match?mode=neg'));
    await rq.close();
    rs = rq.response;
    http.handleRequest(rq);
    body = await readResponse(rs);
    print('Body: $body');
    expect(rs.statusCode, 200);
    expect(body, json.encode('NO neg'));

    // Fallback
    rq = MockHttpRequest('GET', Uri.parse('/match?mode=ambi'));
    await rq.close();
    rs = rq.response;
    http.handleRequest(rq);
    body = await readResponse(rs);
    print('Body: $body');
    expect(rs.statusCode, 200);
    expect(body, json.encode('DEFAULT ambi'));
  });
}
