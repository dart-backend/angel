/// A response of an [OpenApiOperation].
class OpenApiResponse {
  /// What the response means, such as `The user`.
  final String description;

  /// The JSON Schema of its JSON body, if it has one, as
  /// `OpenApi.ref('User')`.
  final Map<String, dynamic>? schema;

  const OpenApiResponse(this.description, {this.schema});

  Map<String, dynamic> toJson() => {
    'description': description,
    if (schema case var schema?)
      'content': {
        'application/json': {'schema': schema},
      },
  };
}

/// What [OpenApi.describe] says of an operation, a route of a method and a
/// path, beyond what its route gives.
///
/// It is also an annotation of a `Controller`'s method, which
/// `OpenApi.documentOf` reads through the app's reflector:
/// `@OpenApiOperation(summary: 'Read a user')`.
class OpenApiOperation {
  final String? summary, description, operationId;
  final List<String> tags;
  final bool deprecated;

  /// The query parameters it reads, by name, each with its JSON Schema.
  final Map<String, Map<String, dynamic>> queryParameters;

  /// The JSON Schema of the JSON body of its request, if it reads one.
  final Map<String, dynamic>? requestBody;

  /// Its responses, by status code. Without any, it is documented with a
  /// `200`.
  final Map<int, OpenApiResponse> responses;

  /// More of the OpenAPI Operation Object, as `security`, which replaces
  /// what the rest of it gives.
  final Map<String, dynamic> extra;

  const OpenApiOperation({
    this.summary,
    this.description,
    this.operationId,
    this.tags = const [],
    this.deprecated = false,
    this.queryParameters = const {},
    this.requestBody,
    this.responses = const {},
    this.extra = const {},
  });
}
