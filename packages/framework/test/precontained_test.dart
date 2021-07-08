import 'dart:convert';

import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';

import 'package:test/test.dart';

void main() {
  test('preinjects functions', () async {
    var app = Angel(reflector: MirrorsReflector())
      ..configuration['foo'] = 'bar'
      ..get('/foo', ioc(echoAppFoo));
    app.optimizeForProduction(force: true);
    print(app.preContained);
    expect(app.preContained.keys, contains(echoAppFoo));

    var rq = MockHttpRequest('GET', Uri(path: '/foo'));
    await rq.close();
    await AngelHttp(app).handleRequest(rq);
    var rs = rq.response;
    var body = await rs.transform(utf8.decoder).join();
    expect(body, json.encode('bar'));
  }, skip: 'Angel no longer has to preinject functions');
}

String echoAppFoo(String foo) => foo;
