import 'package:angel3_auth_server/angel3_auth_server.dart';

/// The error codes of OpenID Connect of an authorization request (OpenID
/// Connect Core 1.0 §3.1.2.6), of `prompt=none`, of which the user would
/// have had to be prompted.
abstract final class OpenIdErrors {
  /// The user must sign in.
  static const loginRequired = 'login_required';

  /// The user must consent to the client.
  static const consentRequired = 'consent_required';

  /// The user must select one of the accounts they are signed in to.
  static const accountSelectionRequired = 'account_selection_required';

  /// The user must interact with the provider, of another reason.
  static const interactionRequired = 'interaction_required';
}

/// What the provider must do with the user before it issues a code, of
/// [OpenIdRequest.interactions].
enum OpenIdInteraction {
  /// Sign the user in, again, as they are not, or not recently enough.
  login,

  /// Let the user select an account, of `prompt=select_account`.
  selectAccount,

  /// Ask the user to consent to the client.
  consent,
}

/// The OpenID Connect metadata of a client (OpenID Connect Dynamic Client
/// Registration 1.0 §2), of the `metadata` of its [ClientRegistration], as
/// `OpenIdServer.checkClientMetadata` checked it, of their defaults.
class OpenIdClientMetadata {
  /// The URIs that the provider may redirect to once the user signed out
  /// (OpenID Connect RP-Initiated Logout 1.0 §3.1).
  final List<Uri> postLogoutRedirectUris;

  /// The algorithm of the ID tokens of the client: `RS256` by default.
  final String idTokenSignedResponseAlg;

  /// The `max_age` of the authorization requests of the client that give
  /// none, in seconds, if any.
  final int? defaultMaxAge;

  /// Whether each ID token of the client must have an `auth_time`.
  final bool requireAuthTime;

  /// `web`, by default, or `native`.
  final String applicationType;

  /// `public`, of the subjects that the provider gives.
  final String subjectType;

  OpenIdClientMetadata({
    this.postLogoutRedirectUris = const [],
    this.idTokenSignedResponseAlg = 'RS256',
    this.defaultMaxAge,
    this.requireAuthTime = false,
    this.applicationType = 'web',
    this.subjectType = 'public',
  });

  /// The metadata of the client of [metadata], the metadata of a
  /// [ClientRegistration] that `checkClientMetadata` checked.
  factory OpenIdClientMetadata.of(Map<String, dynamic> metadata) =>
      OpenIdClientMetadata(
        postLogoutRedirectUris: [
          for (var uri
              in (metadata['post_logout_redirect_uris'] as List?) ?? const [])
            Uri.parse(uri as String),
        ],
        idTokenSignedResponseAlg:
            metadata['id_token_signed_response_alg'] as String? ?? 'RS256',
        defaultMaxAge: metadata['default_max_age'] as int?,
        requireAuthTime: metadata['require_auth_time'] as bool? ?? false,
        applicationType: metadata['application_type'] as String? ?? 'web',
        subjectType: metadata['subject_type'] as String? ?? 'public',
      );
}

/// A request to end the session of a user (OpenID Connect RP-Initiated
/// Logout 1.0 §2), of `OpenIdServer.endSessionEndpoint`, which
/// `OpenIdServer.endSession` is given, once it is checked.
class EndSessionRequest<Client> {
  /// The `sub` of the `id_token_hint`, if the request had one: the user the
  /// client signed in, whom it asks to sign out.
  final String? subject;

  /// The client of the request, of the audience of its `id_token_hint`, or
  /// of its `client_id`; `null` if it gave neither.
  final Client? client;

  /// Whether the request had an `id_token_hint` of the provider: of none,
  /// the provider should ask the user whether to sign out, as anyone could
  /// send them a link to it.
  final bool hasIdTokenHint;

  /// The `post_logout_redirect_uri` of the request, which is one of the
  /// client's, if it gave one.
  final Uri? postLogoutRedirectUri;

  /// The `state` of the request, which the redirect gives back.
  final String? state;

  EndSessionRequest({
    this.subject,
    this.client,
    this.hasIdTokenHint = false,
    this.postLogoutRedirectUri,
    this.state,
  });

  /// The URI to redirect the user to, once they signed out: the
  /// [postLogoutRedirectUri], of the [state], or `null` of none.
  Uri? get redirectUri {
    var uri = postLogoutRedirectUri;
    if (uri == null) return null;
    var state = this.state;
    if (state == null || state.isEmpty) return uri;
    var added = Uri(queryParameters: {'state': state}).query;
    return uri.replace(
      query: uri.query.isEmpty ? added : '${uri.query}&$added',
    );
  }
}
