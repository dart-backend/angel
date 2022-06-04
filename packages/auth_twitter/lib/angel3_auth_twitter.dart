import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:oauth1/oauth1.dart' as oauth;
import 'package:dart_twitter_api/twitter_api.dart';

/// Authenticates users by connecting to Twitter's API.
class TwitterStrategy<User> extends AuthStrategy<User> {
  /// The options defining how to connect to the third-party.
  final ExternalAuthOptions options;

  /// A callback that uses Twitter to authenticate a [User].
  ///
  /// As always, return `null` if authentication fails.
  final FutureOr<User> Function(TwitterApi, RequestContext, ResponseContext)
      verifier;

  /// A callback that is triggered when an OAuth2 error occurs (i.e. the user declines to login);
  final FutureOr<dynamic> Function(
      TwitterAuthorizationException, RequestContext, ResponseContext) onError;

  /// The root of Twitter's API. Defaults to `'https://api.twitter.com'`.
  final Uri baseUrl;

  oauth.Client? _client;

  /// The underlying [oauth.Client] used to query Twitter.
  oauth.Client get client => _client!;

  TwitterStrategy(this.options, this.verifier, this.onError,
      {http.BaseClient? client, Uri? baseUrl})
      : baseUrl = baseUrl ?? Uri.parse('https://api.twitter.com') {
    // define platform (server)
    final oauth.Platform platform = oauth.Platform(
        '$baseUrl/oauth/request_token', // temporary credentials request
        '$baseUrl/oauth/authorize', // resource owner authorization
        '$baseUrl/oauth/access_token', // token credentials request
        oauth.SignatureMethods.hmacSha1 // signature method
        );

    // define client credentials (consumer keys)
    final oauth.ClientCredentials clientCredentials =
        oauth.ClientCredentials(options.clientId, options.clientSecret);

    // create Authorization object with client credentials and platform definition
    final oauth.Authorization auth =
        oauth.Authorization(clientCredentials, platform);

    // request temporary credentials (request tokens)
    auth.requestTemporaryCredentials('oob').then((res) {
      // redirect to authorization page
      print(
          "Open with your browser: ${auth.getResourceOwnerAuthorizationURI(res.credentials.token)}");

      // get verifier (PIN)
      stdout.write("PIN: ");
      String verifier = stdin.readLineSync() ?? '';

      // request token credentials (access tokens)
      return auth.requestTokenCredentials(res.credentials, verifier);
    }).then((res) {
      // create Client object
      _client = oauth.Client(
          platform.signatureMethod, clientCredentials, res.credentials);
    });
  }

  /// Handle a response from Twitter.
  Future<Map<String, String>> handleUrlEncodedResponse(http.Response rs) async {
    var body = rs.body;

    if (rs.statusCode != 200) {
      var err = json.decode(rs.body) as Map;
      var errors = err['errors'] as List;

      if (errors.isNotEmpty) {
        throw TwitterAuthorizationException(
            errors[0]['message'] as String, false);
      } else {
        throw StateError(
            'Twitter returned an error response without an error message: ${rs.body}');
      }
    }

    return Uri.splitQueryString(body);
  }

  /// Get an access token.
  Future<Map<String, String>> getAccessToken(String token, String verifier) {
    return client.post(
        baseUrl.replace(path: p.join(baseUrl.path, 'oauth/access_token')),
        headers: {
          'accept': 'application/json'
        },
        body: {
          'oauth_token': token,
          'oauth_verifier': verifier
        }).then(handleUrlEncodedResponse);
    // var request = await createRequest("oauth/access_token",
    //     method: "POST", data: {"verifier": verifier}, accessToken: token);
  }

  /// Get a request token.
  Future<Map<String, String>> getRequestToken() {
    return client.post(
        baseUrl.replace(path: p.join(baseUrl.path, 'oauth/request_token')),
        headers: {
          'accept': 'application/json'
        },
        body: {
          'oauth_callback': options.redirectUri.toString()
        }).then(handleUrlEncodedResponse);
  }

  @override
  Future<User?> authenticate(RequestContext req, ResponseContext res,
      [AngelAuthOptions? options]) async {
    try {
      if (options != null) {
        var result = await authenticateCallback(req, res, options);
        if (result is User) {
          return result;
        } else {
          return null;
        }
      } else {
        var result = await getRequestToken();
        var token = result['oauth_token'];
        var url = baseUrl.replace(
            path: p.join(baseUrl.path, 'oauth/authorize'),
            queryParameters: {'oauth_token': token});
        await res.redirect(url);
        return null;
      }
    } on TwitterAuthorizationException catch (e) {
      var result = await onError(e, req, res);
      await req.app?.executeHandler(result, req, res);
      await res.close();
      return null;
    }
  }

  Future authenticateCallback(
      RequestContext req, ResponseContext res, AngelAuthOptions options) async {
    try {
      if (req.queryParameters.containsKey('denied')) {
        throw TwitterAuthorizationException(
            'The user denied the Twitter authorization attempt.', true);
      }

      var token = req.queryParameters['oauth_token'] as String;
      var verifier = req.queryParameters['oauth_verifier'] as String;
      var loginData = await getAccessToken(token, verifier);
      var twitter = TwitterApi(
          client: TwitterClient(
              consumerKey: this.options.clientId,
              consumerSecret: this.options.clientSecret,
              token: loginData['oauth_token'] ?? '',
              secret: loginData['oauth_token_secret'] ?? ''));

      return await this.verifier(twitter, req, res);
    } on TwitterAuthorizationException catch (e) {
      return await onError(e, req, res);
    }
  }
}

class TwitterAuthorizationException implements Exception {
  /// The message associated with this exception.
  final String message;

  /// Whether the user denied the authorization attempt.
  final bool isDenial;

  TwitterAuthorizationException(this.message, this.isDenial);

  @override
  String toString() => 'TwitterAuthorizationException: $message';
}
