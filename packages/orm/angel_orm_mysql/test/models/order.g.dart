// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class OrderMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'orders',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
        table.integer('employee_id');
        table.timeStamp('order_date');
        table.integer('shipper_id');
        table
            .declare(
              'customer_id',
              ColumnType('int'),
            )
            .references(
              'customers',
              'id',
            );
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('orders');
  }
}

class CustomerMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create(
      'customers',
      (table) {
        table.serial('id').primaryKey();
        table.timeStamp('created_at');
        table.timeStamp('updated_at');
      },
    );
  }

  @override
  void down(Schema schema) {
    schema.drop('customers');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class OrderQuery extends Query<Order, OrderQueryWhere> {
  OrderQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = OrderQueryWhere(this);
    leftJoin(
      _customer = CustomerQuery(
        trampoline: trampoline,
        parent: this,
      ),
      'customer_id',
      'id',
      additionalFields: const [
        'id',
        'created_at',
        'updated_at',
      ],
      trampoline: trampoline,
    );
  }

  @override
  final OrderQueryValues values = OrderQueryValues();

  List<String> _selectedFields = [];

  OrderQueryWhere? _where;

  late CustomerQuery _customer;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'orders';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
      'customer_id',
      'employee_id',
      'order_date',
      'shipper_id',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  OrderQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  OrderQueryWhere? get where {
    return _where;
  }

  @override
  OrderQueryWhere newWhereClause() {
    return OrderQueryWhere(this);
  }

  Optional<Order> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Order(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
      employeeId: fields.contains('employee_id') ? (row[4] as int?) : null,
      orderDate:
          fields.contains('order_date') ? mapToNullableDateTime(row[5]) : null,
      shipperId: fields.contains('shipper_id') ? (row[6] as int?) : null,
    );
    if (row.length > 7) {
      var modelOpt = CustomerQuery().parseRow(row.skip(7).take(3).toList());
      modelOpt.ifPresent((m) {
        model = model.copyWith(customer: m);
      });
    }
    return Optional.of(model);
  }

  @override
  Optional<Order> deserialize(List row) {
    return parseRow(row);
  }

  CustomerQuery get customer {
    return _customer;
  }
}

class OrderQueryWhere extends QueryWhere {
  OrderQueryWhere(OrderQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        createdAt = DateTimeSqlExpressionBuilder(
          query,
          'created_at',
        ),
        updatedAt = DateTimeSqlExpressionBuilder(
          query,
          'updated_at',
        ),
        customerId = NumericSqlExpressionBuilder<int>(
          query,
          'customer_id',
        ),
        employeeId = NumericSqlExpressionBuilder<int>(
          query,
          'employee_id',
        ),
        orderDate = DateTimeSqlExpressionBuilder(
          query,
          'order_date',
        ),
        shipperId = NumericSqlExpressionBuilder<int>(
          query,
          'shipper_id',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final NumericSqlExpressionBuilder<int> customerId;

  final NumericSqlExpressionBuilder<int> employeeId;

  final DateTimeSqlExpressionBuilder orderDate;

  final NumericSqlExpressionBuilder<int> shipperId;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
      customerId,
      employeeId,
      orderDate,
      shipperId,
    ];
  }
}

class OrderQueryValues extends MapQueryValues {
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
  int get customerId {
    return (values['customer_id'] as int);
  }

  set customerId(int value) => values['customer_id'] = value;
  int? get employeeId {
    return (values['employee_id'] as int?);
  }

  set employeeId(int? value) => values['employee_id'] = value;
  DateTime? get orderDate {
    return (values['order_date'] as DateTime?);
  }

  set orderDate(DateTime? value) => values['order_date'] = value;
  int? get shipperId {
    return (values['shipper_id'] as int?);
  }

  set shipperId(int? value) => values['shipper_id'] = value;
  void copyFrom(Order model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    employeeId = model.employeeId;
    orderDate = model.orderDate;
    shipperId = model.shipperId;
    if (model.customer != null) {
      values['customer_id'] = model.customer?.id;
    }
  }
}

class CustomerQuery extends Query<Customer, CustomerQueryWhere> {
  CustomerQuery({
    Query? parent,
    Set<String>? trampoline,
  }) : super(parent: parent) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = CustomerQueryWhere(this);
  }

  @override
  final CustomerQueryValues values = CustomerQueryValues();

  List<String> _selectedFields = [];

  CustomerQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'customers';
  }

  @override
  List<String> get fields {
    const _fields = [
      'id',
      'created_at',
      'updated_at',
    ];
    return _selectedFields.isEmpty
        ? _fields
        : _fields.where((field) => _selectedFields.contains(field)).toList();
  }

  CustomerQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  CustomerQueryWhere? get where {
    return _where;
  }

  @override
  CustomerQueryWhere newWhereClause() {
    return CustomerQueryWhere(this);
  }

  Optional<Customer> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = Customer(
      id: fields.contains('id') ? row[0].toString() : null,
      createdAt:
          fields.contains('created_at') ? mapToNullableDateTime(row[1]) : null,
      updatedAt:
          fields.contains('updated_at') ? mapToNullableDateTime(row[2]) : null,
    );
    return Optional.of(model);
  }

  @override
  Optional<Customer> deserialize(List row) {
    return parseRow(row);
  }
}

class CustomerQueryWhere extends QueryWhere {
  CustomerQueryWhere(CustomerQuery query)
      : id = NumericSqlExpressionBuilder<int>(
          query,
          'id',
        ),
        createdAt = DateTimeSqlExpressionBuilder(
          query,
          'created_at',
        ),
        updatedAt = DateTimeSqlExpressionBuilder(
          query,
          'updated_at',
        );

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [
      id,
      createdAt,
      updatedAt,
    ];
  }
}

class CustomerQueryValues extends MapQueryValues {
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
  void copyFrom(Customer model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Order extends _Order {
  Order({
    this.id,
    this.createdAt,
    this.updatedAt,
    this.customer,
    this.employeeId,
    this.orderDate,
    this.shipperId,
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
  _Customer? customer;

  @override
  int? employeeId;

  @override
  DateTime? orderDate;

  @override
  int? shipperId;

  Order copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    _Customer? customer,
    int? employeeId,
    DateTime? orderDate,
    int? shipperId,
  }) {
    return Order(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        customer: customer ?? this.customer,
        employeeId: employeeId ?? this.employeeId,
        orderDate: orderDate ?? this.orderDate,
        shipperId: shipperId ?? this.shipperId);
  }

  @override
  bool operator ==(other) {
    return other is _Order &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.customer == customer &&
        other.employeeId == employeeId &&
        other.orderDate == orderDate &&
        other.shipperId == shipperId;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
      customer,
      employeeId,
      orderDate,
      shipperId,
    ]);
  }

  @override
  String toString() {
    return 'Order(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, customer=$customer, employeeId=$employeeId, orderDate=$orderDate, shipperId=$shipperId)';
  }

  Map<String, dynamic> toJson() {
    return OrderSerializer.toMap(this);
  }
}

@generatedSerializable
class Customer extends _Customer {
  Customer({
    this.id,
    this.createdAt,
    this.updatedAt,
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

  Customer copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt);
  }

  @override
  bool operator ==(other) {
    return other is _Customer &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return hashObjects([
      id,
      createdAt,
      updatedAt,
    ]);
  }

  @override
  String toString() {
    return 'Customer(id=$id, createdAt=$createdAt, updatedAt=$updatedAt)';
  }

  Map<String, dynamic> toJson() {
    return CustomerSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const OrderSerializer orderSerializer = OrderSerializer();

class OrderEncoder extends Converter<Order, Map> {
  const OrderEncoder();

  @override
  Map convert(Order model) => OrderSerializer.toMap(model);
}

class OrderDecoder extends Converter<Map, Order> {
  const OrderDecoder();

  @override
  Order convert(Map map) => OrderSerializer.fromMap(map);
}

class OrderSerializer extends Codec<Order, Map> {
  const OrderSerializer();

  @override
  OrderEncoder get encoder => const OrderEncoder();
  @override
  OrderDecoder get decoder => const OrderDecoder();
  static Order fromMap(Map map) {
    return Order(
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
        customer: map['customer'] != null
            ? CustomerSerializer.fromMap(map['customer'] as Map)
            : null,
        employeeId: map['employee_id'] as int?,
        orderDate: map['order_date'] != null
            ? (map['order_date'] is DateTime
                ? (map['order_date'] as DateTime)
                : DateTime.parse(map['order_date'].toString()))
            : null,
        shipperId: map['shipper_id'] as int?);
  }

  static Map<String, dynamic> toMap(_Order? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'customer': CustomerSerializer.toMap(model.customer),
      'employee_id': model.employeeId,
      'order_date': model.orderDate?.toIso8601String(),
      'shipper_id': model.shipperId
    };
  }
}

abstract class OrderFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    customer,
    employeeId,
    orderDate,
    shipperId,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String customer = 'customer';

  static const String employeeId = 'employee_id';

  static const String orderDate = 'order_date';

  static const String shipperId = 'shipper_id';
}

const CustomerSerializer customerSerializer = CustomerSerializer();

class CustomerEncoder extends Converter<Customer, Map> {
  const CustomerEncoder();

  @override
  Map convert(Customer model) => CustomerSerializer.toMap(model);
}

class CustomerDecoder extends Converter<Map, Customer> {
  const CustomerDecoder();

  @override
  Customer convert(Map map) => CustomerSerializer.fromMap(map);
}

class CustomerSerializer extends Codec<Customer, Map> {
  const CustomerSerializer();

  @override
  CustomerEncoder get encoder => const CustomerEncoder();
  @override
  CustomerDecoder get decoder => const CustomerDecoder();
  static Customer fromMap(Map map) {
    return Customer(
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
            : null);
  }

  static Map<String, dynamic> toMap(_Customer? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String()
    };
  }
}

abstract class CustomerFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';
}
