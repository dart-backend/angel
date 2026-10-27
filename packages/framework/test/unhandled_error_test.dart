import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// An app whose container fails on demand, so creating a request context (out
/// of the per-request error zone) fails.
class _FailingApp extends Angel {
  Object? error;

  @override
  Container get container {
    var e = error;
    if (e != null) throw e;
    return super.container;
  }
}

void main() {
  late _FailingApp app;
  late AngelHttp driver;

  setUp(() async {
    app = _FailingApp()..get('/', (req, res) => 'ok');
    driver = AngelHttp(app);
    await driver.startServer('127.0.0.1', 0);
  });

  tearDown(() => driver.close());

  Future<int> status() async => (await http.get(driver.uri)).statusCode;

  test('a server-side error before the app runs is a 500, not a 400', () async {
    app.error = StateError('A bug in the server.');
    expect(await status(), 500);

    app.error = null;
    expect(await status(), 200, reason: 'the server keeps serving');
  });

  test(
    'an AngelHttpException before the app runs keeps its status code',
    () async {
      app.error = AngelHttpException(statusCode: 503);
      expect(await status(), 503);
    },
  );

  test('a FormatException before the app runs is a 400', () async {
    app.error = FormatException('Malformed.');
    expect(await status(), 400);
  });
}
