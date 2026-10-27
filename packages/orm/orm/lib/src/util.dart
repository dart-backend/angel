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

/// A `@name` placeholder: `@` and a name of letters (in any script), digits
/// and underscores, in group 1; or else, in no group, a string literal, a
/// quoted identifier or a system variable (`@@session`), which are left as
/// they are, as a `@` in them is no placeholder.
final RegExp _placeholder = RegExp(
  r"'(?:[^'\\]|\\.|'')*'|"
  r'"(?:[^"\\]|\\.|"")*"|'
  r'`(?:[^`]|``)*`|'
  r'@@[\p{L}\p{N}_$.]+|'
  r'@([\p{L}\p{N}_]+)',
  unicode: true,
);

/// Replaces each `@name` placeholder in [sql] that has a value in [values]
/// with what [replace] returns for its name and value, called in the order
/// the placeholders appear.
///
/// Names are matched whole, so `@name` does not replace part of `@name1`. A
/// placeholder with no value (e.g. a MySQL user variable) is left as it is,
/// as is a `@` in a string literal (`'x@name.com'`), a quoted identifier, or
/// a system variable (`@@session`).
/// Executors use this to turn the `@name` placeholders the queries are built
/// with into those of their driver, e.g. positional `?`.
String replacePlaceholders(
  String sql,
  Map<String, dynamic> values,
  String Function(String name, dynamic value) replace,
) {
  return sql.replaceAllMapped(_placeholder, (m) {
    var name = m[1];
    if (name == null || !values.containsKey(name)) return m[0]!;
    return replace(name, values[name]);
  });
}

/*
final showDebugPrint = true;

void debugPrint(Object obj) {
  if (showDebugPrint) {
    print(obj);
  }
}
*/

/// The items of a relation joined to a row, [a], with those of another row of
/// the same record, [b], that it does not have: by [key], or by `==` without
/// one. An item of both is combined by [merge], when given, for the relations
/// joined to it in turn, which also come once per row.
List<T> mergeJoined<T>(
  List<T> a,
  List<T> b, {
  Object? Function(T)? key,
  T Function(T, T)? merge,
}) {
  var out = List<T>.of(a);
  for (var item in b) {
    var idx = key == null
        ? out.indexOf(item)
        : out.indexWhere((e) => key(e) == key(item));
    if (idx == -1) {
      out.add(item);
    } else if (merge != null) {
      out[idx] = merge(out[idx], item);
    }
  }
  return out;
}
