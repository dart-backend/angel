// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'with_enum.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class WithEnum implements _WithEnum {
  WithEnum({
    this.type = WithEnumType.b,
    this.finalList = const [],
    this.imageBytes,
  });

  @override
  WithEnumType? type;

  @override
  List<int>? finalList;

  @override
  Uint8List? imageBytes;

  WithEnum copyWith({
    WithEnumType? type,
    List<int>? finalList,
    Uint8List? imageBytes,
  }) {
    return WithEnum(
        type: type ?? this.type,
        finalList: finalList ?? this.finalList,
        imageBytes: imageBytes ?? this.imageBytes);
  }

  @override
  bool operator ==(other) {
    return other is _WithEnum &&
        other.type == type &&
        ListEquality<int>(DefaultEquality<int>())
            .equals(other.finalList, finalList) &&
        ListEquality().equals(other.imageBytes, imageBytes);
  }

  @override
  int get hashCode {
    return hashObjects([
      type,
      finalList,
      imageBytes,
    ]);
  }

  @override
  String toString() {
    return 'WithEnum(type=$type, finalList=$finalList, imageBytes=$imageBytes)';
  }

  Map<String, dynamic> toJson() {
    return WithEnumSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const WithEnumSerializer withEnumSerializer = WithEnumSerializer();

class WithEnumEncoder extends Converter<WithEnum, Map> {
  const WithEnumEncoder();

  @override
  Map convert(WithEnum model) => WithEnumSerializer.toMap(model);
}

class WithEnumDecoder extends Converter<Map, WithEnum> {
  const WithEnumDecoder();

  @override
  WithEnum convert(Map map) => WithEnumSerializer.fromMap(map);
}

class WithEnumSerializer extends Codec<WithEnum, Map> {
  const WithEnumSerializer();

  @override
  WithEnumEncoder get encoder => const WithEnumEncoder();

  @override
  WithEnumDecoder get decoder => const WithEnumDecoder();

  static WithEnum fromMap(Map map) {
    return WithEnum(
        type: map['type'] as WithEnumType? ?? WithEnumType.b,
        finalList: map['final_list'] is Iterable
            ? (map['final_list'] as Iterable).cast<int>().toList()
            : [],
        imageBytes: map['image_bytes'] is Uint8List
            ? (map['image_bytes'] as Uint8List)
            : (map['image_bytes'] is Iterable<int>
                ? Uint8List.fromList(
                    (map['image_bytes'] as Iterable<int>).toList())
                : (map['image_bytes'] is String
                    ? Uint8List.fromList(
                        base64.decode(map['image_bytes'] as String))
                    : null)));
  }

  static Map<String, dynamic> toMap(_WithEnum? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'type': model.type,
      'final_list': model.finalList,
      'image_bytes':
          model.imageBytes != null ? base64.encode(model.imageBytes!) : null
    };
  }
}

abstract class WithEnumFields {
  static const List<String> allFields = <String>[
    type,
    finalList,
    imageBytes,
  ];

  static const String type = 'type';

  static const String finalList = 'final_list';

  static const String imageBytes = 'image_bytes';
}
