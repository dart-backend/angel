/// A way a request is authenticated, as with a JWT in a `Bearer`
/// `Authorization` header: its [name], and its [definition], an OpenAPI
/// Security Scheme Object, which documents of an API, such as the OpenAPI
/// documents of `angel3_openapi`, list.
final class SecurityScheme {
  /// The name of the scheme, by which documents refer to it.
  final String name;

  /// The OpenAPI Security Scheme Object of the scheme, as
  /// `{'type': 'http', 'scheme': 'bearer'}`.
  final Map<String, dynamic> definition;

  const SecurityScheme(this.name, this.definition);

  /// A JWT in a `Bearer` `Authorization` header, as `angel3_auth` takes.
  static const SecurityScheme bearer = SecurityScheme('bearer', {
    'type': 'http',
    'scheme': 'bearer',
    'bearerFormat': 'JWT',
  });

  /// A user name and password in a `Basic` `Authorization` header.
  static const SecurityScheme basic = SecurityScheme('basic', {
    'type': 'http',
    'scheme': 'basic',
  });
}

/// What a request handler, as a middleware of `angel3_auth`, requires of a
/// request: to be authenticated by one of [schemes]; it responds [status]
/// to one that is not.
///
/// A handler is tagged with [tag], and its requirements read with [of], so
/// that documents of an API list the requirements of the routes it is a
/// handler of. The handler that [chain] makes of others has their
/// requirements, each of which a request must meet.
final class SecurityRequirement {
  static final Expando<List<SecurityRequirement>> _requirements = Expando(
    'securityRequirements',
  );

  /// The schemes, any one of which authenticates a request.
  final List<SecurityScheme> schemes;

  /// The status of the response to a request that is not authenticated.
  final int status;

  const SecurityRequirement(this.schemes, {this.status = 401});

  /// Tags [handler] with this requirement, besides those it has, and
  /// returns it.
  H tag<H extends Function>(H handler) {
    var requirements = _requirements[handler] ??= [];
    if (!requirements.contains(this)) requirements.add(this);
    return handler;
  }

  /// The requirements [handler] is tagged with, each of which a request
  /// must meet: none if it is not tagged.
  static List<SecurityRequirement> of(Function handler) =>
      List.unmodifiable(_requirements[handler] ?? const []);
}
