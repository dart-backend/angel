// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'odd_alias.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class OddAlias implements OddAliasEntity {
  OddAlias({
    this.quote,
    this.ref,
    this.backslash,
    required this.price,
    this.counts = const [],
  });

  @override
  String? quote;

  @override
  String? ref;

  @override
  String? backslash;

  @override
  int? price;

  @override
  List<int>? counts;

  OddAlias copyWith({
    String? quote,
    String? ref,
    String? backslash,
    int? price,
    List<int>? counts,
  }) {
    return OddAlias(
      quote: quote ?? this.quote,
      ref: ref ?? this.ref,
      backslash: backslash ?? this.backslash,
      price: price ?? this.price,
      counts: counts ?? this.counts,
    );
  }

  @override
  bool operator ==(other) {
    return other is OddAliasEntity &&
        other.quote == quote &&
        other.ref == ref &&
        other.backslash == backslash &&
        other.price == price &&
        ListEquality<int>(DefaultEquality<int>()).equals(other.counts, counts);
  }

  @override
  int get hashCode {
    return Object.hashAll([quote, ref, backslash, price, counts?.length]);
  }

  @override
  String toString() {
    return 'OddAlias(quote=$quote, ref=$ref, backslash=$backslash, price=$price, counts=$counts)';
  }

  Map<String, dynamic> toJson() {
    return OddAliasSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const OddAliasSerializer oddAliasSerializer = OddAliasSerializer();

class OddAliasEncoder extends Converter<OddAlias, Map> {
  const OddAliasEncoder();

  @override
  Map convert(OddAlias model) => OddAliasSerializer.toMap(model);
}

class OddAliasDecoder extends Converter<Map, OddAlias> {
  const OddAliasDecoder();

  @override
  OddAlias convert(Map map) => OddAliasSerializer.fromMap(map);
}

class OddAliasSerializer extends Codec<OddAlias, Map> {
  const OddAliasSerializer();

  /// The name of the JSON Schema of [OddAlias].
  static const String schemaName = 'OddAlias';

  /// The JSON Schema of the map that [toMap] writes of [OddAlias], whose
  /// models are `$ref`s to `#/components/schemas`.
  static const Map<String, dynamic> jsonSchema = {
    'type': 'object',
    'properties': {
      "it's": {
        'type': ['string', 'null'],
      },
      '\$ref': {
        'type': ['string', 'null'],
      },
      'back\\slash': {
        'type': ['string', 'null'],
      },
      "price \$ and 'tax'": {'type': 'integer'},
      'two words': {
        'type': ['array', 'null'],
        'items': {'type': 'integer'},
      },
    },
    'required': ["price \$ and 'tax'"],
  };

  @override
  OddAliasEncoder get encoder => const OddAliasEncoder();

  @override
  OddAliasDecoder get decoder => const OddAliasDecoder();

  static OddAlias fromMap(Map map) {
    if (map["price \$ and 'tax'"] == null) {
      throw FormatException(
        "Missing required field 'price \$ and 'tax'' on OddAlias.",
      );
    }

    return OddAlias(
      quote: map["it's"] as String?,
      ref: map['\$ref'] as String?,
      backslash: map['back\\slash'] as String?,
      price: map["price \$ and 'tax'"] as int?,
      counts: map['two words'] is Iterable
          ? (map['two words'] as Iterable).cast<int>().toList()
          : [],
    );
  }

  /// Adds the JSON Schema of [OddAlias], and those of the models it
  /// holds, to [schemas], by name.
  static void addJsonSchemas(Map<String, Map<String, dynamic>> schemas) {
    if (schemas.containsKey(schemaName)) return;
    schemas[schemaName] = jsonSchema;
  }

  static Map<String, dynamic> toMap(OddAliasEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    if (model.price == null) {
      throw FormatException(
        "Missing required field 'price \$ and 'tax'' on OddAlias.",
      );
    }

    return {
      "it's": model.quote,
      '\$ref': model.ref,
      'back\\slash': model.backslash,
      "price \$ and 'tax'": model.price,
      'two words': model.counts,
    };
  }
}

abstract class OddAliasFields {
  static const List<String> allFields = <String>[
    quote,
    ref,
    backslash,
    price,
    counts,
  ];

  static const String quote = "it's";

  static const String ref = '\$ref';

  static const String backslash = 'back\\slash';

  static const String price = "price \$ and 'tax'";

  static const String counts = 'two words';
}
