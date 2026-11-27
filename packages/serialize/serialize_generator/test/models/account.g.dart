// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Account extends AccountEntity {
  Account(
    String region, {
    int tier = 1,
    required this.owner,
    this.note,
    this.email,
  }) : super(region, owner: owner, tier: tier, note: note);

  @override
  String owner;

  @override
  String? note;

  @override
  String? email;

  Account copyWith(
    String region, {
    int tier = 1,
    String? owner,
    String? note,
    String? email,
  }) {
    return Account(
      region,
      tier: tier,
      owner: owner ?? this.owner,
      note: note ?? this.note,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(other) {
    return other is AccountEntity &&
        other.owner == owner &&
        other.note == note &&
        other.email == email;
  }

  @override
  int get hashCode {
    return Object.hashAll([owner, note, email]);
  }

  @override
  String toString() {
    return 'Account(owner=$owner, note=$note, email=$email)';
  }

  Map<String, dynamic> toJson() {
    return AccountSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

abstract class AccountSerializer {
  /// The name of the JSON Schema of [Account].
  static const String schemaName = 'Account';

  /// The JSON Schema of the map that [toMap] writes of [Account], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      'owner': {'type': 'string'},
      'note': {
        'type': ['string', 'null'],
      },
      'email': {
        'type': ['string', 'null'],
      },
    },
    'required': ['owner'],
  };

  static Account fromMap(Map map, String region, {int tier = 1}) {
    return Account(
      region,
      tier: tier,
      owner: map['owner'] as String,
      note: map['note'] as String?,
      email: map['email'] as String?,
    );
  }

  /// Adds the JSON Schema of [Account], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(AccountEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'owner': model.owner, 'note': model.note, 'email': model.email};
  }
}

abstract class AccountFields {
  static const List<String> allFields = <String>[owner, note, email];

  static const String owner = 'owner';

  static const String note = 'note';

  static const String email = 'email';
}
