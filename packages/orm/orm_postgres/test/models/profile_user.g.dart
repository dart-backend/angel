// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_user.dart';

// **************************************************************************
// MigrationGenerator
// **************************************************************************

class ProfileUserMigration extends Migration {
  @override
  void up(Schema schema) {
    schema.create('profile_users', (table) {
      table.serial('id').primaryKey();
      table.timeStamp('created_at');
      table.timeStamp('updated_at');
      table.varChar('name', length: 255);
      table.declare('profile', ColumnType.jsonb);
      table.declare('address', ColumnType.jsonb);
    });
  }

  @override
  void down(Schema schema) {
    schema.drop('profile_users');
  }
}

// **************************************************************************
// OrmGenerator
// **************************************************************************

class ProfileUserQuery extends Query<ProfileUser, ProfileUserQueryWhere> {
  ProfileUserQuery({super.parent, Set<String>? trampoline}) {
    trampoline ??= <String>{};
    trampoline.add(tableName);
    _where = ProfileUserQueryWhere(this);
  }

  @override
  final ProfileUserQueryValues values = ProfileUserQueryValues();

  List<String> _selectedFields = [];

  ProfileUserQueryWhere? _where;

  @override
  Map<String, String> get casts {
    return {};
  }

  @override
  String get tableName {
    return 'profile_users';
  }

  @override
  List<String> get fields {
    const localFields = [
      'id',
      'created_at',
      'updated_at',
      'name',
      'profile',
      'address',
    ];
    return _selectedFields.isEmpty
        ? localFields
        : localFields
              .where((field) => _selectedFields.contains(field))
              .toList();
  }

  ProfileUserQuery select(List<String> selectedFields) {
    _selectedFields = selectedFields;
    return this;
  }

  @override
  ProfileUserQueryWhere? get where {
    return _where;
  }

  @override
  ProfileUserQueryWhere newWhereClause() {
    return ProfileUserQueryWhere(this);
  }

  Optional<ProfileUser> parseRow(List row) {
    if (row.every((x) => x == null)) {
      return Optional.empty();
    }
    var model = ProfileUser(
      id: fields.contains('id') ? row[fields.indexOf('id')].toString() : null,
      createdAt: fields.contains('created_at')
          ? mapToNullableDateTime(row[fields.indexOf('created_at')])
          : null,
      updatedAt: fields.contains('updated_at')
          ? mapToNullableDateTime(row[fields.indexOf('updated_at')])
          : null,
      name: fields.contains('name')
          ? (row[fields.indexOf('name')] as String)
          : '',
      profile: fields.contains('profile')
          ? row[fields.indexOf('profile')] == null
                ? null
                : UserProfileSerializer.fromMap(
                    (row[fields.indexOf('profile')] is String
                        ? json.decode(
                            (row[fields.indexOf('profile')] as String),
                          )
                        : row[fields.indexOf('profile')] as Map),
                  )
          : null,
      address: fields.contains('address')
          ? UserAddressSerializer.fromMap(
              (row[fields.indexOf('address')] is String
                  ? json.decode((row[fields.indexOf('address')] as String))
                  : row[fields.indexOf('address')] as Map),
            )
          : throw StateError('address is not among the fields of the query.'),
    );
    return Optional.of(model);
  }

  @override
  Optional<ProfileUser> deserialize(List row) {
    return parseRow(row);
  }
}

class ProfileUserQueryWhere extends QueryWhere {
  ProfileUserQueryWhere(ProfileUserQuery query)
    : id = NumericSqlExpressionBuilder<int>(query, 'id'),
      createdAt = DateTimeSqlExpressionBuilder(query, 'created_at'),
      updatedAt = DateTimeSqlExpressionBuilder(query, 'updated_at'),
      name = StringSqlExpressionBuilder(query, 'name'),
      profile = MapSqlExpressionBuilder(query, 'profile'),
      address = MapSqlExpressionBuilder(query, 'address');

  final NumericSqlExpressionBuilder<int> id;

  final DateTimeSqlExpressionBuilder createdAt;

  final DateTimeSqlExpressionBuilder updatedAt;

  final StringSqlExpressionBuilder name;

  final MapSqlExpressionBuilder profile;

  final MapSqlExpressionBuilder address;

  @override
  List<SqlExpressionBuilder> get expressionBuilders {
    return [id, createdAt, updatedAt, name, profile, address];
  }
}

class ProfileUserQueryValues extends MapQueryValues {
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

  String get name {
    return (values['name'] as String);
  }

  set name(String value) => values['name'] = value;

  _UserProfile? get profile {
    return values['profile'] == null
        ? null
        : UserProfileSerializer.fromMap((values['profile'] as Map));
  }

  set profile(_UserProfile? value) => values['profile'] = value == null
      ? null
      : UserProfileSerializer.toMap(value);

  _UserAddress get address {
    return UserAddressSerializer.fromMap((values['address'] as Map));
  }

  set address(_UserAddress value) =>
      values['address'] = UserAddressSerializer.toMap(value);

  void copyFrom(ProfileUser model) {
    createdAt = model.createdAt;
    updatedAt = model.updatedAt;
    name = model.name;
    profile = model.profile;
    address = model.address;
  }
}

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class ProfileUser extends _ProfileUser {
  ProfileUser({
    this.id,
    this.createdAt,
    this.updatedAt,
    required this.name,
    this.profile,
    required this.address,
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
  String name;

  @override
  _UserProfile? profile;

  @override
  _UserAddress address;

  ProfileUser copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? name,
    _UserProfile? profile,
    _UserAddress? address,
  }) {
    return ProfileUser(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      profile: profile ?? this.profile,
      address: address ?? this.address,
    );
  }

  @override
  bool operator ==(other) {
    return other is _ProfileUser &&
        other.id == id &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.name == name &&
        other.profile == profile &&
        other.address == address;
  }

  @override
  int get hashCode {
    return Object.hashAll([id, createdAt, updatedAt, name, profile, address]);
  }

  @override
  String toString() {
    return 'ProfileUser(id=$id, createdAt=$createdAt, updatedAt=$updatedAt, name=$name, profile=$profile, address=$address)';
  }

  Map<String, dynamic> toJson() {
    return ProfileUserSerializer.toMap(this);
  }
}

@generatedSerializable
class UserProfile implements _UserProfile {
  UserProfile({required this.firstName, required this.lastName});

  @override
  String firstName;

  @override
  String lastName;

  UserProfile copyWith({String? firstName, String? lastName}) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
    );
  }

  @override
  bool operator ==(other) {
    return other is _UserProfile &&
        other.firstName == firstName &&
        other.lastName == lastName;
  }

  @override
  int get hashCode {
    return Object.hashAll([firstName, lastName]);
  }

  @override
  String toString() {
    return 'UserProfile(firstName=$firstName, lastName=$lastName)';
  }

  Map<String, dynamic> toJson() {
    return UserProfileSerializer.toMap(this);
  }
}

@generatedSerializable
class UserAddress implements _UserAddress {
  UserAddress({required this.city});

  @override
  String city;

  UserAddress copyWith({String? city}) {
    return UserAddress(city: city ?? this.city);
  }

  @override
  bool operator ==(other) {
    return other is _UserAddress && other.city == city;
  }

  @override
  int get hashCode {
    return Object.hashAll([city]);
  }

  @override
  String toString() {
    return 'UserAddress(city=$city)';
  }

  Map<String, dynamic> toJson() {
    return UserAddressSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const ProfileUserSerializer profileUserSerializer = ProfileUserSerializer();

class ProfileUserEncoder extends Converter<ProfileUser, Map> {
  const ProfileUserEncoder();

  @override
  Map convert(ProfileUser model) => ProfileUserSerializer.toMap(model);
}

class ProfileUserDecoder extends Converter<Map, ProfileUser> {
  const ProfileUserDecoder();

  @override
  ProfileUser convert(Map map) => ProfileUserSerializer.fromMap(map);
}

class ProfileUserSerializer extends Codec<ProfileUser, Map> {
  const ProfileUserSerializer();

  /// The name of the JSON Schema of [ProfileUser].
  static const String schemaName = 'ProfileUser';

  /// The JSON Schema of the map that [toMap] writes of [ProfileUser], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'id': {
        'type': ['string', 'null'],
      },
      'created_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'updated_at': {
        'type': ['string', 'null'],
        'format': 'date-time',
      },
      'name': {'type': 'string'},
      'profile': {
        'anyOf': [
          {'\$ref': '#/components/schemas/UserProfile'},
          {'type': 'null'},
        ],
      },
      'address': {'\$ref': '#/components/schemas/UserAddress'},
    },
    'required': ['name', 'address'],
  };

  @override
  ProfileUserEncoder get encoder => const ProfileUserEncoder();

  @override
  ProfileUserDecoder get decoder => const ProfileUserDecoder();

  static ProfileUser fromMap(Map map) {
    return ProfileUser(
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
      name: map['name'] as String,
      profile: map['profile'] != null
          ? UserProfileSerializer.fromMap(map['profile'] as Map)
          : null,
      address: UserAddressSerializer.fromMap(map['address'] as Map),
    );
  }

  /// Adds the JSON Schema of [ProfileUser], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
    UserProfileSerializer.addJsonSchemas(schemas);
    UserAddressSerializer.addJsonSchemas(schemas);
  }

  static Map<String, dynamic> toMap(_ProfileUser? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'id': model.id,
      'created_at': model.createdAt?.toIso8601String(),
      'updated_at': model.updatedAt?.toIso8601String(),
      'name': model.name,
      'profile': model.profile == null
          ? null
          : UserProfileSerializer.toMap(model.profile),
      'address': UserAddressSerializer.toMap(model.address),
    };
  }
}

abstract class ProfileUserFields {
  static const List<String> allFields = <String>[
    id,
    createdAt,
    updatedAt,
    name,
    profile,
    address,
  ];

  static const String id = 'id';

  static const String createdAt = 'created_at';

  static const String updatedAt = 'updated_at';

  static const String name = 'name';

  static const String profile = 'profile';

  static const String address = 'address';
}

const UserProfileSerializer userProfileSerializer = UserProfileSerializer();

class UserProfileEncoder extends Converter<UserProfile, Map> {
  const UserProfileEncoder();

  @override
  Map convert(UserProfile model) => UserProfileSerializer.toMap(model);
}

class UserProfileDecoder extends Converter<Map, UserProfile> {
  const UserProfileDecoder();

  @override
  UserProfile convert(Map map) => UserProfileSerializer.fromMap(map);
}

class UserProfileSerializer extends Codec<UserProfile, Map> {
  const UserProfileSerializer();

  /// The name of the JSON Schema of [UserProfile].
  static const String schemaName = 'UserProfile';

  /// The JSON Schema of the map that [toMap] writes of [UserProfile], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'first_name': {'type': 'string'},
      'last_name': {'type': 'string'},
    },
    'required': ['first_name', 'last_name'],
  };

  @override
  UserProfileEncoder get encoder => const UserProfileEncoder();

  @override
  UserProfileDecoder get decoder => const UserProfileDecoder();

  static UserProfile fromMap(Map map) {
    return UserProfile(
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
    );
  }

  /// Adds the JSON Schema of [UserProfile], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(_UserProfile? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'first_name': model.firstName, 'last_name': model.lastName};
  }
}

abstract class UserProfileFields {
  static const List<String> allFields = <String>[firstName, lastName];

  static const String firstName = 'first_name';

  static const String lastName = 'last_name';
}

const UserAddressSerializer userAddressSerializer = UserAddressSerializer();

class UserAddressEncoder extends Converter<UserAddress, Map> {
  const UserAddressEncoder();

  @override
  Map convert(UserAddress model) => UserAddressSerializer.toMap(model);
}

class UserAddressDecoder extends Converter<Map, UserAddress> {
  const UserAddressDecoder();

  @override
  UserAddress convert(Map map) => UserAddressSerializer.fromMap(map);
}

class UserAddressSerializer extends Codec<UserAddress, Map> {
  const UserAddressSerializer();

  /// The name of the JSON Schema of [UserAddress].
  static const String schemaName = 'UserAddress';

  /// The JSON Schema of the map that [toMap] writes of [UserAddress], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'city': {'type': 'string'},
    },
    'required': ['city'],
  };

  @override
  UserAddressEncoder get encoder => const UserAddressEncoder();

  @override
  UserAddressDecoder get decoder => const UserAddressDecoder();

  static UserAddress fromMap(Map map) {
    return UserAddress(city: map['city'] as String);
  }

  /// Adds the JSON Schema of [UserAddress], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(_UserAddress? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'city': model.city};
  }
}

abstract class UserAddressFields {
  static const List<String> allFields = <String>[city];

  static const String city = 'city';
}
