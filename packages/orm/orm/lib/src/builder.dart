import 'package:intl/intl.dart' show DateFormat;

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

  String get substitution {
    var c = _isProperty ? 'prop' : columnName;
    return _substitution ??= query.reserveName(c);
  }

  bool get hasValue;

  String? compile();
}

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
    _raw = 'IN (${values.join(', ')})';
    _hasValue = true;
  }

  void isNotIn(Iterable<T> values) {
    _raw = 'NOT IN (${values.join(', ')})';
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
    _raw = 'IN (${values.map(_getValue).join(', ')})';
    _hasValue = true;
  }

  void isNotIn(Iterable<T> values) {
    _raw = 'NOT IN (${values.map(_getValue).join(', ')})';
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
    _raw = null;
    _op = op;
    _value = value;
    query.substitutionValues[substitution] = _value;
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
    query.substitutionValues[lowerName] = lower;
    query.substitutionValues[upperName] = upper;
    _raw = 'BETWEEN @$lowerName AND @$upperName';
    _hasValue = true;
  }

  void isNotBetween(String lower, String upper) {
    query.substitutionValues[lowerName] = lower;
    query.substitutionValues[upperName] = upper;
    _raw = 'NOT BETWEEN @$lowerName AND @$upperName';
    _hasValue = true;
  }

  void get isNull {
    _raw = 'IS NULL';
    _hasValue = true;
  }

  void get isNotNull {
    _raw = 'IS NOT NULL';
    _hasValue = true;
  }

  String _in(Iterable<String> values) {
    return 'IN (${values.map((v) {
      var name = query.reserveName('${columnName}_in_value');
      query.substitutionValues[name] = v;
      return '@$name';
    }).join(', ')})';
  }

  void isIn(Iterable<String> values) {
    _raw = _in(values);
    _hasValue = true;
  }

  void isNotIn(Iterable<String> values) {
    _raw = 'NOT ${_in(values)}';
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

  /// The names of the substitution values [_raw] uses.
  final List<String> _bound = [];

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

  /// Removes the substitution values of the previous predicate, which the
  /// executor would otherwise be given as unused parameters.
  void _unbind() {
    _bound.forEach(query.substitutionValues.remove);
    _bound.clear();
  }

  /// Binds [dt] as a substitution value, under a name of its own in the
  /// query, and returns its placeholder.
  ///
  /// The executor sends it as it stores a [DateTime], e.g. as UTC, where a
  /// literal would be the wall-clock time of [dt], whatever its time zone.
  String _bind(DateTime dt) {
    var name = query.reserveName(columnName);
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
    _raw = (column) => '$column IS NULL';
  }

  void get isNotNull {
    _unbind();
    _raw = (column) => '$column IS NOT NULL';
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
  String? compileFor(String column) {
    var raw = _raw;
    if (raw != null) return raw(column);
    var parts = <String>[
      for (var (field, builder) in [
        ('YEAR', _year),
        ('MONTH', _month),
        ('DAY', _day),
        ('HOUR', _hour),
        ('MINUTE', _minute),
      ])
        if (builder != null && builder.hasValue)
          'EXTRACT($field FROM $column) ${builder.compile()}',
      if (_second case var second? when second.hasValue)
        'FLOOR(EXTRACT(SECOND FROM $column)) ${second.compile()}',
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
  String compileFor(String column) => [
    if (_raw != null) '$column $_raw',
    if (_value != null) '$column::jsonb $_op @$substitution::jsonb',
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

  /// This property's predicates, on the JSON in [column].
  Iterable<String> _predicates(String column) sync* {
    var name = nameFor(column);
    if (_nullCheck case var check?) yield '$name $check';
    var typed = _typed;
    var c = typed != null && typed.hasValue ? typed.compile() : null;
    if (c != null) {
      // A date predicate already names its column.
      yield typed is DateTimeSqlExpressionBuilder ? c : '$name $c';
    }
  }

  T? _set<T extends SqlExpressionBuilder?>(T Function() value) {
    if (_typed is T) {
      return _typed as T?;
    } else if (_typed != null) {
      throw StateError(
        '$nameString is already typed as $_typed, and cannot be changed.',
      );
    } else {
      _typed = value()
        ?.._cast = 'text'
        .._isProperty = true;
      return _typed as T?;
    }
  }

  String get nameString => nameFor(builder.columnName);

  /// This property of the JSON in [column].
  String nameFor(String column) =>
      '$column::jsonb->>${isInt ? name : "'$name'"}';

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
