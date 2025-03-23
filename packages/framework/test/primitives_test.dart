import 'dart:convert';
import 'dart:io' show stderr;

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';

import 'package:test/test.dart';

void main() {
  late Angel app;
  late AngelHttp http;

  setUp(() {
    app = Angel(reflector: MirrorsReflector())
      ..configuration['global'] = 305; // Pitbull!
    http = AngelHttp(app);

    app.get('/string/:string', ioc((String string) => string));

    app.get(
        '/num/parsed/:num',
        chain([
          (req, res) {
            req.params['n'] = num.parse(req.params['num'].toString());
            return true;
          },
          ioc((num n) => n),
        ]));

    app.get('/num/global', ioc((num global) => global));

    app.errorHandler = (e, req, res) {
      stderr
        ..writeln(e.error)
        ..writeln(e.stackTrace);
    };
  });

  tearDown(() => app.close());

  test('String type annotation', () async {
    var rq = MockHttpRequest('GET', Uri.parse('/string/hello'));
    await rq.close();
    await http.handleRequest(rq);
    var rs = await rq.response.transform(utf8.decoder).join();
    expect(rs, json.encode('hello'));
  });

  test('Primitive after parsed param injection', () async {
    var rq = MockHttpRequest('GET', Uri.parse('/num/parsed/24'));
    await rq.close();
    await http.handleRequest(rq);
    var rs = await rq.response.transform(utf8.decoder).join();
    expect(rs, json.encode(24));
  });

  test('globally-injected primitive', () async {
    var rq = MockHttpRequest('GET', Uri.parse('/num/global'));
    await rq.close();
    await http.handleRequest(rq);
    var rs = await rq.response.transform(utf8.decoder).join();
    expect(rs, json.encode(305));
  });

  test('unparsed primitive throws error', () async {
    var rq = MockHttpRequest('GET', Uri.parse('/num/unparsed/32'));
    await rq.close();
    var req = await http.createRequestContext(rq, rq.response);
    var res = await http.createResponseContext(rq, rq.response, req);
    expect(() => app.runContained((num unparsed) => unparsed, req, res),
        throwsA(isA<ArgumentError>()));
  });
}
