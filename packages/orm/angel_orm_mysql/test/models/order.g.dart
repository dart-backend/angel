// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class OrderMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('orders', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.integer('employee_id');
      table.timeStamp('order_date');
      table.integer('shipper_id');
      table
          .declare('customer_id', ColumnType('int'))
          .references('customers', 'id');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('orders');
  }
}

class CustomerMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('customers', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('customers');
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Order extends EntityOrder {
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
  EntityCustomer? customer;

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
    EntityCustomer? customer,
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
      shipperId: shipperId ?? this.shipperId,
    );
  }

  @override
  bool operator ==(other) {
    return other is EntityOrder &&
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
class Customer extends EntityCustomer {
  Customer({this.id, this.createdAt, this.updatedAt});

  /// A unique identifier corresponding to this item.
  @override
  String? id;

  /// The time at which this item was created.
  @override
  DateTime? createdAt;

  /// The last time at which this item was updated.
  @override
  DateTime? updatedAt;

  Customer copyWith({String? id, DateTime? createdAt, DateTime? updatedAt}) {
    return Customer(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(other) {
    return other is EntityCustomer &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return hashObjects([id, createdAt, updatedAt]);
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
      shipperId: map['shipper_id'] as int?,
    );
  }

  static Map<String, dynamic> toMap(EntityOrder? model) {
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
      'shipper_id': model.shipperId,
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
          : null,
    );
  }

  static Map<String, dynamic> toMap(EntityCustomer? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
    };
  }
}

abstract class CustomerFields {
  static const List<String> allFields = <String>[id, createdAt, updatedAt];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';
}
