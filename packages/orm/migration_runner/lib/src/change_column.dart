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

/// Reads the constraints of the column [column] of the table [table] of the
/// current database, and the version of the server, for
/// [ExistingConstraints.parse]. The names are string literals, as the clients
/// of MySQL and MariaDB take parameters differently.
String existingConstraintsQuery(String table, String column) =>
    'SELECT IS_NULLABLE, COLUMN_DEFAULT, EXTRA, VERSION() '
    'FROM information_schema.columns '
    'WHERE table_schema = DATABASE() '
    'AND table_name = ${compileDefault(table, escapeBackslashes: true)} '
    'AND column_name = ${compileDefault(column, escapeBackslashes: true)}';

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

  /// The constraints of a row of [existingConstraintsQuery].
  ///
  /// MariaDB gives `COLUMN_DEFAULT` as SQL, such as `'it''s'`, `0` or
  /// `current_timestamp()`, and `NULL` for none. MySQL gives a literal as its
  /// value, such as `it's`, an expression with `DEFAULT_GENERATED` in `EXTRA`,
  /// and none as `NULL`.
  factory ExistingConstraints.parse({
    required String isNullable,
    required String? columnDefault,
    required String extra,
    required String version,
  }) {
    Object? defaultValue;
    if (columnDefault != null) {
      if (version.toLowerCase().contains('mariadb')) {
        if (columnDefault.toUpperCase() != 'NULL') {
          defaultValue = RawSql(columnDefault);
        }
      } else if (extra.toUpperCase().contains('DEFAULT_GENERATED')) {
        // An expression, which MySQL takes in parentheses, but for the
        // current time.
        defaultValue = RawSql(
          _currentTimestamp.hasMatch(columnDefault)
              ? columnDefault
              : '($columnDefault)',
        );
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
/// without them, the column is nullable without a default.
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

  /// Whether some constraint is not given, and so is read from the database.
  bool get keepsExisting =>
      isNullable == null || defaultValue == null || autoIncrement == null;

  MigrationColumn _column() => changedColumn(
    type,
    length: length,
    precision: precision,
    scale: scale,
    isNullable: isNullable ?? existing?.isNullable,
    defaultValue: defaultValue ?? existing?.defaultValue,
  );

  /// The `MODIFY`, with the column compiled by [compileColumn], and the
  /// `ON UPDATE` clause the column has.
  String compile(String Function(MigrationColumn column) compileColumn) {
    var sql =
        'MODIFY ${quoteMySqlIdentifier(name)} ${compileColumn(_column())}';
    if (autoIncrement ?? existing?.autoIncrement ?? false) {
      sql += ' AUTO_INCREMENT';
    }
    var onUpdate = existing?.onUpdate;
    if (onUpdate != null) sql += ' ON UPDATE $onUpdate';
    return sql;
  }
}
