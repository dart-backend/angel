import 'package:angel3_orm/angel3_orm.dart';

class MigrationColumn extends Column {
  final List<MigrationColumnReference> _references = [];
  late bool _nullable;
  late IndexType _index;
  dynamic _defaultValue;

  @override
  bool get isNullable => _nullable;

  @override
  IndexType get indexType => _index;

  @override
  dynamic get defaultValue => _defaultValue;

  List<MigrationColumnReference> get externalReferences =>
      List<MigrationColumnReference>.unmodifiable(_references);

  /// Throws an [ArgumentError] if [type] has a precision and [precision] is
  /// not positive, or has a scale and [scale] is negative or greater than
  /// the precision ([Column.defaultPrecision] if [precision] is `null`),
  /// which databases reject only when the migration is run.
  MigrationColumn(
    ColumnType type, {
    bool isNullable = true,
    super.name,
    super.length,
    super.precision,
    super.scale,
    super.timezone,
    super.expression,
    IndexType indexType = IndexType.none,
    dynamic defaultValue,
  }) : super(type: type, isNullable: isNullable, defaultValue: defaultValue) {
    var precision = this.precision, scale = this.scale;
    if (type.hasPrecision && precision != null && precision < 1) {
      throw ArgumentError.value(
        precision,
        'precision',
        'The precision of a ${type.name} column must be at least 1',
      );
    }
    var maxScale = precision ?? Column.defaultPrecision;
    if (type.hasScale && scale != null && (scale < 0 || scale > maxScale)) {
      throw ArgumentError.value(
        scale,
        'scale',
        'The scale of a ${type.name} column must be from 0 to its precision '
            '($maxScale)',
      );
    }
    _nullable = isNullable;
    _index = indexType;
    _defaultValue = defaultValue;
  }

  /// [column] if it is a [MigrationColumn], or a [MigrationColumn] with all
  /// of its attributes.
  factory MigrationColumn.from(Column column) => column is MigrationColumn
      ? column
      : MigrationColumn(
          column.type,
          isNullable: column.isNullable,
          name: column.name,
          length: column.length,
          precision: column.precision,
          scale: column.scale,
          timezone: column.timezone,
          expression: column.expression,
          indexType: column.indexType,
          defaultValue: column.defaultValue,
        );

  /// The precision and scale of [type] in SQL, such as `(10, 2)`, or `''` if
  /// it has none: those given, a scale without a precision with
  /// [Column.defaultPrecision], and neither as `''` if the database has an
  /// [unbounded] type without them (PostgreSQL's `numeric`), or else as
  /// [Column.defaultPrecision] and [Column.defaultScale].
  ///
  /// Throws an [ArgumentError] if the precision is greater than
  /// [maxPrecision] or the scale greater than [maxScale], the limits of the
  /// database, which it would reject only when the migration is run.
  String precisionArguments({
    bool unbounded = false,
    int? maxPrecision,
    int? maxScale,
  }) {
    if (!type.hasPrecision) return '';
    var precision = this.precision, scale = type.hasScale ? this.scale : null;
    if (precision == null && scale == null) {
      if (unbounded) return '';
      precision = Column.defaultPrecision;
      if (type.hasScale) scale = Column.defaultScale;
    }
    precision ??= Column.defaultPrecision;
    if (maxPrecision != null && precision > maxPrecision) {
      throw ArgumentError.value(
        precision,
        'precision',
        'The precision of a ${type.name} column can be at most $maxPrecision',
      );
    }
    if (maxScale != null && scale != null && scale > maxScale) {
      throw ArgumentError.value(
        scale,
        'scale',
        'The scale of a ${type.name} column can be at most $maxScale',
      );
    }
    return scale == null ? '($precision)' : '($precision, $scale)';
  }

  MigrationColumn notNull() => this.._nullable = false;

  MigrationColumn defaultsTo(Object? value) => this.._defaultValue = value;

  MigrationColumn unique() => this.._index = IndexType.unique;

  MigrationColumn primaryKey() => this.._index = IndexType.primaryKey;

  MigrationColumnReference references(String foreignTable, String foreignKey) {
    var ref = MigrationColumnReference._(foreignTable, foreignKey);
    _references.add(ref);
    return ref;
  }
}

class MigrationColumnReference {
  final String foreignTable, foreignKey;
  String? _behavior;

  MigrationColumnReference._(this.foreignTable, this.foreignKey);

  String? get behavior => _behavior;

  StateError _locked() =>
      StateError('Cannot override existing "$_behavior" behavior.');

  void onDeleteCascade() {
    if (_behavior != null) throw _locked();
    _behavior = 'ON DELETE CASCADE';
  }

  void onUpdateCascade() {
    if (_behavior != null) throw _locked();
    _behavior = 'ON UPDATE CASCADE';
  }

  void onNoAction() {
    if (_behavior != null) throw _locked();
    _behavior = 'ON UPDATE NO ACTION';
  }

  void onUpdateSetDefault() {
    if (_behavior != null) throw _locked();
    _behavior = 'ON UPDATE SET DEFAULT';
  }

  void onUpdateSetNull() {
    if (_behavior != null) throw _locked();
    _behavior = 'ON UPDATE SET NULL';
  }
}
