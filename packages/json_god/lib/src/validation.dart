part of angel3_json_god;

/// Thrown when schema validation fails.
class JsonValidationError implements Exception {
  //final Schema schema;
  final invalidData;
  final String cause;

  const JsonValidationError(
      String this.cause, this.invalidData); //, Schema this.schema);
}

/// Specifies a schema to validate a class with.
class WithSchema {
  final Map schema;

  const WithSchema(Map this.schema);
}

/// Specifies a schema to validate a class with.
class WithSchemaUrl {
  final String schemaUrl;

  const WithSchemaUrl(String this.schemaUrl);
}
