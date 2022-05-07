import 'package:charcode/ascii.dart';

bool isAscii(int ch) => ch >= $nul && ch <= $del;

bool mapToBool(dynamic value) {
  if (value is int) {
    return value != 0;
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

DateTime? mapToDateTime(dynamic value) {
  if (value == null) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return value;
}

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
