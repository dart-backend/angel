import 'package:charcode/ascii.dart';

bool isAscii(int ch) => ch >= $nul && ch <= $del;

final DateTime defaultDate = DateTime.parse("1970-01-01 00:00:00");

bool mapToBool(dynamic value) {
  if (value is int) {
    return value != 0;
  }

  if (value is String) {
    return value != "0";
  }

  return value != null ? value as bool : false;
}

String mapToText(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is! String) {
    return value.toString();
  }
  return value;
}

/// Helper method to convert dynamic value to DateTime.
/// If null return January 1st, 1970 at 00:00:00 UTC as default
DateTime mapToDateTime(dynamic value) {
  if (value == null) {
    return defaultDate;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? defaultDate;
  }
  return value;
}

/// Helper method to convert dynamic value to nullable DateTime
DateTime? mapToNullableDateTime(dynamic value) {
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return value;
}

/// Helper method to convert dynamic value to nullable double
double mapToDouble(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }

  if (value is! double) {
    return 0.0;
  }
  return value;
}

/// Helper method to convert dynamic value to nullable double
int mapToInt(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  if (value is! int) {
    return 0;
  }
  return value;
}

/*
final showDebugPrint = true;

void debugPrint(Object obj) {
  if (showDebugPrint) {
    print(obj);
  }
}
*/
