import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:angel3_user_agent/angel3_user_agent.dart';
import 'package:test/test.dart';

const chrome =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

void main() {
  late TestClient client;

  setUp(() async {
    var app = Angel()
      ..fallback(parseUserAgent)
      // A second use of the middleware, e.g. in a route's chain.
      ..fallback(parseUserAgent)
      ..get('/', (req, res) {
        var container = req.container!;
        var ua = container.make<UserAgent>();
        return {
          'chrome': ua.isChrome,
          'value': ua.value,
          // Made again, from the request's container and a child of it.
          'once':
              identical(ua, container.make<UserAgent>()) &&
              identical(ua, container.createChild().make<UserAgent>()),
        };
      });
    // A user agent of the app does not stand in for the request's.
    app.container.registerSingleton(UserAgent('app'));
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  test('parses the User-Agent header once per request', () async {
    var response = await client.get(
      Uri.parse('/'),
      headers: {'user-agent': '  $chrome  '},
    );
    expect(response, isJson({'chrome': true, 'value': chrome, 'once': true}));
  });

  test('a missing or blank User-Agent is a 400', () async {
    for (var agent in [null, '   ']) {
      var response = await client.get(
        Uri.parse('/'),
        headers: {'user-agent': ?agent},
      );
      expect(response, hasStatus(400));
    }
  });
}
