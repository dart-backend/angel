import 'package:intl/intl.dart' show DateFormat;

import 'dialect/current.dart';
import 'dialect/dialect.dart';
import 'query.dart';

final DateFormat dateYmd = DateFormat('yyyy-MM-dd');
final DateFormat dateYmdHms = DateFormat('yyyy-MM-dd HH:mm:ss');

abstract class SqlExpressionBuilder<T> {
  final Query query;
  final String columnName;
  String? _cast;
  bool _isProperty = false;
  String? _substitution;

  SqlExpressionBuilder(this.query, this.columnName);

  /// What the names of the parameters of this builder start with: not the
  /// name of a JSON property, which is an expression.
  String get _parameterName => _isProperty ? 'prop' : columnName;

  /// What `IS NULL` and `IS NOT NULL` test, when not the column given to
  /// [compileFor]: a JSON property as it is, not as the type it is read as,
  /// which is `NULL` of a value of another type.
  String? _nullColumn;

  String get substitution =>
      _substitution ??= query.reserveName(_parameterName);

  /// The names of the substitution values of the predicate of this builder.
  final List<String> _bound = [];

  /// The names of the substitution values of this builder.
  Iterable<String> get boundParameterNames => _bound;

  /// Removes the substitution values of the previous predicate, which the
  /// executor would otherwise be given as unused parameters.
  void _unbind() {
    _bound.forEach(query.substitutionValues.remove);
    _bound.clear();
  }

  bool get hasValue;

  String? compile();

  /// The predicate on [column] (e.g. `table.column`), or `null` if it has
  /// none.
  String? compileFor(String column) {
    var c = compile();
    if (c == null) return null;
    if (c == _noRow || c == _everyRow) return c;
    var isNullCheck = c == 'IS NULL' || c == 'IS NOT NULL';
    return '${isNullCheck ? _nullColumn ?? column : column} $c';
  }
}

/// `IN` no values, which `IN ()` cannot say, as it is not valid SQL.
const _noRow = 'FALSE';

/// `NOT IN` no values, which is true of every row, even of a `NULL`.
const _everyRow = 'TRUE';

class NumericSqlExpressionBuilder<T extends num>
    extends SqlExpressionBuilder<T> {
  bool _hasValue = false;
  String _op = '=';
  String? _raw;
  T? _value;

  NumericSqlExpressionBuilder(super.query, super.columnName);

  @override
  bool get hasValue => _hasValue;

  bool _change(String op, T value) {
    if (value is double && !value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be a finite number');
    }
    _raw = null;
    _op = op;
    _value = value;
    return _hasValue = true;
  }

  @override
  String? compile() {
    if (_raw != null) return _raw;
    if (_value == null) return null;
    // A plain numeric literal: `CAST(... AS decimal)` would round it to an
    // integer in MySQL, whose DECIMAL defaults to DECIMAL(10,0).
    var v = _value.toString();
    if (_cast != null) v = 'CAST ($v AS $_cast)';
    return '$_op $v';
  }

  bool operator <(T value) => _change('<', value);

  bool operator >(T value) => _change('>', value);

  bool operator <=(T value) => _change('<=', value);

  bool operator >=(T value) => _change('>=', value);

  void get isNull {
    _raw = 'IS NULL';
    _hasValue = true;
  }

  void get isNotNull {
    _raw = 'IS NOT NULL';
    _hasValue = true;
  }

  void lessThan(T value) {
    _change('<', value);
  }

  void lessThanOrEqualTo(T value) {
    _change('<=', value);
  }

  void greaterThan(T value) {
    _change('>', value);
  }

  void greaterThanOrEqualTo(T value) {
    _change('>=', value);
  }

  void equals(T value) {
    _change('=', value);
  }

  void notEquals(T value) {
    _change('!=', value);
  }

  void isBetween(T lower, T upper) {
    _raw = 'BETWEEN $lower AND $upper';
    _hasValue = true;
  }

  void isNotBetween(T lower, T upper) {
    _raw = 'NOT BETWEEN $lower AND $upper';
    _hasValue = true;
  }

  void isIn(Iterable<T> values) {
    _raw = values.isEmpty ? _noRow : 'IN (${values.join(', ')})';
    _hasValue = true;
  }

  void isNotIn(Iterable<T> values) {
    _raw = values.isEmpty ? _everyRow : 'NOT IN (${values.join(', ')})';
    _hasValue = true;
  }
}

class EnumSqlExpressionBuilder<T> extends SqlExpressionBuilder<T> {
  final int Function(T) _getValue;
  bool _hasValue = false;
  String _op = '=';
  String? _raw;
  int? _value;

  EnumSqlExpressionBuilder(super.query, super.columnName, this._getValue);

  @override
  bool get hasValue => _hasValue;

  bool _change(String op, T value) {
    _raw = null;
    _op = op;
    _value = _getValue(value);
    return _hasValue = true;
  }

  UnsupportedError _unsupported() =>
      UnsupportedError('Enums do not support this operation.');

  @override
  String compile() {
    if (_raw != null) {
      return _raw!;
    }
    if (_value == null) {
      return '';
    }
    return '$_op $_value';
  }

  void get isNull {
    _raw = 'IS NULL';
    _hasValue = true;
  }

  void get isNotNull {
    _raw = 'IS NOT NULL';
    _hasValue = true;
  }

  void equals(T value) {
    _change('=', value);
  }

  void notEquals(T value) {
    _change('!=', value);
  }

  void isBetween(T lower, T upper) => throw _unsupported();

  void isNotBetween(T lower, T upper) => throw _unsupported();

  void isIn(Iterable<T> values) {
    _raw = values.isEmpty ? _noRow : 'IN (${values.map(_getValue).join(', ')})';
    _hasValue = true;
  }

  void isNotIn(Iterable<T> values) {
    _raw = values.isEmpty
        ? _everyRow
        : 'NOT IN (${values.map(_getValue).join(', ')})';
    _hasValue = true;
  }
}

class StringSqlExpressionBuilder extends SqlExpressionBuilder<String> {
  bool _hasValue = false;
  String? _op = '=', _raw, _value;

  StringSqlExpressionBuilder(super.query, super.columnName);

  @override
  bool get hasValue => _hasValue;

  String get lowerName => '${substitution}_lower';

  String get upperName => '${substitution}_upper';

  bool _change(String op, String value) {
    _unbind();
    _raw = null;
    _op = op;
    _value = value;
    query.substitutionValues[substitution] = _value;
    _bound.add(substitution);
    return _hasValue = true;
  }

  @override
  String? compile() {
    if (_raw != null) return _raw;
    if (_value == null) return null;
    return '$_op @$substitution';
  }

  void isEmpty() => equals('');

  void equals(String value) {
    _change('=', value);
  }

  void notEquals(String value) {
    _change('!=', value);
  }

  /// Builds a `LIKE` predicate.
  ///
  /// The [pattern] is passed to the [QueryExecutor] as a parameter, never
  /// written into the SQL, so it is safe to build from user input. Its `%`
  /// and `_` are still wildcards; escape them in user input that should match
  /// literally.
  ///
  /// If given, [sanitize] is applied to [pattern] first, e.g. to wrap user
  /// input in wildcards.
  ///
  /// Example:
  /// ```dart
  /// carNameBuilder.like('%Mazda%');
  /// carNameBuilder.like(userInput, sanitize: (s) => '%$s%');
  /// ```
  void like(String pattern, {String Function(String)? sanitize}) {
    _change('LIKE', sanitize == null ? pattern : sanitize(pattern));
  }

  void isBetween(String lower, String upper) {
    _bindBounds(lower, upper);
    _raw = 'BETWEEN @$lowerName AND @$upperName';
    _hasValue = true;
  }

  void isNotBetween(String lower, String upper) {
    _bindBounds(lower, upper);
    _raw = 'NOT BETWEEN @$lowerName AND @$upperName';
    _hasValue = true;
  }

  void get isNull {
    _unbind();
    _raw = 'IS NULL';
    _hasValue = true;
  }

  void get isNotNull {
    _unbind();
    _raw = 'IS NOT NULL';
    _hasValue = true;
  }

  void _bindBounds(String lower, String upper) {
    _unbind();
    query.substitutionValues[lowerName] = lower;
    query.substitutionValues[upperName] = upper;
    _bound.addAll([lowerName, upperName]);
  }

  String _in(Iterable<String> values) {
    return 'IN (${values.map((v) {
      var name = query.reserveName('${_parameterName}_in_value');
      query.substitutionValues[name] = v;
      _bound.add(name);
      return '@$name';
    }).join(', ')})';
  }

  void isIn(Iterable<String> values) {
    _unbind();
    _raw = values.isEmpty ? _noRow : _in(values);
    _hasValue = true;
  }

  void isNotIn(Iterable<String> values) {
    _unbind();
    _raw = values.isEmpty ? _everyRow : 'NOT ${_in(values)}';
    _hasValue = true;
  }
}

class BooleanSqlExpressionBuilder extends SqlExpressionBuilder<bool> {
  bool _hasValue = false;
  String? _op = '=', _raw;
  bool? _value;

  BooleanSqlExpressionBuilder(super.query, super.columnName);

  @override
  bool get hasValue => _hasValue;

  bool _change(String op, bool value) {
    _raw = null;
    _op = op;
    _value = value;
    return _hasValue = true;
  }

  @override
  String? compile() {
    if (_raw != null) return _raw;
    if (_value == null) return null;
    var v = _value! ? 'TRUE' : 'FALSE';
    if (_cast != null) v = 'CAST ($v AS $_cast)';
    return '$_op $v';
  }

  void get isTrue => equals(true);

  void get isFalse => equals(false);

  void get isNull {
    _raw = 'IS NULL';
    _hasValue = true;
  }

  void get isNotNull {
    _raw = 'IS NOT NULL';
    _hasValue = true;
  }

  void equals(bool value) {
    _change('=', value);
  }

  void notEquals(bool value) {
    _change('!=', value);
  }
}

class DateTimeSqlExpressionBuilder extends SqlExpressionBuilder<DateTime> {
  NumericSqlExpressionBuilder<int>? _year,
      _month,
      _day,
      _hour,
      _minute,
      _second;

  /// A predicate for the column it is given, when one was set directly.
  String Function(String column)? _raw;

  DateTimeSqlExpressionBuilder(super.query, super.columnName);

  NumericSqlExpressionBuilder<int> get year =>
      _year ??= NumericSqlExpressionBuilder(query, 'year');
  NumericSqlExpressionBuilder<int> get month =>
      _month ??= NumericSqlExpressionBuilder(query, 'month');
  NumericSqlExpressionBuilder<int> get day =>
      _day ??= NumericSqlExpressionBuilder(query, 'day');
  NumericSqlExpressionBuilder<int> get hour =>
      _hour ??= NumericSqlExpressionBuilder(query, 'hour');
  NumericSqlExpressionBuilder<int> get minute =>
      _minute ??= NumericSqlExpressionBuilder(query, 'minute');
  NumericSqlExpressionBuilder<int> get second =>
      _second ??= NumericSqlExpressionBuilder(query, 'second');

  @override
  bool get hasValue =>
      _raw != null ||
      _year?.hasValue == true ||
      _month?.hasValue == true ||
      _day?.hasValue == true ||
      _hour?.hasValue == true ||
      _minute?.hasValue == true ||
      _second?.hasValue == true;

  /// Binds [dt] as a substitution value, under a name of its own in the
  /// query, and returns its placeholder.
  ///
  /// The executor sends it as it stores a [DateTime], e.g. as UTC, where a
  /// literal would be the wall-clock time of [dt], whatever its time zone.
  String _bind(DateTime dt) {
    var name = query.reserveName(_parameterName);
    query.substitutionValues[name] = dt;
    _bound.add(name);
    return '@$name';
  }

  bool _change(String op, DateTime dt, bool time) {
    _unbind();
    if (time) {
      var placeholder = _bind(dt);
      _raw = (column) => '$column $op $placeholder';
    } else {
      // A date has no time zone, so it is the date of [dt] as it is given,
      // which also matches a `date` column.
      var date = dateYmd.format(dt);
      _raw = (column) => "$column $op '$date'";
    }
    return true;
  }

  bool operator <(DateTime value) => _change('<', value, true);

  bool operator <=(DateTime value) => _change('<=', value, true);

  bool operator >(DateTime value) => _change('>', value, true);

  bool operator >=(DateTime value) => _change('>=', value, true);

  void equals(DateTime value, {bool includeTime = true}) {
    _change('=', value, includeTime != false);
  }

  void lessThan(DateTime value, {bool includeTime = true}) {
    _change('<', value, includeTime != false);
  }

  void lessThanOrEqualTo(DateTime value, {bool includeTime = true}) {
    _change('<=', value, includeTime != false);
  }

  void greaterThan(DateTime value, {bool includeTime = true}) {
    _change('>', value, includeTime != false);
  }

  void greaterThanOrEqualTo(DateTime value, {bool includeTime = true}) {
    _change('>=', value, includeTime != false);
  }

  /// No value is in an empty list, which `IN ()` cannot say, as it is not
  /// valid SQL.
  void isIn(Iterable<DateTime> values) {
    var placeholders = _bindAll(values);
    _raw = (column) =>
        placeholders.isEmpty ? 'FALSE' : '$column IN ($placeholders)';
  }

  void isNotIn(Iterable<DateTime> values) {
    var placeholders = _bindAll(values);
    _raw = (column) =>
        placeholders.isEmpty ? 'TRUE' : '$column NOT IN ($placeholders)';
  }

  String _bindAll(Iterable<DateTime> values) {
    _unbind();
    return values.map(_bind).join(', ');
  }

  void isBetween(DateTime lower, DateTime upper) {
    _unbind();
    var l = _bind(lower), u = _bind(upper);
    _raw = (column) => '$column BETWEEN $l AND $u';
  }

  void isNotBetween(DateTime lower, DateTime upper) {
    _unbind();
    var l = _bind(lower), u = _bind(upper);
    _raw = (column) => '$column NOT BETWEEN $l AND $u';
  }

  void get isNull {
    _unbind();
    _raw = (column) => '${_nullColumn ?? column} IS NULL';
  }

  void get isNotNull {
    _unbind();
    _raw = (column) => '${_nullColumn ?? column} IS NOT NULL';
  }

  /// The predicates on this column, each with the column name, joined with
  /// `AND`.
  @override
  String? compile() => compileFor(columnName);

  /// Like [compile], with [column] (e.g. `table.column`) as the column name.
  ///
  /// The parts of a date ([year], [month], ...) use the standard
  /// `EXTRACT(... FROM column)`, which PostgreSQL and MySQL/MariaDB both
  /// support; the second is rounded down, as PostgreSQL's has a fraction.
  @override
  String? compileFor(String column) {
    var raw = _raw;
    var parts = <String>[
      if (raw != null) raw(column),
      for (var (field, builder) in [
        ('YEAR', _year),
        ('MONTH', _month),
        ('DAY', _day),
        ('HOUR', _hour),
        ('MINUTE', _minute),
      ])
        if (builder != null && builder.hasValue)
          ?builder.compileFor('EXTRACT($field FROM $column)'),
      if (_second case var second? when second.hasValue)
        ?second.compileFor('FLOOR(EXTRACT(SECOND FROM $column))'),
    ];
    return parts.isEmpty ? null : parts.join(' AND ');
  }
}

abstract class JsonSqlExpressionBuilder<T, K> extends SqlExpressionBuilder<T> {
  final List<JsonSqlExpressionBuilderProperty> _properties = [];
  bool _hasValue = false;
  T? _value;
  String? _op;
  String? _raw;

  JsonSqlExpressionBuilder(super.query, super.columnName);

  JsonSqlExpressionBuilderProperty operator [](K name) {
    var p = _property(name);
    _properties.add(p);
    return p;
  }

  JsonSqlExpressionBuilderProperty _property(K name);

  @override
  Iterable<String> get boundParameterNames => [
    if (_value != null) substitution,
    for (var p in _properties) ...?p.typed?.boundParameterNames,
  ];

  bool get hasRaw => _raw != null || _properties.any((p) => p.hasValue);

  @override
  bool get hasValue => _hasValue || _properties.any((p) => p.hasValue);

  T? _encodeValue(T? v) => v;

  bool _change(String op, T value) {
    _raw = null;
    _op = op;
    _value = value;
    query.substitutionValues[substitution] = _encodeValue(_value);
    return _hasValue = true;
  }

  void get isNull {
    _raw = 'IS NULL';
    _hasValue = true;
  }

  void get isNotNull {
    _raw = 'IS NOT NULL';
    _hasValue = true;
  }

  /// The predicates on this column, each with the column name, joined with
  /// `AND`.
  @override
  String compile() => compileFor(columnName);

  /// Like [compile], with [column] (e.g. `table.column`) as the column name.
  @override
  String compileFor(String column) => [
    if (_raw != null) '$column $_raw',
    if (_value != null)
      _JsonSql.of(currentDialect).compare(column, _op!, '@$substitution'),
    for (var p in _properties) ...p._predicates(column),
  ].join(' AND ');

  void contains(T value) {
    _change('@>', value);
  }

  void equals(T value) {
    _change('=', value);
  }
}

class MapSqlExpressionBuilder extends JsonSqlExpressionBuilder<Map, String> {
  MapSqlExpressionBuilder(super.query, super.columnName);

  @override
  JsonSqlExpressionBuilderProperty _property(String name) {
    return JsonSqlExpressionBuilderProperty(this, name, false);
  }

  void containsKey(String key) {
    this[key].isNotNull;
  }

  void containsPair(dynamic key, dynamic value) {
    contains({key: value});
  }
}

class ListSqlExpressionBuilder extends JsonSqlExpressionBuilder<List, int> {
  ListSqlExpressionBuilder(super.query, super.columnName);

  @override
  List<dynamic>? _encodeValue(List<dynamic>? v) => v; //[json.encode(v)];

  @override
  JsonSqlExpressionBuilderProperty _property(int name) {
    return JsonSqlExpressionBuilderProperty(this, name.toString(), true);
  }
}

class JsonSqlExpressionBuilderProperty {
  final JsonSqlExpressionBuilder builder;
  final String name;
  final bool isInt;
  SqlExpressionBuilder? _typed;

  JsonSqlExpressionBuilderProperty(this.builder, this.name, this.isInt);

  /// `IS NULL` or `IS NOT NULL`, when checked.
  String? _nullCheck;

  SqlExpressionBuilder? get typed => _typed;

  bool get hasValue => _nullCheck != null || _typed?.hasValue == true;

  String? compile() => _typed?.compile();

  /// This property's predicates, on the JSON in [column], in the SQL of the
  /// dialect of the query being run.
  Iterable<String> _predicates(String column) sync* {
    var sql = _JsonSql.of(currentDialect);
    var name = sql.text(column, this);
    if (_nullCheck case var check?) yield '$name $check';
    var typed = _typed;
    if (typed == null || !typed.hasValue) return;
    typed._nullColumn = name;
    String expression;
    switch (typed) {
      // A property that is no number is `NULL`, as in no comparison.
      case NumericSqlExpressionBuilder():
        expression = sql.number(column, this);
      case DateTimeSqlExpressionBuilder():
        expression = sql.dateTime(column, this);
      // As JSON, not as text, which may be no JSON. A JSON `null` is `NULL`.
      case JsonSqlExpressionBuilder():
        expression = sql.json(column, this);
      // Compared as text on PostgreSQL, of `CAST (TRUE AS text)`; as a
      // boolean elsewhere, of which a property that is none is `NULL`.
      case BooleanSqlExpressionBuilder():
        var boolean = sql.boolean(column, this);
        typed._cast = boolean == null ? 'text' : null;
        expression = boolean ?? name;
      default:
        expression = name;
    }
    var predicate = typed.compileFor(expression);
    if (predicate != null) yield predicate;
  }

  T? _set<T extends SqlExpressionBuilder?>(T Function() value) {
    if (_typed is T) {
      return _typed as T?;
    } else if (_typed != null) {
      throw StateError(
        '$nameString is already typed as $_typed, and cannot be changed.',
      );
    } else {
      var typed = value();
      typed
        ?.._cast = typed is NumericSqlExpressionBuilder ? null : 'text'
        .._isProperty = true;
      _typed = typed;
      return typed;
    }
  }

  String get nameString => nameFor(builder.columnName);

  /// The index or the key of this property, as PostgreSQL's SQL: a `'` in a
  /// key is escaped, as a key may come from a request. A key with a
  /// backslash is an escape string, of which every reader of the SQL knows
  /// where it ends, whether or not it takes a backslash as an escape.
  String get _pgKey {
    if (isInt) return name;
    var quoted = name.replaceAll("'", "''");
    return name.contains(r'\')
        ? "E'${quoted.replaceAll(r'\', r'\\')}'"
        : "'$quoted'";
  }

  /// The JSON path of this property, as a string literal of SQLite's or
  /// MySQL's SQL, such as `'$."first_name"'` or `'$[0]'`.
  ///
  /// Throws an [ArgumentError] for a key with a `"` or a backslash, which
  /// a path of SQLite cannot quote, and MySQL's quotes otherwise.
  String get _path {
    if (isInt) return "'\$[$name]'";
    if (name.contains('"') || name.contains(r'\')) {
      throw ArgumentError.value(
        name,
        'name',
        'A key of a JSON property with a `"` or a backslash can only be '
            'queried on PostgreSQL',
      );
    }
    return "'\$.\"${name.replaceAll("'", "''")}\"'";
  }

  /// This property of the JSON in [column], as text, in the SQL of the
  /// dialect of the query being run: `NULL` of a property that is missing,
  /// or a JSON `null`.
  String nameFor(String column) =>
      _JsonSql.of(currentDialect).text(column, this);

  void get isNotNull {
    _nullCheck = 'IS NOT NULL';
  }

  void get isNull {
    _nullCheck = 'IS NULL';
  }

  StringSqlExpressionBuilder? get asString {
    return _set(() => StringSqlExpressionBuilder(builder.query, nameString));
  }

  BooleanSqlExpressionBuilder? get asBool {
    return _set(() => BooleanSqlExpressionBuilder(builder.query, nameString));
  }

  DateTimeSqlExpressionBuilder? get asDateTime {
    return _set(() => DateTimeSqlExpressionBuilder(builder.query, nameString));
  }

  NumericSqlExpressionBuilder<double>? get asDouble {
    return _set(
      () => NumericSqlExpressionBuilder<double>(builder.query, nameString),
    );
  }

  NumericSqlExpressionBuilder<int>? get asInt {
    return _set(
      () => NumericSqlExpressionBuilder<int>(builder.query, nameString),
    );
  }

  MapSqlExpressionBuilder? get asMap {
    return _set(() => MapSqlExpressionBuilder(builder.query, nameString));
  }

  ListSqlExpressionBuilder? get asList {
    return _set(() => ListSqlExpressionBuilder(builder.query, nameString));
  }
}

/// The SQL of JSON columns and properties of a [Dialect].
///
/// A property is `NULL` where it is missing, or a JSON `null`, and where it
/// is not of the type it is read as, so that it matches no comparison.
sealed class _JsonSql {
  const _JsonSql();

  static _JsonSql of(Dialect dialect) => switch (dialect) {
    MySQLDialect() => const _MySqlJson(),
    SqliteDialect() => const _SqliteJson(),
    _ => const _PostgresJson(),
  };

  /// Whether the JSON of [column] is [op] (`=` or `@>`, contains) that of
  /// the placeholder [parameter], bound to a `Map` or a `List`.
  String compare(String column, String op, String parameter);

  /// The property [p] of [column], as text.
  String text(String column, JsonSqlExpressionBuilderProperty p);

  /// The property [p] of [column], as JSON.
  String json(String column, JsonSqlExpressionBuilderProperty p);

  /// The property [p] of [column], as a number.
  String number(String column, JsonSqlExpressionBuilderProperty p);

  /// The property [p] of [column], as a boolean, or `null` where it is
  /// compared as text.
  String? boolean(String column, JsonSqlExpressionBuilderProperty p);

  /// The property [p] of [column], as a timestamp.
  String dateTime(String column, JsonSqlExpressionBuilderProperty p);
}

/// `jsonb`, of its operators.
final class _PostgresJson extends _JsonSql {
  const _PostgresJson();

  @override
  String compare(String column, String op, String parameter) =>
      '$column::jsonb $op $parameter::jsonb';

  @override
  String text(String column, JsonSqlExpressionBuilderProperty p) =>
      '$column::jsonb->>${p._pgKey}';

  // A JSON `null` is `NULL`, as it is of `->>`.
  @override
  String json(String column, JsonSqlExpressionBuilderProperty p) =>
      "NULLIF($column::jsonb->${p._pgKey}, 'null')";

  // `->>` gives text, which is cast where it is a number.
  @override
  String number(String column, JsonSqlExpressionBuilderProperty p) =>
      "CASE WHEN jsonb_typeof($column::jsonb->${p._pgKey}) = 'number' "
      'THEN (${text(column, p)})::numeric END';

  @override
  String? boolean(String column, JsonSqlExpressionBuilderProperty p) => null;

  // Cast where it is a date, which a cast of another text would fail at.
  @override
  String dateTime(String column, JsonSqlExpressionBuilderProperty p) {
    var name = text(column, p);
    return "CASE WHEN pg_input_is_valid($name, 'timestamptz') "
        'THEN ($name)::timestamptz END';
  }
}

/// SQLite's JSON functions, of JSON text.
final class _SqliteJson extends _JsonSql {
  const _SqliteJson();

  // `json()` minifies both, so that they are equal of the same keys, values
  // and order, as the serializer of a model writes them.
  @override
  String compare(String column, String op, String parameter) => op == '='
      ? 'json($column) = json($parameter)'
      : throw UnsupportedError(
          'SQLite cannot tell if JSON contains other JSON: query a property '
          'of it instead, as `where.column[key]`.',
        );

  // A string as text, a number as a number, and an object or an array as
  // JSON text.
  @override
  String text(String column, JsonSqlExpressionBuilderProperty p) =>
      'json_extract($column, ${p._path})';

  // `json_quote` leaves JSON as it is, and quotes a string.
  @override
  String json(String column, JsonSqlExpressionBuilderProperty p) =>
      "NULLIF(json_quote(json_extract($column, ${p._path})), 'null')";

  @override
  String number(String column, JsonSqlExpressionBuilderProperty p) =>
      "CASE WHEN json_type($column, ${p._path}) IN ('integer', 'real') "
      'THEN json_extract($column, ${p._path}) END';

  @override
  String boolean(String column, JsonSqlExpressionBuilderProperty p) =>
      'CASE json_type($column, ${p._path}) '
      "WHEN 'true' THEN TRUE WHEN 'false' THEN FALSE END";

  @override
  String dateTime(String column, JsonSqlExpressionBuilderProperty p) =>
      throw UnsupportedError(
        'A JSON property can be queried as a date on PostgreSQL only.',
      );
}

/// MySQL's and MariaDB's JSON functions.
final class _MySqlJson extends _JsonSql {
  const _MySqlJson();

  // Each contains the other: of arrays, those of the same values in any
  // order, as `JSON_CONTAINS` tells.
  @override
  String compare(String column, String op, String parameter) => op == '='
      ? '(JSON_CONTAINS($column, $parameter) '
            'AND JSON_CONTAINS($parameter, $column))'
      : 'JSON_CONTAINS($column, $parameter)';

  String _extract(String column, JsonSqlExpressionBuilderProperty p) =>
      'JSON_EXTRACT($column, ${p._path})';

  // A JSON `null` is JSON, not `NULL`, of `JSON_EXTRACT`.
  @override
  String text(String column, JsonSqlExpressionBuilderProperty p) {
    var x = _extract(column, p);
    return "CASE WHEN JSON_TYPE($x) = 'NULL' THEN NULL ELSE JSON_UNQUOTE($x) END";
  }

  @override
  String json(String column, JsonSqlExpressionBuilderProperty p) {
    var x = _extract(column, p);
    return "CASE WHEN JSON_TYPE($x) = 'NULL' THEN NULL ELSE $x END";
  }

  @override
  String number(String column, JsonSqlExpressionBuilderProperty p) {
    var x = _extract(column, p);
    return 'CASE WHEN JSON_TYPE($x) IN '
        "('INTEGER', 'UNSIGNED INTEGER', 'DOUBLE', 'DECIMAL') "
        'THEN JSON_UNQUOTE($x) + 0 END';
  }

  @override
  String boolean(String column, JsonSqlExpressionBuilderProperty p) {
    var x = _extract(column, p);
    return "CASE WHEN JSON_TYPE($x) = 'BOOLEAN' "
        "THEN JSON_UNQUOTE($x) = 'true' END";
  }

  @override
  String dateTime(String column, JsonSqlExpressionBuilderProperty p) =>
      throw UnsupportedError(
        'A JSON property can be queried as a date on PostgreSQL only.',
      );
}
