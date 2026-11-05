import 'dart:convert';

/// The values of a query's named parameters, as the executors send them to
/// the `postgres` driver.
///
/// A [List] is sent as JSON, and a [DateTime] as UTC: sent as text, a local
/// DateTime has its offset, which a `timestamp` column drops, keeping the
/// wall-clock time, and the column is read back as UTC.
Map<String, dynamic> encodeParameters(Map<String, dynamic> values) => {
  for (var MapEntry(:key, :value) in values.entries)
    key: switch (value) {
      List() => jsonEncode(value),
      DateTime() => value.toUtc(),
      _ => value,
    },
};
