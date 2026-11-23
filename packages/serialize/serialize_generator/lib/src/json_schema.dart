part of 'serialize_generator.dart';

/// The Dart source of [text], in single quotes, or in double quotes if it
/// has a `'` but no `"`, as `"Missing required field 'name'"`.
String _dartString(String text) {
  var quote = text.contains("'") && !text.contains('"') ? '"' : "'";
  var escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll(quote, '\\$quote')
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return '$quote$escaped$quote';
}

/// The Dart source of a JSON value, of strings, numbers, booleans, `null`,
/// lists and maps.
String _dartLiteral(Object? value) => switch (value) {
  null => 'null',
  bool() || num() => '$value',
  String() => _dartString(value),
  List() => '[${value.map(_dartLiteral).join(', ')}]',
  Map() =>
    '{${value.entries.map((e) => '${_dartLiteral(e.key)}: ${_dartLiteral(e.value)}').join(', ')}}',
  _ => throw ArgumentError.value(value, 'value', 'is not JSON'),
};

/// The JSON Schema (2020-12, as OpenAPI 3.1 has it) of a value of [type] as
/// `toMap` writes it, which may be `null` if [type] is nullable, unless
/// [nullable] says otherwise. A model class is a `$ref` to its schema in
/// `#/components/schemas`, whose name is added to [models].
Map<String, dynamic> _jsonSchemaOf(
  DartType type,
  Set<String> models, {
  bool? nullable,
}) {
  Map<String, dynamic> schema;
  if (type is DynamicType || type.isDartCoreObject) {
    return {};
  } else if (isModelClass(type)) {
    var name = modelClassNameOf(type);
    models.add(name);
    schema = {r'$ref': '#/components/schemas/$name'};
  } else if (type.isDartCoreString) {
    schema = {'type': 'string'};
  } else if (type.isDartCoreInt) {
    schema = {'type': 'integer'};
  } else if (type.isDartCoreDouble || type.isDartCoreNum) {
    schema = {'type': 'number'};
  } else if (type.isDartCoreBool) {
    schema = {'type': 'boolean'};
  } else if (dateTimeTypeChecker.isAssignableFromType(type)) {
    schema = {'type': 'string', 'format': 'date-time'};
  } else if (type is InterfaceType && type.element is EnumElement) {
    // Written as its index.
    var names = [
      for (var f in (type.element as EnumElement).fields)
        if (f.isEnumConstant) f.name,
    ];
    schema = {
      'type': 'integer',
      'enum': [for (var i = 0; i < names.length; i++) i],
      'description': 'The index of ${type.element.name}: ${names.join(', ')}',
    };
  } else if (const TypeChecker.typeNamed(Uint8List)
      .isAssignableFromType(type)) {
    // Written as base64 text.
    schema = {'type': 'string', 'contentEncoding': 'base64'};
  } else if (type is InterfaceType && type.isDartCoreList) {
    var items = type.typeArguments.isEmpty
        ? const <String, dynamic>{}
        : _jsonSchemaOf(type.typeArguments.first, models);
    schema = {'type': 'array', if (items.isNotEmpty) 'items': items};
  } else if (type is InterfaceType && type.isDartCoreMap) {
    var values = type.typeArguments.length < 2
        ? const <String, dynamic>{}
        : _jsonSchemaOf(type.typeArguments[1], models);
    schema = {
      'type': 'object',
      if (values.isNotEmpty) 'additionalProperties': values,
    };
  } else {
    return {};
  }

  if (!(nullable ?? type.nullabilitySuffix == NullabilitySuffix.question)) {
    return schema;
  }
  if (schema['type'] case String t) {
    return {
      ...schema,
      'type': [t, 'null'],
      // `enum` lists every value allowed, so `null` too.
      if (schema['enum'] case List values) 'enum': [...values, null],
    };
  }
  return {
    'anyOf': [
      schema,
      {'type': 'null'},
    ],
  };
}

/// The JSON Schema of the map that `toMap` writes of [ctx]'s model, and the
/// names of the model classes that it refers to.
(Map<String, dynamic>, Set<String>) _modelJsonSchema(BuildContext ctx) {
  var models = <String>{};
  var properties = <String, dynamic>{};
  var required = <String>[];

  for (var field in ctx.fields) {
    var name = field.name ?? '';
    if (ctx.excluded[name]?.canSerialize == false) continue;
    var alias = ctx.resolveFieldName(name) ?? name;
    var info = ctx.fieldInfo[name];

    // A custom serializer writes what its `serializesTo` says, if anything.
    properties[alias] = info?.serializer != null && info?.serializesTo == null
        ? <String, dynamic>{}
        : _jsonSchemaOf(
            ctx.resolveSerializedFieldType(name),
            models,
            // `toMap` throws of a required field that is `null`.
            nullable: ctx.requiredFields.containsKey(name) ? false : null,
          );

    // Of those that `fromMap` cannot do without: one of
    // `isNullable: false`, or a value it casts, without a default.
    var type = field.type;
    var deserialized =
        ctx.excluded[name]?.canDeserialize != false &&
        info?.deserializer == null;
    var cast =
        type.isDartCoreString ||
        type.isDartCoreInt ||
        type.isDartCoreDouble ||
        type.isDartCoreNum ||
        type.isDartCoreBool ||
        isModelClass(type);
    if (deserialized &&
        (ctx.requiredFields.containsKey(name) ||
            (cast &&
                type.nullabilitySuffix != NullabilitySuffix.question &&
                ctx.defaults[name] == null))) {
      required.add(alias);
    }
  }

  return (
    {
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    },
    models,
  );
}

/// Adds `schemaName`, `jsonSchema` and `addJsonSchemas` to the serializer
/// [clazz] of [ctx]'s model, for an OpenAPI document's
/// `components.schemas`.
void _addJsonSchema(ClassBuilder clazz, BuildContext ctx) {
  var name = ctx.modelClassName!;
  var (schema, models) = _modelJsonSchema(ctx);
  clazz.fields.add(
    Field(
      (b) => b
        ..docs.add('/// The name of the JSON Schema of [$name].')
        ..static = true
        ..modifier = FieldModifier.constant
        ..type = refer('String')
        ..name = 'schemaName'
        ..assignment = Code(_dartLiteral(name)),
    ),
  );
  clazz.fields.add(
    Field(
      (b) => b
        ..docs.addAll([
          '/// The JSON Schema of the map that [toMap] writes of [$name], whose',
          '/// models are `\$ref`s to `#/components/schemas`.',
        ])
        ..static = true
        ..modifier = FieldModifier.constant
        ..type = refer('Map<String, dynamic>')
        ..name = 'jsonSchema'
        ..assignment = Code(_dartLiteral(schema)),
    ),
  );
  clazz.methods.add(
    Method(
      (b) => b
        ..docs.addAll([
          '/// Adds the JSON Schema of [$name], and those of the models it',
          '/// holds, to [schemas], by name.',
        ])
        ..static = true
        ..returns = refer('void')
        ..name = 'addJsonSchemas'
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'schemas'
              ..type = refer('Map<String, Map<String, dynamic>>'),
          ),
        )
        ..body = Block.of([
          Code('if (schemas.containsKey(schemaName)) return;'),
          Code('schemas[schemaName] = jsonSchema;'),
          for (var model in models.where((m) => m != name))
            Code('${model}Serializer.addJsonSchemas(schemas);'),
        ]),
    ),
  );
}
