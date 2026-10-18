import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';

import 'sql.dart';

/// The column that `changeColumnType` changes a column to: of [type], with
/// its [length], [precision] and [scale], nullable or not as [isNullable]
/// (nullable if `null`), and with [defaultValue]. It has no index type or
/// reference, so that compiling it adds no index or reference.
MigrationColumn changedColumn(
  ColumnType type, {
  required int length,
  int? precision,
  int? scale,
  bool? isNullable,
  Object? defaultValue,
}) => MigrationColumn(
  type,
  length: length,
  precision: precision,
  scale: scale,
  isNullable: isNullable ?? true,
  defaultValue: defaultValue,
);

/// Reads the constraints of the columns [columns] of the table [table], and
/// the version of the server, for [ExistingConstraints.parse], with the name
/// of each column first. The names are string literals, as the clients of
/// MySQL and MariaDB take parameters differently.
///
/// The table may be quoted, and qualified by its database, such as
/// `` `shop`.`orders` ``; otherwise it is of the current database. The
/// columns may be quoted too.
String existingConstraintsQuery(String table, Iterable<String> columns) {
  String literal(String value) =>
      compileDefault(value, escapeBackslashes: true);
  var names = table.split('.').map(unquoteIdentifier).toList();
  var database = names.length > 1 ? literal(names.first) : 'DATABASE()';
  var columnNames = columns.map((c) => literal(unquoteIdentifier(c)));
  return 'SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, DATA_TYPE, '
      'VERSION() '
      'FROM information_schema.columns '
      'WHERE table_schema = $database '
      'AND table_name = ${literal(names.last)} '
      'AND column_name IN (${columnNames.join(', ')})';
}

/// The SQL of an expression of MySQL's `COLUMN_DEFAULT`, which escapes the
/// quotes and backslashes in it with a backslash, as in
/// `concat(_utf8mb4\'a\',_utf8mb4\'b\')`.
String _unescapeMySql(String expression) => expression.replaceAllMapped(
  RegExp(r'''\\(['"\\])'''),
  (match) => match[1]!,
);

/// The types that a column may have `AUTO_INCREMENT` with.
const _integerTypes = {
  ColumnType.tinyInt,
  ColumnType.smallInt,
  ColumnType.int,
  ColumnType.bigInt,
  ColumnType.smallSerial,
  ColumnType.serial,
  ColumnType.bigSerial,
};

/// The types that a column may have `ON UPDATE`, and a default of the current
/// time, with.
const _dateTimeTypes = {
  ColumnType.dateTime,
  ColumnType.smallDateTime,
  ColumnType.timeStamp,
  ColumnType.timeStampWithTimeZone,
};

/// The constraints that a column has in a MySQL or MariaDB database, which a
/// `MODIFY` keeps only if it gives them again.
class ExistingConstraints {
  final bool isNullable;

  /// The default, as [RawSql] or a [String] literal, or `null` for none.
  final Object? defaultValue;

  final bool autoIncrement;

  /// The value of an `ON UPDATE` clause, such as `CURRENT_TIMESTAMP`.
  final String? onUpdate;

  const ExistingConstraints({
    required this.isNullable,
    this.defaultValue,
    this.autoIncrement = false,
    this.onUpdate,
  });

  /// The constraints of a row of [existingConstraintsQuery], of a column of
  /// the type [dataType], such as `datetime`.
  ///
  /// MariaDB from 10.2.7 gives `COLUMN_DEFAULT` as SQL, such as `'it''s'`,
  /// `0` or `current_timestamp()`, and `NULL` for none. MySQL, and MariaDB
  /// before 10.2.7, give a literal as its value, such as `it's`, and none as
  /// SQL `NULL`. MySQL from 8.0.13 has `DEFAULT_GENERATED` in `EXTRA` for an
  /// expression; before, the only expression is the current time, of a
  /// `datetime` or `timestamp`. The default of a `bit` is SQL, such as
  /// `b'1'`.
  factory ExistingConstraints.parse({
    required String isNullable,
    required String? columnDefault,
    required String extra,
    required String version,
    String dataType = '',
  }) {
    Object? defaultValue;
    if (columnDefault != null) {
      var type = dataType.toLowerCase();
      if (version.toLowerCase().contains('mariadb') &&
          !_isBefore(version, 10, 2, 7)) {
        if (columnDefault.toUpperCase() != 'NULL') {
          defaultValue = RawSql(columnDefault);
        }
      } else if (extra.toUpperCase().contains('DEFAULT_GENERATED')) {
        // An expression, which MySQL takes in parentheses, but for the
        // current time.
        defaultValue = RawSql(
          _currentTimestamp.hasMatch(columnDefault)
              ? columnDefault
              : '(${_unescapeMySql(columnDefault)})',
        );
      } else if ((type == 'datetime' || type == 'timestamp') &&
          _currentTimestamp.hasMatch(columnDefault)) {
        defaultValue = RawSql(columnDefault);
      } else if (type == 'bit') {
        defaultValue = RawSql(columnDefault);
      } else {
        defaultValue = columnDefault;
      }
    }
    return ExistingConstraints(
      isNullable: isNullable.toUpperCase() == 'YES',
      defaultValue: defaultValue,
      autoIncrement: extra.toLowerCase().contains('auto_increment'),
      onUpdate: _onUpdate.firstMatch(extra)?[1],
    );
  }

  /// Whether the server of [version], such as `8.0.12` or
  /// `10.2.6-MariaDB-log`, is before [major].[minor].[patch]. A version that
  /// cannot be read is not.
  static bool _isBefore(String version, int major, int minor, int patch) {
    // MariaDB may give its version after a version of MySQL, as in
    // `5.5.5-10.2.6-MariaDB`.
    var match =
        _mariaDbVersion.firstMatch(version) ?? _version.firstMatch(version);
    if (match == null) return false;
    var parts = [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
    for (var (i, limit) in [major, minor, patch].indexed) {
      if (parts[i] != limit) return parts[i] < limit;
    }
    return false;
  }

  static final RegExp _version = RegExp(r'(\d+)\.(\d+)\.(\d+)');

  static final RegExp _mariaDbVersion = RegExp(
    r'(\d+)\.(\d+)\.(\d+)-mariadb',
    caseSensitive: false,
  );

  static final RegExp _currentTimestamp = RegExp(
    r'^current_timestamp(\(\d*\))?$',
    caseSensitive: false,
  );

  static final RegExp _onUpdate = RegExp(
    r'on update (\w+(\(\d*\))?)',
    caseSensitive: false,
  );
}

/// A change of the type of a column on MySQL or MariaDB, which define the
/// whole column again in a `MODIFY`. The constraints not given (`null`) are
/// those [existing] in the database, which the schema reads when it is run;
/// without them, the column is nullable without a default. A [defaultValue]
/// of [noDefault] removes the default.
///
/// The `AUTO_INCREMENT` of the column is kept only for an integer type, and
/// its `ON UPDATE` and default of the current time only for a date and time
/// type, as the database rejects them for the others.
class ColumnModification {
  final String name;
  final ColumnType type;
  final int length;
  final int? precision, scale;
  final bool? isNullable;
  final Object? defaultValue;
  final bool? autoIncrement;

  /// The constraints of the column in the database, for those not given.
  ExistingConstraints? existing;

  ColumnModification(
    this.name,
    this.type, {
    required this.length,
    this.precision,
    this.scale,
    this.isNullable,
    this.defaultValue,
    this.autoIncrement,
  }) {
    // Checks the precision and scale when the change is declared.
    _column();
  }

  /// Whether some constraint is not given, and so is read from the database:
  /// one of [isNullable], [defaultValue] and [autoIncrement], or the
  /// `ON UPDATE` that a date and time type keeps, which cannot be given.
  bool get keepsExisting =>
      isNullable == null ||
      defaultValue == null ||
      autoIncrement == null ||
      _dateTimeTypes.contains(type);

  /// The default [existing], unless [type] cannot have it.
  Object? get _existingDefault {
    var value = existing?.defaultValue;
    if (value is RawSql &&
        !_dateTimeTypes.contains(type) &&
        ExistingConstraints._currentTimestamp.hasMatch(value.value)) {
      return null;
    }
    return value;
  }

  MigrationColumn _column() => changedColumn(
    type,
    length: length,
    precision: precision,
    scale: scale,
    isNullable: isNullable ?? existing?.isNullable,
    defaultValue: identical(defaultValue, noDefault)
        ? null
        : defaultValue ?? _existingDefault,
  );

  /// The `MODIFY`, with the column compiled by [compileColumn], and the
  /// `ON UPDATE` clause the column has.
  String compile(String Function(MigrationColumn column) compileColumn) {
    var sql =
        'MODIFY ${quoteMySqlIdentifier(name)} ${compileColumn(_column())}';
    if (autoIncrement ??
        (_integerTypes.contains(type) && (existing?.autoIncrement ?? false))) {
      sql += ' AUTO_INCREMENT';
    }
    var onUpdate = existing?.onUpdate;
    if (onUpdate != null && _dateTimeTypes.contains(type)) {
      sql += ' ON UPDATE $onUpdate';
    }
    return sql;
  }
}
