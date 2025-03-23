// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// OrmGenerator
// **************************************************************************

class EmployeeQuery extends Query<Employee, EmployeeQueryWhere> {
  EmployeeQuery({Query? parent, Set<String>? trampoline})
      : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = EmployeeQueryWhere(this);
  }

  @override
  final EmployeeQueryValues values = EmployeeQueryValues();

  EmployeeQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {'salary': 'text'};
  }

  @override
  String get tableName {
    return 'employees';
  }

  @override
  List<String> get fields {
    return const [
      'id',
      'created_at',
      'updated_at',
      'first_name',
      'last_name',
      'salary'
    ];
  }

  @override
  EmployeeQueryWhere? get where {
    return _where;
  }

  @override
  EmployeeQueryWhere newWhereClause() {
    return EmployeeQueryWhere(this);
  }

  static Optional<Employee> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Employee(
        id: row[0].toString(),
        createdAt: (row[1] as DateTime?),
        updatedAt: (row[2] as DateTime?),
        firstName: (row[3] as String?),
        lastName: (row[4] as String?),
        salary: double.tryParse(row[5].toString()));
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
        salary = NumericSqlExpressionBuilder<double>(query, 'salary');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder firstName;

  final StringSqlExpressionBuilder lastName;

  final NumericSqlExpressionBuilder<double> salary;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, firstName, lastName, salary];
  }
}

class EmployeeQueryValues extends MapQueryValues {
  @override
  Map<String, String> get casts {
    return {'salary': 'decimal'};
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
  double? get salary {
    return double.tryParse((values['salary'] as String));
  }

  set salary(double? value) => values['salary'] = value.toString();
  void copyFrom(Employee model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    firstName = model.firstName;
    lastName = model.lastName;
    salary = model.salary;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Employee extends _Employee {
  Employee(
      {this.id,
      this.createdAt,
      this.updatedAt,
      this.firstName,
      this.lastName,
      this.salary});

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
  double? salary;

  Employee copyWith(
      {String? id,
      DateTime? createdAt,
      DateTime? updatedAt,
      String? firstName,
      String? lastName,
      double? salary}) {
    return Employee(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        salary: salary ?? this.salary);
  }

  @override
  bool operator ==(other) {
    return other is _Employee &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.salary == salary;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt, firstName, lastName, salary]);
  }

  @override
  String toString() {
    return 'Employee(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, firstName=$firstName, lastName=$lastName, salary=$salary)';
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
        salary: map['salary'] as double?);
  }

  static Map<String, dynamic> toMap(_Employee? model) {
    if (model == null) {
      return {};
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'first_name': model.firstName,
      'last_name': model.lastName,
      'salary': model.salary
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
    salary
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String firstName = 'first_name';

  static const String lastName = 'last_name';

  static const String salary = 'salary';
}
