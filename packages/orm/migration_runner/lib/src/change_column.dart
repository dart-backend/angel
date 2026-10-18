import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';

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
/// `` `shop`.`orders` ``; otherwise it is of the current database.
String existingConstraintsQuery(String table, Iterable<String> columns) {
  String literal(String value) =>
      compileDefault(value, escapeBackslashes: true);
  var names = table.split('.').map(_unquote).toList();
  var database = names.length > 1 ? literal(names.first) : 'DATABASE()';
  return 'SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, DATA_TYPE, '
      'VERSION() '
      'FROM information_schema.columns '
      'WHERE table_schema = $database '
      'AND table_name = ${literal(names.last)} '
      'AND column_name IN (${columns.map(literal).join(', ')})';
}

/// The [name] without the backticks or double quotes around it.
String _unquote(String name) {
  name = name.trim();
  if (name.length < 2) return name;
  var quote = name[0];
  if ((quote == '`' || quote == '"') && name.endsWith(quote)) {
    return name.substring(1, name.length - 1).replaceAll('$quote$quote', quote);
  }
  return name;
}

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
              : '($columnDefault)',
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
/// without them, the column is nullable without a default.
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

  /// Whether some constraint is not given, and so is read from the database.
  bool get keepsExisting =>
      isNullable == null || defaultValue == null || autoIncrement == null;

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
    defaultValue: defaultValue ?? _existingDefault,
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

/// An alter table of MySQL or MariaDB, whose changes of column types are
/// compiled with the constraints read from the database.
abstract interface class ModifyingAlterTable {
  String get tableName;

  /// The changes of column types, whose constraints not given are read from
  /// the database when the schema is run.
  List<ColumnModification> get modifications;

  /// Compiles the clauses of the table, which may be compiled again.
  void compile(StringBuffer buf, int indent);
}

/// The alter tables of a MySQL or MariaDB schema, each with the text compiled
/// before it and its indent, which are compiled with the constraints that
/// [run] reads from the database just before them.
class SchemaAlters {
  final Logger _log;
  final List<(String, ModifyingAlterTable, int)> _alters = [];

  SchemaAlters(this._log);

  /// Adds [table], after the text of [buf], which is cleared.
  void add(StringBuffer buf, ModifyingAlterTable table, int indent) {
    _alters.add((buf.toString(), table, indent));
    buf.clear();
  }

  /// The SQL of the schema, whose text after the last alter table is [rest].
  /// A change of a column's type keeps the constraints not given only when
  /// [run] has read them from the database.
  String compile(StringBuffer rest) {
    var buf = StringBuffer();
    for (var (text, table, indent) in _alters) {
      buf.write(text);
      _compileAlter(buf, table, indent);
    }
    buf.write(rest);
    return buf.toString();
  }

  /// Runs the SQL of the schema, whose text after the last alter table is
  /// [rest], with [execute], and reads the constraints with [query], which
  /// gives the rows of a query as text.
  ///
  /// The statements before an alter table that changes a column's type are
  /// run before the column's constraints are read, as they may create the
  /// table or rename the column.
  Future<void> run(
    StringBuffer rest, {
    required Future<void> Function(String sql) execute,
    required Future<List<List<String?>>> Function(String sql) query,
  }) async {
    Future<void> executeText(String sql) async {
      if (sql.trim().isNotEmpty) await execute(sql);
    }

    var buf = StringBuffer();
    for (var (text, table, indent) in _alters) {
      buf.write(text);
      if (table.modifications.any((m) => m.keepsExisting)) {
        await executeText(buf.toString());
        buf.clear();
        await _readExisting(table, query);
      }
      _compileAlter(buf, table, indent);
    }
    buf.write(rest);
    await executeText(buf.toString());
  }

  void _compileAlter(StringBuffer buf, ModifyingAlterTable table, int indent) {
    buf.write('  ' * indent);
    buf.writeln('ALTER TABLE ${table.tableName}');
    table.compile(buf, indent + 1);
    buf.writeln(';');
  }

  /// Reads the constraints of the columns of [table] whose types are changed,
  /// which a `MODIFY` keeps only if it gives them again, from the database,
  /// in one query.
  Future<void> _readExisting(
    ModifyingAlterTable table,
    Future<List<List<String?>>> Function(String sql) query,
  ) async {
    var modifications = [
      for (var m in table.modifications)
        if (m.keepsExisting) m,
    ];
    var rows = await query(
      existingConstraintsQuery(
        table.tableName,
        modifications.map((m) => m.name).toSet(),
      ),
    );
    // The names of columns are not case sensitive.
    var byName = {for (var row in rows) row[0]?.toLowerCase(): row};
    for (var modification in modifications) {
      var row = byName[modification.name.toLowerCase()];
      if (row == null) {
        _log.warning(
          'Column ${modification.name} of table ${table.tableName} '
          'not found, so the constraints not given to changeColumnType are '
          'not kept',
        );
        continue;
      }
      modification.existing = ExistingConstraints.parse(
        isNullable: row[1] ?? 'YES',
        columnDefault: row[2],
        extra: row[3] ?? '',
        dataType: row[4] ?? '',
        version: row[5] ?? '',
      );
    }
  }
}
