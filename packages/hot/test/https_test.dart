import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_hot/angel3_hot.dart';
import 'package:test/test.dart';

void main() {
  late HotReloader hot;
  late HttpServer server;
  var version = 0;

  setUp(() async {
    version = 0;
    hot = HotReloader(
      () {
        var v = ++version;
        return Angel()..get('/', (req, res) => 'v$v');
      },
      [],
      hotReload: false,
      enableHotkeys: false,
      securityContext: SecurityContext()
        ..useCertificateChain('test/dev.pem')
        ..usePrivateKey('test/dev.key', password: 'dartdart'),
    );
    server = await hot.startServer('127.0.0.1', 0);
  });

  tearDown(() => hot.close());

  /// The body of `GET /` over HTTPS, trusting the test's certificate.
  Future<String> get() async {
    var client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    try {
      var rq = await client.getUrl(
        Uri.parse('https://127.0.0.1:${server.port}/'),
      );
      var rs = await rq.close();
      return await rs.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  test('serves over HTTPS', () async {
    expect(await get(), '"v1"');
  });

  test('a reload serves the new app over HTTPS', () async {
    await hot.reload();
    expect(await get(), '"v2"');
  });

  test('plain HTTP is not served', () async {
    var client = HttpClient();
    try {
      await expectLater(
        client
            .getUrl(Uri.parse('http://127.0.0.1:${server.port}/'))
            .then((rq) => rq.close()),
        throwsA(anything),
      );
    } finally {
      client.close(force: true);
    }
  });
}
