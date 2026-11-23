/// A path parameter of a route, as OpenAPI describes it.
class PathParameter {
  /// Its name, as `id` of `:id`.
  final String name;

  /// Its JSON Schema: an `integer` of `int:id`, a `number` of `double:x` or
  /// `num:x`, a `string` with a `pattern` of `:id([0-9]+)`, or a `string`.
  final Map<String, dynamic> schema;

  const PathParameter(this.name, this.schema);
}

/// A route's path as OpenAPI writes it, as `/users/{id}`, with its
/// parameters.
class OpenApiPath {
  final String path;
  final List<PathParameter> parameters;

  const OpenApiPath(this.path, this.parameters);
}

/// A parameter segment of a route: an optional type (`int`, `num`,
/// `double`), text before it, `:name`, text after it, an optional `?`, and
/// an optional regular expression in parentheses, with text after it.
final RegExp _parameterSegment = RegExp(
  r'^(int|num|double)?([^:]*):([A-Za-z0-9_]+)([^(?]*)(\?)?(?:\((.+)\)(.*))?$',
);

/// The OpenAPI paths of an Angel3 route [path], such as `users/:id` or
/// `files/int:id?`: two of an optional parameter, with and without it, and
/// none of a path with a wildcard (`*`), which OpenAPI cannot describe.
List<OpenApiPath> openApiPathsOf(String path) {
  var segments = path.split('/').where((s) => s.isNotEmpty).toList();
  // Each segment: its text in the path, its parameter, whether optional.
  var parts = <(String, PathParameter?, bool)>[];
  for (var segment in segments) {
    if (segment.contains('*')) return const [];
    var match = _parameterSegment.firstMatch(segment);
    if (match == null) {
      parts.add((segment, null, false));
      continue;
    }
    var type = match[1];
    var name = match[3]!;
    var pattern = match[6];
    var schema = switch (type) {
      'int' => <String, dynamic>{'type': 'integer'},
      'num' || 'double' => <String, dynamic>{'type': 'number'},
      _ => <String, dynamic>{
        'type': 'string',
        if (pattern != null) 'pattern': '^$pattern\$',
      },
    };
    var text = '${match[2]}{$name}${match[4]}${match[7] ?? ''}';
    parts.add((text, PathParameter(name, schema), match[5] == '?'));
  }

  // Each optional parameter may be left out: of `a/:b?`, `/a` and `/a/{b}`.
  var variants = <List<(String, PathParameter?, bool)>>[[]];
  for (var part in parts) {
    variants = [
      for (var v in variants) ...[
        [...v, part],
        if (part.$3) v,
      ],
    ];
  }
  return [
    for (var v in variants)
      OpenApiPath('/${v.map((p) => p.$1).join('/')}', [for (var p in v) ?p.$2]),
  ];
}
