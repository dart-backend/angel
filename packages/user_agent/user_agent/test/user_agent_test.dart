import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:angel3_user_agent/angel3_user_agent.dart';
import 'package:test/test.dart';

const chrome =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const edge = '$chrome Edg/120.0.0.0';

const ipad =
    'Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

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

  // Since user_agent_analyzer 6.0.0, Chromium-based browsers are not Chrome.
  test('Edge is not Chrome', () async {
    var response = await client.get(
      Uri.parse('/'),
      headers: {'user-agent': edge},
    );
    expect(response, isJson({'chrome': false, 'value': edge, 'once': true}));
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

  // The checks of `user_agent_analyzer` 6.0.0, which this package exports.
  group('UserAgent', () {
    test('Edge is Edge, not Chrome', () {
      var ua = UserAgent(edge);
      expect(ua.isEdge, isTrue);
      expect(ua.isChrome, isFalse);
    });

    test('an iPad is iOS, not macOS or a desktop', () {
      var ua = UserAgent(ipad);
      expect(ua.isIOS, isTrue);
      expect(ua.isMacOS, isFalse);
      expect(ua.isDesktop, isFalse);
    });
  });
}
