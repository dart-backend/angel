// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class EmployeeMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('employees', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('first_name', length: 255);
      table.varChar('last_name', length: 255);
      table.varChar('unique_id', length: 255).unique();
      table.double('salary');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('employees');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class EmployeeQuery extends Query<Employee, EmployeeQueryWhere> {
  EmployeeQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = EmployeeQueryWhere(this);
  }

  @override
  final EmployeeQueryValues values = EmployeeQueryValues();

  List<String> _selectedFields = [];

  EmployeeQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'employees';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'first_name',
      'last_name',
      'unique_id',
      'salary',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  EmployeeQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  EmployeeQueryWhere? get where {
    return _where;
  }

  @override
  EmployeeQueryWhere newWhereClause() {
    return EmployeeQueryWhere(this);
  }

  Optional<Employee> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Employee(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[1])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[2])
          : null,
      firstName: fields.contains('first_name') ? (row[3] as String?) : null,
      lastName: fields.contains('last_name') ? (row[4] as String?) : null,
      uniqueId: fields.contains('unique_id') ? (row[5] as String?) : null,
      salary: fields.contains('salary') ? mapToDouble(row[6]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Employee> deserialize(List row) {
    return parseRow(row);
  }
}

class EmployeeQueryWhere extends QueryWhere {
  EmployeeQueryWhere(EmployeeQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      firstName = StringSqlExpressionBuilder(query, 'first_name'),
      lastName = StringSqlExpressionBuilder(query, 'last_name'),
      uniqueId = StringSqlExpressionBuilder(query, 'unique_id'),
      salary = NumericSqlExpressionBuilder<double>(query, 'salary');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder firstName;

  final StringSqlExpressionBuilder lastName;

  final StringSqlExpressionBuilder uniqueId;

  final NumericSqlExpressionBuilder<double> salary;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, firstName, lastName, uniqueId, salary];
  }
}

class EmployeeQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {};
  }

  String? get id {
    return (values['id'] as String?);
  }

  set id(String? value) => values['id'] = value;

  DateTime? get createdAt {
    return (values['created_at'] as DateTime?);
  }

  set createdAt(DateTime? value) => values['created_at'] = value;

  DateTime? get updatedAt {
    return (values['updated_at'] as DateTime?);
  }

  set updatedAt(DateTime? value) => values['updated_at'] = value;

  String? get firstName {
    return (values['first_name'] as String?);
  }

  set firstName(String? value) => values['first_name'] = value;

  String? get lastName {
    return (values['last_name'] as String?);
  }

  set lastName(String? value) => values['last_name'] = value;

  String? get uniqueId {
    return (values['unique_id'] as String?);
  }

  set uniqueId(String? value) => values['unique_id'] = value;

  double? get salary {
    return (values['salary'] as double?) ?? 0.0;
  }

  set salary(double? value) => values['salary'] = value;

  void copyFrom(Employee model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    firstName = model.firstName;
    lastName = model.lastName;
    uniqueId = model.uniqueId;
    salary = model.salary;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Employee extends _Employee {
  Employee({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.firstName,
    this.lastName,
    this.uniqueId,
    this.salary,
  });

  /// A unique identifier corresponding to this item.
  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  @override
  String? firstName;

  @override
  String? lastName;

  @override
  String? uniqueId;

  @override
  double? salary;

  Employee copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? firstName,
    String? lastName,
    String? uniqueId,
    double? salary,
  }) {
    return Employee(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      uniqueId: uniqueId ?? this.uniqueId,
      salary: salary ?? this.salary,
    );
  }

  @override
  bool operator ==(other) {
    return other is _Employee &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.uniqueId == uniqueId &&
        other.salary == salary;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      firstName,
      lastName,
      uniqueId,
      salary,
    ]);
  }

  @override
  String toString() {
    return 'Employee(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, firstName=$firstName, lastName=$lastName, uniqueId=$uniqueId, salary=$salary)';
  }

  Map<String, dynamic> toJson() {
    return EmployeeSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const EmployeeSerializer employeeSerializer = EmployeeSerializer();

class EmployeeEncoder extends Converter<Employee, Map> {
  const EmployeeEncoder();

  @override
  Map convert(Employee model) => EmployeeSerializer.toMap(model);
}

class EmployeeDecoder extends Converter<Map, Employee> {
  const EmployeeDecoder();

  @override
  Employee convert(Map map) => EmployeeSerializer.fromMap(map);
}

class EmployeeSerializer extends Codec<Employee, Map> {
  const EmployeeSerializer();

  @override
  EmployeeEncoder get encoder => const EmployeeEncoder();

  @override
  EmployeeDecoder get decoder => const EmployeeDecoder();

  static Employee fromMap(Map map) {
    return Employee(
      id: map['id'] as String?,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is DateTime
                ? (map['created_at'] as DateTime)
                : DateTime.parse(map['created_at'].toString()))
          : null,
      updatedAt: map['updated_at'] != null
          ? (map['updated_at'] is DateTime
                ? (map['updated_at'] as DateTime)
                : DateTime.parse(map['updated_at'].toString()))
          : null,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      uniqueId: map['unique_id'] as String?,
      salary: map['salary'] as double?,
    );
  }

  static Map<String, dynamic> toMap(_Employee? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'first_name': model.firstName,
      'last_name': model.lastName,
      'unique_id': model.uniqueId,
      'salary': model.salary,
    };
  }
}

abstract class EmployeeFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    firstName,
    lastName,
    uniqueId,
    salary,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String firstName = 'first_name';

  static const String lastName = 'last_name';

  static const String uniqueId = 'unique_id';

  static const String salary = 'salary';
}
