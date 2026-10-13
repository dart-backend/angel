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

/// Converts a value read from the database to a double.
///
/// `null`, and a string that is not a number, give `0.0`. Any number (e.g. an
/// `int` for a whole value) is converted, as is a value whose `toString` is a
/// number (e.g. a driver's decimal type); anything else throws a
/// [FormatException] rather than silently becoming `0.0`.
double mapToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is BigInt) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return double.tryParse(value.toString()) ??
      (throw FormatException(
        'Cannot convert $value (${value.runtimeType}) to a double.',
      ));
}

/// Converts a value read from the database to an int.
///
/// `null`, and a string that is not an integer, give `0`. A whole `double`
/// or a `BigInt` that fits is converted, as is a value whose `toString` is an
/// integer; anything else (e.g. `2.5`) throws a [FormatException] rather than
/// silently becoming `0`.
int mapToInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  if (value is BigInt && value.isValidInt) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is! double && value is! BigInt) {
    var parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  throw FormatException(
    'Cannot convert $value (${value.runtimeType}) to an int.',
  );
}

/*
final showDebugPrint = true;

void debugPrint(Object obj) {
  if (showDebugPrint) {
    print(obj);
  }
}
*/
