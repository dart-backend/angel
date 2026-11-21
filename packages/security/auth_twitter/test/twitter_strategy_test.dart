import 'dart:convert';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_auth_twitter/angel3_auth_twitter.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  late TestClient client;
  late List<http.Request> twitterRequests;
  late http.Response Function(http.Request) requestTokenResponse;
  late List<String> verified;

  setUp(() async {
    twitterRequests = [];
    verified = [];
    requestTokenResponse = (_) => http.Response(
      'oauth_token=rt&oauth_token_secret=rts&oauth_callback_confirmed=true',
      200,
    );

    // A fake Twitter.
    var twitter = MockClient((rq) async {
      twitterRequests.add(rq);
      switch (rq.url.path) {
        case '/oauth/request_token':
          return requestTokenResponse(rq);
        case '/oauth/access_token':
          return http.Response(
            'oauth_token=at&oauth_token_secret=ats&screen_name=bob',
            200,
          );
      }
      return http.Response('Not found', 404);
    });

    var app = Angel();
    var auth = AngelAuth<String>(
      jwtKey: 'test-secret',
      allowCookie: false,
      serializer: (user) => user,
      deserializer: (id) => id.toString(),
    );
    auth.strategies['twitter'] = TwitterStrategy<String>(
      ExternalAuthOptions(
        clientId: 'key',
        clientSecret: 'secret',
        redirectUri: 'http://localhost/auth/twitter/callback',
      ),
      (twit, req, res) {
        verified.add(req.queryParameters['oauth_token'] as String);
        return 'bob';
      },
      (e, req, res) => {'error': e.message, 'denial': e.isDenial},
      client: twitter,
    );

    app.get('/auth/twitter', auth.authenticate('twitter'));
    app.get(
      '/auth/twitter/callback',
      auth.authenticate(
        'twitter',
        AngelAuthOptions(callback: (req, res, jwt) => 'logged in'),
      ),
    );
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  Future<Map> errorOf(String path) async {
    var rs = await client.get(Uri.parse(path));
    expect(rs.statusCode, isNot(500));
    return json.decode(rs.body) as Map;
  }

  test(
    'redirects to Twitter with a request token signed by the consumer only',
    () async {
      var rs = await client.get(Uri.parse('/auth/twitter'));
      expect(rs.statusCode, 302);
      expect(
        rs.headers['location'],
        'https://api.twitter.com/oauth/authorize?oauth_token=rt',
      );

      var rq = twitterRequests.single;
      expect(rq.url.toString(), 'https://api.twitter.com/oauth/request_token');
      var header = rq.headers['Authorization']!;
      expect(header, contains('oauth_consumer_key="key"'));
      expect(header, isNot(contains('oauth_token=')));
    },
  );

  test('the callback exchanges the request token once', () async {
    await client.get(Uri.parse('/auth/twitter'));

    var rs = await client.get(
      Uri.parse('/auth/twitter/callback?oauth_token=rt&oauth_verifier=v'),
    );
    expect(rs.statusCode, 200);
    expect(json.decode(rs.body), 'logged in');
    expect(verified, ['rt']);

    var rq = twitterRequests.last;
    expect(rq.url.toString(), 'https://api.twitter.com/oauth/access_token');
    expect(rq.headers['Authorization'], contains('oauth_token="rt"'));
    expect(rq.headers['Authorization'], contains('oauth_verifier="v"'));

    // A replayed callback is rejected.
    expect(
      await errorOf('/auth/twitter/callback?oauth_token=rt&oauth_verifier=v'),
      {'error': 'Unknown or expired request token.', 'denial': false},
    );
  });

  test('a callback without oauth_verifier goes to onError', () async {
    expect(await errorOf('/auth/twitter/callback?oauth_token=rt'), {
      'error': 'The callback is missing oauth_token or oauth_verifier.',
      'denial': false,
    });
  });

  test('a denial goes to onError', () async {
    await client.get(Uri.parse('/auth/twitter'));
    expect(await errorOf('/auth/twitter/callback?denied=rt'), {
      'error': 'The user denied the Twitter authorization attempt.',
      'denial': true,
    });
  });

  test('a plain-text error from Twitter goes to onError', () async {
    requestTokenResponse = (_) =>
        http.Response('Failed to validate oauth signature', 401);
    expect(await errorOf('/auth/twitter'), {
      'error': 'Failed to validate oauth signature',
      'denial': false,
    });
  });

  test('a JSON error from Twitter goes to onError', () async {
    requestTokenResponse = (_) => http.Response(
      json.encode({
        'errors': [
          {'code': 32, 'message': 'Could not authenticate you.'},
        ],
      }),
      401,
    );
    expect(await errorOf('/auth/twitter'), {
      'error': 'Could not authenticate you.',
      'denial': false,
    });
  });
}
