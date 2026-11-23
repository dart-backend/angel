import 'dart:async';
import 'dart:convert';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:http_parser/http_parser.dart';

import 'operation.dart';
import 'path.dart';

/// The HTTP methods of an OpenAPI Path Item.
const _methods = {
  'GET',
  'PUT',
  'POST',
  'DELETE',
  'OPTIONS',
  'HEAD',
  'PATCH',
  'TRACE',
};

/// An OpenAPI 3.1 document of an Angel3 app, built from its routes and the
/// services it mounts, which [configureServer] serves with a Swagger UI
/// page.
///
/// ```dart
/// var openApi = OpenApi(title: 'Todo API', version: '1.0.0');
/// await app.configure(openApi.configureServer);
/// ```
///
/// Each route of a method and a path gives an operation, with its path
/// parameters: `GET /users/:id` is `GET /users/{id}`. [describe] adds what a
/// route cannot tell: a summary, query parameters, request and response
/// schemas. A service mounted with `app.use` gives its operations itself,
/// whose schemas [describeService] gives.
class OpenApi {
  /// The `title` and `version` of the API, in the document's `info`.
  final String title, version;

  /// The `description` of the API, in the document's `info`.
  final String? description;

  /// The URLs that serve the API, as `https://api.example.com`.
  final List<String> servers;

  /// The schemas of `components`, by name, which [ref] refers to.
  final Map<String, Map<String, dynamic>> schemas;

  /// The path that serves the document, `openapi.json` by default.
  final String documentPath;

  /// The path that serves the Swagger UI page, `docs` by default, or
  /// `null` for none.
  final String? uiPath;

  /// Where the Swagger UI page loads Swagger UI from: `swagger-ui.css` and
  /// `swagger-ui-bundle.js` of this URL.
  final String swaggerUiUrl;

  /// Whether a route is documented; by default, every route of a method of
  /// OpenAPI without a wildcard.
  final bool Function(Route<RequestHandler> route)? include;

  /// More of the OpenAPI Object, as `components.securitySchemes` or
  /// `security`, which replaces what the rest of it gives.
  final Map<String, dynamic> extra;

  final Map<String, OpenApiOperation> _described = {};
  final Map<String, (Map<String, dynamic>?, String?)> _services = {};
  Map<String, dynamic>? _cached;

  OpenApi({
    required this.title,
    this.version = '1.0.0',
    this.description,
    this.servers = const [],
    this.schemas = const {},
    this.documentPath = 'openapi.json',
    this.uiPath = 'docs',
    this.swaggerUiUrl = 'https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.34.1',
    this.include,
    this.extra = const {},
  });

  /// The schemas of `@serializable` models, for [schemas], of the
  /// `addJsonSchemas` of their serializers, which add the schemas of the
  /// models each holds:
  ///
  /// ```dart
  /// OpenApi(
  ///   title: 'Todo API',
  ///   schemas: OpenApi.schemasOf([TodoSerializer.addJsonSchemas]),
  /// );
  /// ```
  static Map<String, Map<String, dynamic>> schemasOf(
    Iterable<void Function(Map<String, Map<String, dynamic>> schemas)> adders,
  ) {
    var schemas = <String, Map<String, dynamic>>{};
    for (var add in adders) {
      add(schemas);
    }
    return schemas;
  }

  /// A JSON Schema that refers to the schema [name] of [schemas].
  static Map<String, dynamic> ref(String name) => {
    r'$ref': '#/components/schemas/$name',
  };

  /// Describes the operation of [method] and [path], written as the route
  /// is, as `users/:id`, or as OpenAPI writes it, as `/users/{id}`.
  void describe(String method, String path, OpenApiOperation operation) {
    for (var p in openApiPathsOf(path)) {
      _described['${method.toUpperCase()} ${p.path}'] = operation;
    }
    _cached = null;
  }

  /// Gives the JSON Schema of the items of the service mounted at [path],
  /// and the tag of its operations, which is its path by default.
  void describeService(
    String path, {
    Map<String, dynamic>? schema,
    String? tag,
  }) {
    _services[_strip(path)] = (schema, tag);
    _cached = null;
  }

  static String _strip(String path) => path.replaceAll(RegExp(r'^/+|/+$'), '');

  /// The OpenAPI document of [app], as JSON. In production it is built
  /// once.
  Map<String, dynamic> documentOf(Angel app) {
    if (app.environment.isProduction) return _cached ??= _build(app);
    return _build(app);
  }

  Map<String, dynamic> _build(Angel app) {
    var paths = <String, Map<String, dynamic>>{};
    void add(String method, String path, Map<String, dynamic> operation) {
      paths.putIfAbsent(path, () => {})[method.toLowerCase()] ??= operation;
    }

    // The services first: their routes are documented as theirs.
    var servicePaths = <String>{};
    for (var MapEntry(:key, :value) in app.services.entries) {
      if (key is! String) continue;
      var base = _strip(key);
      servicePaths
        ..add(base)
        ..add(_strip('$base/:id'));
      for (var (method, path, operation) in _serviceOperations(base, value)) {
        add(method, path, operation);
      }
    }

    var annotated = _controllerOperations(app);
    var own = {_strip(documentPath), if (uiPath != null) _strip(uiPath!)};
    for (var route in flatten<RequestHandler>(app).routes) {
      var method = route.method.toUpperCase();
      var path = _strip(route.path);
      if (!_methods.contains(method)) continue;
      if (own.contains(path) || servicePaths.contains(path)) continue;
      if (include != null && !include!(route)) continue;
      for (var p in openApiPathsOf(path)) {
        var described =
            _described['$method ${p.path}'] ??
            (route.handlers.isEmpty ? null : annotated[route.handlers.last]);
        add(
          method,
          p.path,
          _operation(p.parameters, described, operationId: route.name),
        );
      }
    }

    return {
      'openapi': '3.1.0',
      'info': {
        'title': title,
        'version': version,
        if (description != null) 'description': description,
      },
      if (servers.isNotEmpty)
        'servers': [
          for (var url in servers) {'url': url},
        ],
      'paths': paths,
      if (schemas.isNotEmpty) 'components': {'schemas': schemas},
      ...extra,
    };
  }

  /// The `@OpenApiOperation` annotations of the methods of the app's
  /// controllers, by the handler of the route of each, which a flattened
  /// route keeps as its last handler. A controller whose class its
  /// reflector cannot reflect has none.
  Map<Function, OpenApiOperation> _controllerOperations(Angel app) {
    var operations = <Function, OpenApiOperation>{};
    var reflector = app.container.reflector;
    for (var controller in app.controllers.values) {
      ReflectedClass? clazz;
      try {
        clazz = reflector.reflectClass(controller.runtimeType);
      } on ArgumentError {
        continue;
      } on UnsupportedError {
        continue;
      }
      for (var declaration in clazz?.declarations ?? const []) {
        var annotations = [
          for (var a in declaration.function?.annotations ?? const [])
            a.reflectee,
        ];
        var operation = annotations.whereType<OpenApiOperation>().firstOrNull;
        if (operation == null) continue;
        // The name of its route, as `Controller` gives it.
        var expose = annotations.whereType<Expose>().firstOrNull;
        var name = expose?.as?.isNotEmpty == true
            ? expose!.as!
            : declaration.name;
        var route = controller.routeMappings[name];
        if (route == null || route.handlers.isEmpty) continue;
        operations[route.handlers.last] = operation;
      }
    }
    return operations;
  }

  /// The operations of the service mounted at [base]: those of its routes
  /// that serve its methods, as `GET /todos` of `index`, which [describe]
  /// may replace. Of the other routes, `POST /todos/:id` is another way to
  /// `update`, and `DELETE /todos` (`remove` of all) is refused by most
  /// services.
  Iterable<(String, String, Map<String, dynamic>)> _serviceOperations(
    String base,
    Service service,
  ) sync* {
    var (schema, tag) = _services[base] ?? (null, null);
    var tags = [tag ?? base];
    var name = base.split('/').last;
    var collection = '/$base';
    var item = '/$base/{id}';
    var id = const PathParameter('id', {'type': 'string'});
    var notFound = {404: const OpenApiResponse('Not found')};
    var list = schema == null ? null : {'type': 'array', 'items': schema};

    Map<String, dynamic> operation(
      String method,
      String path,
      OpenApiOperation defaults,
      List<PathParameter> parameters,
    ) => _operation(parameters, _described['$method $path'] ?? defaults);

    yield (
      'GET',
      collection,
      operation(
        'GET',
        collection,
        OpenApiOperation(
          summary: 'List the items of $name',
          operationId: '${name}Index',
          tags: tags,
          responses: {200: OpenApiResponse('The items', schema: list)},
        ),
        [],
      ),
    );
    yield (
      'POST',
      collection,
      operation(
        'POST',
        collection,
        OpenApiOperation(
          summary: 'Create an item of $name',
          operationId: '${name}Create',
          tags: tags,
          requestBody: schema,
          responses: {200: OpenApiResponse('The item created', schema: schema)},
        ),
        [],
      ),
    );
    yield (
      'GET',
      item,
      operation(
        'GET',
        item,
        OpenApiOperation(
          summary: 'Read an item of $name',
          operationId: '${name}Read',
          tags: tags,
          responses: {
            200: OpenApiResponse('The item', schema: schema),
            ...notFound,
          },
        ),
        [id],
      ),
    );
    yield (
      'PATCH',
      item,
      operation(
        'PATCH',
        item,
        OpenApiOperation(
          summary: 'Modify an item of $name, of the fields given',
          operationId: '${name}Modify',
          tags: tags,
          requestBody: schema,
          responses: {
            200: OpenApiResponse('The item modified', schema: schema),
            ...notFound,
          },
        ),
        [id],
      ),
    );
    yield (
      'PUT',
      item,
      operation(
        'PUT',
        item,
        OpenApiOperation(
          summary: 'Replace an item of $name',
          operationId: '${name}Update',
          tags: tags,
          requestBody: schema,
          responses: {
            200: OpenApiResponse('The item replaced', schema: schema),
            ...notFound,
          },
        ),
        [id],
      ),
    );
    yield (
      'DELETE',
      item,
      operation(
        'DELETE',
        item,
        OpenApiOperation(
          summary: 'Remove an item of $name',
          operationId: '${name}Remove',
          tags: tags,
          responses: {
            200: OpenApiResponse('The item removed', schema: schema),
            ...notFound,
          },
        ),
        [id],
      ),
    );
  }

  Map<String, dynamic> _operation(
    List<PathParameter> pathParameters,
    OpenApiOperation? described, {
    String? operationId,
  }) {
    var op = described ?? const OpenApiOperation();
    var parameters = [
      for (var p in pathParameters)
        {'name': p.name, 'in': 'path', 'required': true, 'schema': p.schema},
      for (var MapEntry(:key, :value) in op.queryParameters.entries)
        {'name': key, 'in': 'query', 'schema': value},
    ];
    return {
      if (op.summary != null) 'summary': op.summary,
      if (op.description != null) 'description': op.description,
      'operationId': ?(op.operationId ?? operationId),
      if (op.tags.isNotEmpty) 'tags': op.tags,
      if (op.deprecated) 'deprecated': true,
      if (parameters.isNotEmpty) 'parameters': parameters,
      if (op.requestBody case var body?)
        'requestBody': {
          'required': true,
          'content': {
            'application/json': {'schema': body},
          },
        },
      'responses': op.responses.isEmpty
          ? {
              '200': {'description': 'OK'},
            }
          : {
              for (var MapEntry(:key, :value) in op.responses.entries)
                '$key': value.toJson(),
            },
      ...op.extra,
    };
  }

  /// Serves the document at [documentPath], and the Swagger UI page at
  /// [uiPath]. The document is of the app's routes when it is asked for,
  /// so routes added after this are documented too.
  FutureOr<void> configureServer(Angel app) {
    app.get(documentPath, (req, res) {
      res.json(documentOf(app));
      return false;
    });
    if (uiPath case var uiPath?) {
      app.get(uiPath, (req, res) {
        res
          ..contentType = MediaType('text', 'html', {'charset': 'utf-8'})
          ..write(swaggerUiPage('/${_strip(documentPath)}'));
        return false;
      });
    }
  }

  /// The Swagger UI page of the document at [documentUrl].
  String swaggerUiPage(String documentUrl) {
    var escape = const HtmlEscape();
    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escape.convert(title)}</title>
  <link rel="stylesheet" href="${escape.convert(swaggerUiUrl)}/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="${escape.convert(swaggerUiUrl)}/swagger-ui-bundle.js" crossorigin></script>
  <script>
    window.onload = () => {
      window.ui = SwaggerUIBundle({url: ${jsonEncode(documentUrl)}, dom_id: '#swagger-ui'});
    };
  </script>
</body>
</html>
''';
  }
}
