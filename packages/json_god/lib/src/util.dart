part of angel3_json_god;

bool _isPrimitive(value) {
  return value is num || value is bool || value is String || value == null;
}
