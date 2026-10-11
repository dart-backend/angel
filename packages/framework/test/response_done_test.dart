import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:test/test.dart';

void main() {
  late AngelHttp http;
  late Future done;

  setUp(() {
    var app = Angel();
    http = AngelHttp(app);

    app.get('/unbuffered', (req, res) {
      done = res.done;
      res.write('Hey!');
      return res.close();
    });

    app.get('/buffered', (req, res) {
      res.useBuffer();
      done = res.done;
      res.write('Hey!');
      return res.close();
    });
  });

  tearDown(() => http.close());

  for (var path in ['unbuffered', 'buffered']) {
    test('done completes once a $path response is closed', () async {
      var rq = MockHttpRequest('GET', Uri.parse('/$path'));
      await rq.close();
      await http.handleRequest(rq);
      expect(await rq.response.transform(utf8.decoder).join(), 'Hey!');
      await done.timeout(const Duration(seconds: 1));
    });
  }
}
