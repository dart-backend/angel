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
///
/// Without [generationExpressions], `GENERATION_EXPRESSION`, which MySQL
/// before 5.7.6 and MariaDB before 10.2.5 do not have, is read as `NULL`.
String existingConstraintsQuery(
  String table,
  Iterable<String> columns, {
  bool generationExpressions = true,
}) {
  var (database, tableName, columnNames) = _names(table, columns);
  var generation = generationExpressions ? 'GENERATION_EXPRESSION' : 'NULL';
  return 'SELECT COLUMN_NAME, IS_NULLABLE, COLUMN_DEFAULT, EXTRA, DATA_TYPE, '
      'VERSION(), COLUMN_TYPE, $generation, CHARACTER_SET_NAME, '
      'COLLATION_NAME, COLUMN_COMMENT '
      'FROM information_schema.columns '
      'WHERE table_schema = $database '
      'AND table_name = $tableName '
      'AND column_name IN (${columnNames.join(', ')})';
}

/// Reads the `CHECK` constraints of the columns [columns] of the table
/// [table] on MariaDB, with the name of each column first, for
/// [ExistingConstraints.check]. A constraint of a column has its name.
String columnChecksQuery(String table, Iterable<String> columns) {
  var (database, tableName, columnNames) = _names(table, columns);
  return 'SELECT CONSTRAINT_NAME, CHECK_CLAUSE '
      'FROM information_schema.CHECK_CONSTRAINTS '
      'WHERE CONSTRAINT_SCHEMA = $database '
      'AND TABLE_NAME = $tableName '
      'AND CONSTRAINT_NAME IN (${columnNames.join(', ')})';
}

/// The database, table and columns of [table] and [columns], as SQL.
(String, String, Iterable<String>) _names(
  String table,
  Iterable<String> columns,
) {
  String literal(String value) =>
      compileDefault(value, escapeBackslashes: true);
  var names = splitQualifiedName(table);
  return (
    names.length > 1 ? literal(names.first) : 'DATABASE()',
    literal(names.last),
    columns.map((c) => literal(unquoteIdentifier(c))),
  );
}

/// Whether the server of [version], which MariaDB has in it, has column
/// `CHECK` constraints that a `MODIFY` drops, and
/// `information_schema.CHECK_CONSTRAINTS`, as MariaDB from 10.2.22 does.
/// MySQL keeps a column's constraints, which are of the table.
bool hasColumnChecks(String version) =>
    _isMariaDb(version) && !_isBefore(version, 10, 2, 22);

bool _isMariaDb(String version) => version.toLowerCase().contains('mariadb');

/// Whether the server of [version], such as `8.0.12` or `10.2.6-MariaDB-log`,
/// is before [major].[minor].[patch]. A version that cannot be read is not,
/// nor is one of [major].[minor] without a patch, such as Aurora MySQL's
/// `8.0.mysql_aurora.3.05.2`.
bool _isBefore(String version, int major, int minor, int patch) {
  // MariaDB may give its version after a version of MySQL, as in
  // `5.5.5-10.2.6-MariaDB`.
  var match =
      _mariaDbVersion.firstMatch(version) ?? _version.firstMatch(version);
  if (match == null) return false;
  var limits = [major, minor, patch];
  for (var i = 0; i < 3; i++) {
    var part = match[i + 1];
    if (part == null) return false;
    var n = int.parse(part);
    if (n != limits[i]) return n < limits[i];
  }
  return false;
}

/// The version of MySQL at the start of `VERSION()`, whose patch Aurora
/// MySQL does not give.
final RegExp _version = RegExp(r'^(\d+)\.(\d+)(?:\.(\d+))?');

final RegExp _mariaDbVersion = RegExp(
  r'(\d+)\.(\d+)\.(\d+)-mariadb',
  caseSensitive: false,
);

/// The types of text that keep the character set and collation of a column,
/// unlike `nchar` and `nvarchar`, whose character set is that of the server.
const _stringTypes = {ColumnType.char, ColumnType.varChar, ColumnType.text};

/// The types that MySQL takes no literal default for, but an expression from
/// 8.0.13.
const _blobTypes = {ColumnType.text, ColumnType.nText, ColumnType.image};

/// The types of JSON, which do not keep a default, as one of another type is
/// rarely JSON.
const _jsonTypes = {ColumnType.json, ColumnType.jsonb};

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

/// The types that a column may be `UNSIGNED` with.
const _unsignedTypes = {
  ..._integerTypes,
  ColumnType.decimal,
  ColumnType.numeric,
  ColumnType.float,
  ColumnType.real,
  ColumnType.double,
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

  /// The whole type of the column, such as `int(10) unsigned`.
  final String? columnType;

  /// The expression of a generated column, as SQL, such as `a + 1`, or
  /// `null` for a column that is not generated.
  final String? generationExpression;

  /// Whether a generated column is stored, rather than virtual.
  final bool stored;

  /// The character set and collation of a column of text, such as `utf8mb4`
  /// and `utf8mb4_bin`, or `null` for a column of another type.
  final String? characterSet, collation;

  /// The comment of the column, or `null` for none.
  final String? comment;

  /// The expression of the `CHECK` constraint of the column on MariaDB, such
  /// as `` json_valid(`data`) `` of a `JSON` column, which a `MODIFY` drops,
  /// or `null` for none.
  final String? check;

  /// The version of the server, such as `8.4.0` or `11.4.2-MariaDB`, or
  /// empty if not known.
  final String version;

  const ExistingConstraints({
    required this.isNullable,
    this.defaultValue,
    this.autoIncrement = false,
    this.onUpdate,
    this.columnType,
    this.generationExpression,
    this.stored = false,
    this.characterSet,
    this.collation,
    this.comment,
    this.check,
    this.version = '',
  });

  /// Whether the column is `UNSIGNED`, as its [columnType] says.
  bool get unsigned => columnType?.toLowerCase().contains('unsigned') ?? false;

  /// [value], the default of the column, as a default of a `TEXT` or `BLOB`
  /// column, or `null` if the server takes none: MariaDB takes a literal from
  /// 10.2.1, and MySQL only an expression, in parentheses, from 8.0.13.
  Object? blobDefault(Object value) {
    if (_isMariaDb(version)) {
      return _isBefore(version, 10, 2, 1) ? null : value;
    }
    if (_isBefore(version, 8, 0, 13)) return null;
    // An expression already in parentheses, such as `(1)+(2)`, may not be
    // in one pair of them, so it is in parentheses again.
    var sql = value is RawSql
        ? value.value
        : compileDefault(value, escapeBackslashes: true);
    return RawSql('($sql)');
  }

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
  ///
  /// A generated column has `VIRTUAL GENERATED` or `STORED GENERATED`
  /// (`PERSISTENT` on older MariaDB) in `EXTRA`, and its
  /// [generationExpression], which MySQL escapes as it does a default. Throws
  /// a [StateError] for a generated column without it, as on a server that
  /// has no `GENERATION_EXPRESSION`, which a `MODIFY` would make a column
  /// that is not generated.
  factory ExistingConstraints.parse({
    required String isNullable,
    required String? columnDefault,
    required String extra,
    required String version,
    String dataType = '',
    String? columnType,
    String? generationExpression,
    String? characterSet,
    String? collation,
    String? comment,
    String? check,
  }) {
    var mariaDb = _isMariaDb(version);
    var upperExtra = extra.toUpperCase();
    // MariaDB before 10.2 has `VIRTUAL` or `PERSISTENT`.
    var generated =
        (upperExtra.contains('GENERATED') &&
            !upperExtra.contains('DEFAULT_GENERATED')) ||
        upperExtra.contains('PERSISTENT') ||
        upperExtra.trim() == 'VIRTUAL';
    if (generated && (generationExpression?.isEmpty ?? true)) {
      throw StateError(
        'Cannot keep the generation of a column: the server gives no '
        'GENERATION_EXPRESSION of it',
      );
    }
    Object? defaultValue;
    if (columnDefault != null) {
      var type = dataType.toLowerCase();
      if (mariaDb && !_isBefore(version, 10, 2, 7)) {
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
      columnType: columnType,
      generationExpression: !generated
          ? null
          : mariaDb
          ? generationExpression
          : _unescapeMySql(generationExpression!),
      stored:
          upperExtra.contains('STORED GENERATED') ||
          upperExtra.contains('PERSISTENT'),
      characterSet: characterSet,
      collation: collation,
      comment: (comment?.isEmpty ?? true) ? null : comment,
      check: check,
      version: version,
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
/// without them, the column is nullable without a default. A [defaultValue]
/// of [noDefault] removes the default.
///
/// The `AUTO_INCREMENT` of the column is kept only for an integer type, and
/// its `ON UPDATE` and default of the current time only for a date and time
/// type, as the database rejects them for the others. A serial type is its
/// integer with `AUTO_INCREMENT`, unless [autoIncrement] is `false`.
///
/// A column that is `UNSIGNED` stays so if the new type is numeric, and a
/// generated column keeps its expression and whether it is stored.
///
/// Without a [type], the column keeps its own, which is read from the
/// database too, as for [ColumnModification.nullability].
class ColumnModification {
  final String name;
  final ColumnType? type;
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

  /// This change, and then [later], of the same column, as one: the
  /// constraints that [later] gives win, and the type is that of the last of
  /// them that gives one. MySQL and MariaDB take one `MODIFY` of a column in
  /// a statement.
  ColumnModification mergedWith(ColumnModification later) {
    var typed = later.type != null ? later : this;
    return ColumnModification(
      name,
      typed.type,
      length: typed.length,
      precision: typed.precision,
      scale: typed.scale,
      isNullable: later.isNullable ?? isNullable,
      defaultValue: later.defaultValue ?? defaultValue,
      autoIncrement: later.autoIncrement ?? autoIncrement,
    );
  }

  /// A change of only whether the column [name] is nullable, as [isNullable],
  /// which MySQL and MariaDB make with a `MODIFY` too: it keeps the type of
  /// the column, such as `int(10) unsigned`, and its other constraints.
  ColumnModification.nullability(String name, {required bool isNullable})
    : this(name, null, length: Column.defaultLength, isNullable: isNullable);

  /// Whether the column is `AUTO_INCREMENT` after the change.
  bool get _autoIncrement =>
      autoIncrement ??
      (serialIntegers.containsKey(type) ||
          ((type == null || _integerTypes.contains(type)) &&
              (existing?.autoIncrement ?? false)));

  /// The default [existing], unless the column cannot have it: of the current
  /// time, but for a date and time type, a literal of a `TEXT` or `BLOB`
  /// column, as [ExistingConstraints.blobDefault], and any of a `JSON` or an
  /// `AUTO_INCREMENT` column.
  Object? get _existingDefault {
    var existing = this.existing;
    var value = existing?.defaultValue;
    var type = this.type;
    if (existing == null || value == null || _autoIncrement) return null;
    if (type == null) return value;
    if (_jsonTypes.contains(type)) return null;
    if (value is RawSql &&
        !_dateTimeTypes.contains(type) &&
        ExistingConstraints._currentTimestamp.hasMatch(value.value)) {
      return null;
    }
    if (_blobTypes.contains(type)) return existing.blobDefault(value);
    return value;
  }

  MigrationColumn _column() => changedColumn(
    // The type read from the database, which [compile] does not have before
    // the schema is run.
    type ??
        ColumnType(
          existing?.columnType ??
              '/* the type of ${quoteMySqlIdentifier(name)} */',
        ),
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
    var type = this.type;
    var column = _column();
    var definition = compileColumn(column);

    // Those kept that follow the type, before its NOT NULL and DEFAULT, as
    // the type a column keeps (without [type]) has its UNSIGNED.
    var existing = this.existing;
    var expression = existing?.generationExpression;
    var collation = existing?.collation;
    var afterType = [
      // A column of text keeps its character set and collation, which a
      // column of another type cannot have.
      if (collation != null &&
          (type == null || _stringTypes.contains(type))) ...[
        if (existing?.characterSet case var characterSet?)
          'CHARACTER SET $characterSet',
        'COLLATE $collation',
      ],
      if (type != null &&
          _unsignedTypes.contains(type) &&
          (existing?.unsigned ?? false))
        'unsigned',
      if (expression != null)
        'GENERATED ALWAYS AS ($expression) '
            '${(existing?.stored ?? false) ? 'STORED' : 'VIRTUAL'}',
    ];
    if (afterType.isNotEmpty) {
      // compileColumn gives the type first, as it gives it for a nullable
      // column without a default.
      var typeOnly = compileColumn(
        changedColumn(
          column.type,
          length: length,
          precision: precision,
          scale: scale,
        ),
      );
      definition =
          '$typeOnly ${afterType.join(' ')}'
          '${definition.substring(typeOnly.length)}';
    }

    var sql = 'MODIFY ${quoteMySqlIdentifier(name)} $definition';
    if (_autoIncrement) sql += ' AUTO_INCREMENT';
    var onUpdate = existing?.onUpdate;
    if (onUpdate != null && (type == null || _dateTimeTypes.contains(type))) {
      sql += ' ON UPDATE $onUpdate';
    }
    var comment = existing?.comment;
    if (comment != null) {
      sql += ' COMMENT ${compileDefault(comment, escapeBackslashes: true)}';
    }
    // MariaDB drops the CHECK of a column that a MODIFY does not give.
    var check = existing?.check;
    if (check != null) sql += ' CHECK ($check)';
    return sql;
  }
}
