import 'dart:convert';

import 'package:angel3_orm/angel3_orm.dart';

/// Whether a query is an insert, of which an executor selects the row.
final RegExp _insert = RegExp(r'^\s*INSERT\b', caseSensitive: false);

/// Whether [query] is an insert of the ORM whose row [returningQuery]
/// selects.
bool selectsInsertedRow(String query, String returningQuery) =>
    returningQuery.isNotEmpty && _insert.hasMatch(query);

/// The insert [query] with a `RETURNING id`, of the id of its row, which may
/// not be its rowid, as of a UUID given by a default; no row if it inserted
/// none, as of a trigger that ignores it.
String returningId(String query) => '$query RETURNING id';

/// The values of [returningQuery], with [insertIdParameter] bound to [id].
Map<String, dynamic> withInsertId(Map<String, dynamic> values, Object? id) => {
  ...values,
  insertIdParameter: id,
};

/// Whether [sql] only reads, so that it may run on a connection that reads.
/// A `WITH` may write, so it is not one.
bool isSelect(String sql) => _select.hasMatch(sql);

final RegExp _select = RegExp(r'^\s*SELECT\b', caseSensitive: false);

/// [sql] with its `@name` placeholders as positional `?`, and their values,
/// as SQLite stores them.
(String, List<Object?>) toPositional(
  String sql,
  Map<String, dynamic> substitutionValues,
) {
  var params = <Object?>[];
  var positional = replacePlaceholders(sql, substitutionValues, (_, value) {
    params.add(encodeValue(value));
    return '?';
  });
  return (positional, params);
}

/// [value] as SQLite stores it: a [DateTime] as UTC text, a `List<int>` as a
/// BLOB, and another [List] or a [Map] as JSON text.
Object? encodeValue(Object? value) => switch (value) {
  DateTime() => SqliteDialect.formatDateTime(value),
  // Bound as a BLOB.
  List<int>() => value,
  Map() || List() => json.encode(value, toEncodable: _toEncodable),
  _ => value,
};

/// A value in a JSON [Map] or [List] that JSON has no value of: a [DateTime]
/// as it is stored, and another as its `toJson()`, as [json.encode] gives it.
Object? _toEncodable(dynamic value) =>
    value is DateTime ? SqliteDialect.formatDateTime(value) : value.toJson();
