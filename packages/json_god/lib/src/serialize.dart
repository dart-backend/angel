part of angel3_json_god;

/// Serializes any arbitrary Dart datum to JSON. Supports schema validation.
String serialize(value) {
  var serialized = serializeObject(value);
  logger.info('Serialization result: $serialized');
  return json.encode(serialized);
}

/// Transforms any Dart datum into a value acceptable to json.encode.
serializeObject(value) {
  if (_isPrimitive(value)) {
    logger.info("Serializing primitive value: $value");
    return value;
  } else if (value is DateTime) {
    logger.info("Serializing this DateTime: $value");
    return value.toIso8601String();
  } else if (value is Iterable) {
    logger.info("Serializing this Iterable: $value");
    return value.map(serializeObject).toList();
  } else if (value is Map) {
    logger.info("Serializing this Map: $value");
    return serializeMap(value);
  } else
    return serializeObject(reflection.serialize(value, serializeObject));
}

/// Recursively transforms a Map and its children into JSON-serializable data.
Map serializeMap(Map value) {
  Map outputMap = {};
  value.forEach((key, value) {
    outputMap[key] = serializeObject(value);
  });
  return outputMap;
}
