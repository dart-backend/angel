part of angel3_json_god;

/// Deserializes a JSON string into a Dart datum.
///
/// You can also provide an output Type to attempt to serialize the JSON into.
deserialize(String json, {Type? outputType}) {
  var deserialized = deserializeJson(json, outputType: outputType);
  logger.info("Deserialization result: $deserialized");
  return deserialized;
}

/// Deserializes JSON into data, without validating it.
deserializeJson(String s, {Type? outputType}) {
  logger.info("Deserializing the following JSON: $s");

  if (outputType == null) {
    logger
        .info("No output type was specified, so we are just using json.decode");
    return json.decode(s);
  } else {
    logger.info("Now deserializing to type: $outputType");
    return deserializeDatum(json.decode(s), outputType: outputType);
  }
}

/// Deserializes some JSON-serializable value into a usable Dart value.
deserializeDatum(value, {Type? outputType}) {
  if (outputType != null) {
    return reflection.deserialize(value, outputType, deserializeDatum);
  } else if (value is List) {
    logger.info("Deserializing this List: $value");
    return value.map(deserializeDatum).toList();
  } else if (value is Map) {
    logger.info("Deserializing this Map: $value");
    Map result = {};
    value.forEach((k, v) {
      result[k] = deserializeDatum(v);
    });
    return result;
  } else if (_isPrimitive(value)) {
    logger.info("Value $value is a primitive");
    return value;
  }
}
