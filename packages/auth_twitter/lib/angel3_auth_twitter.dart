import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:belatuk_oauth1/belatuk_oauth1.dart' as oauth;
import 'package:dart_twitter_api/twitter_api.dart';

/// Authenticates users by connecting to Twitter's API, with the OAuth 1.0a
/// redirect flow ("Sign in with Twitter").
///
/// A request without Twitter's callback parameters is redirected to Twitter;
/// the callback request (with `oauth_token` and `oauth_verifier`, or `denied`)
/// is exchanged for an access token and passed to [verifier].
///
/// Request token secrets are kept in memory between the redirect and the
/// callback, so the callback must reach the same server instance.
class TwitterStrategy<TUser> extends AuthStrategy<TUser> {
  /// The options defining how to connect to the third-party.
  final ExternalAuthOptions options;

  /// A callback that uses Twitter to authenticate a [TUser].
  ///
  /// As always, return `null` if authentication fails.
  final FutureOr<TUser> Function(TwitterApi, RequestContext, ResponseContext)
  verifier;

  /// A callback that is triggered when an OAuth error occurs (i.e. the user
  /// declines to login). Its result is run as a request handler.
  final FutureOr<dynamic> Function(
    TwitterAuthorizationException,
    RequestContext,
    ResponseContext,
  )
  onError;

  /// The root of Twitter's API. Defaults to `'https://api.twitter.com'`.
  final Uri baseUrl;

  /// How long a request token is kept, waiting for its callback.
  final Duration requestTokenLifetime;

  /// The most request tokens kept at once; the oldest are dropped first.
  final int maxPendingRequestTokens;

  /// Signs the request token and access token requests with the consumer
  /// credentials from [options].
  final oauth.Authorization authorization;

  // Request token -> its secret, oldest first.
  final LinkedHashMap<String, (String, DateTime)> _pending = LinkedHashMap();

  TwitterStrategy(
    this.options,
    this.verifier,
    this.onError, {
    http.BaseClient? client,
    Uri? baseUrl,
    this.requestTokenLifetime = const Duration(minutes: 15),
    this.maxPendingRequestTokens = 10000,
  }) : baseUrl = baseUrl ?? Uri.parse('https://api.twitter.com'),
       authorization = oauth.Authorization(
         oauth.ClientCredentials(options.clientId, options.clientSecret),
         oauth.Platform(
           _endpoint(baseUrl, 'oauth/request_token'),
           _endpoint(baseUrl, 'oauth/authorize'),
           _endpoint(baseUrl, 'oauth/access_token'),
           oauth.SignatureMethods.hmacSha1,
         ),
         client,
       );

  static String _endpoint(Uri? baseUrl, String path) {
    var base = baseUrl ?? Uri.parse('https://api.twitter.com');
    // p.url, not p: the host's separator would be '\' on Windows.
    return base.replace(path: p.url.join(base.path, path)).toString();
  }

  /// Handle a url-encoded response from Twitter.
  ///
  /// Throws [TwitterAuthorizationException] for an error response, whether
  /// its body is JSON (`{"errors": [{"message": ...}]}`) or plain text.
  Future<Map<String, String>> handleUrlEncodedResponse(http.Response rs) async {
    if (rs.statusCode != 200) {
      throw TwitterAuthorizationException(_errorMessage(rs.body), false);
    }
    return Uri.splitQueryString(rs.body);
  }

  static String _errorMessage(String body) {
    try {
      var err = json.decode(body);
      if (err is Map && err['errors'] is List) {
        var errors = err['errors'] as List;
        if (errors.isNotEmpty &&
            errors.first is Map &&
            errors.first['message'] is String) {
          return errors.first['message'] as String;
        }
      }
    } on FormatException {
      // Not JSON; use the body as it is.
    }
    return body.trim().isEmpty
        ? 'Twitter returned an error response without an error message.'
        : body.trim();
  }

  /// Runs an [authorization] request, turning Twitter's error responses into
  /// [TwitterAuthorizationException]s.
  Future<oauth.AuthorizationResponse> _authorize(
    Future<oauth.AuthorizationResponse> Function() request,
  ) async {
    try {
      return await request();
    } on StateError catch (e) {
      // belatuk_oauth1 throws a StateError with the body of an error response.
      throw TwitterAuthorizationException(_errorMessage(e.message), false);
    }
  }

  /// Get an access token, from the request [token] and [verifier] that Twitter
  /// sent to the callback.
  ///
  /// The request token must have come from [getRequestToken] on this
  /// strategy, within [requestTokenLifetime], and can be used once.
  Future<Map<String, String>> getAccessToken(
    String token,
    String verifier,
  ) async {
    var secret = _takeRequestTokenSecret(token);
    if (secret == null) {
      throw TwitterAuthorizationException(
        'Unknown or expired request token.',
        false,
      );
    }
    var rs = await _authorize(
      () => authorization.requestTokenCredentials(
        oauth.Credentials(token, secret),
        verifier,
      ),
    );
    return {
      'oauth_token': rs.credentials.token,
      'oauth_token_secret': rs.credentials.tokenSecret,
      ...rs.optionalParameters,
    };
  }

  /// Get a request token, signed with the consumer credentials only.
  Future<Map<String, String>> getRequestToken() async {
    var rs = await _authorize(
      () => authorization.requestTemporaryCredentials(
        options.redirectUri.toString(),
      ),
    );
    _keepRequestTokenSecret(rs.credentials.token, rs.credentials.tokenSecret);
    return {
      'oauth_token': rs.credentials.token,
      'oauth_token_secret': rs.credentials.tokenSecret,
    };
  }

  void _keepRequestTokenSecret(String token, String secret) {
    _dropExpired();
    while (_pending.length >= maxPendingRequestTokens && _pending.isNotEmpty) {
      _pending.remove(_pending.keys.first);
    }
    _pending[token] = (secret, DateTime.now().add(requestTokenLifetime));
  }

  String? _takeRequestTokenSecret(String token) {
    _dropExpired();
    return _pending.remove(token)?.$1;
  }

  void _dropExpired() {
    var now = DateTime.now();
    while (_pending.isNotEmpty && _pending.values.first.$2.isBefore(now)) {
      _pending.remove(_pending.keys.first);
    }
  }

  static bool _isCallback(RequestContext req) {
    var query = req.queryParameters;
    return query.containsKey('oauth_token') ||
        query.containsKey('oauth_verifier') ||
        query.containsKey('denied');
  }

  @override
  Future<TUser?> authenticate(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions? options,
  ]) async {
    try {
      // AngelAuth always passes options, so the callback is recognized by
      // Twitter's parameters instead.
      if (_isCallback(req)) {
        return await authenticateCallback(req, res, options);
      }

      var token = (await getRequestToken())['oauth_token']!;
      await res.redirect(authorization.getResourceOwnerAuthorizationURI(token));
      return null;
    } on TwitterAuthorizationException catch (e) {
      var result = await onError(e, req, res);
      await req.app?.executeHandler(result, req, res);
      await res.close();
      return null;
    }
  }

  /// Handles Twitter's callback request.
  ///
  /// Throws [TwitterAuthorizationException] when the user denied access, the
  /// request is missing Twitter's parameters, or Twitter rejects the token;
  /// [authenticate] passes it to [onError].
  Future<TUser?> authenticateCallback(
    RequestContext req,
    ResponseContext res, [
    AngelAuthOptions? options,
  ]) async {
    var query = req.queryParameters;
    if (query.containsKey('denied')) {
      _takeRequestTokenSecret('${query['denied']}');
      throw TwitterAuthorizationException(
        'The user denied the Twitter authorization attempt.',
        true,
      );
    }

    var token = query['oauth_token'];
    var verifier = query['oauth_verifier'];
    if (token is! String ||
        token.isEmpty ||
        verifier is! String ||
        verifier.isEmpty) {
      throw TwitterAuthorizationException(
        'The callback is missing oauth_token or oauth_verifier.',
        false,
      );
    }

    var loginData = await getAccessToken(token, verifier);
    var twitter = TwitterApi(
      client: TwitterClient(
        consumerKey: this.options.clientId,
        consumerSecret: this.options.clientSecret,
        token: loginData['oauth_token'] ?? '',
        secret: loginData['oauth_token_secret'] ?? '',
      ),
    );

    return await this.verifier(twitter, req, res);
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
