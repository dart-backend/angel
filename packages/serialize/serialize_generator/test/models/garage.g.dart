// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'garage.dart';

// **************************************************************************
// JsonModelGenerator
// **************************************************************************

@generatedSerializable
class Garage implements GarageEntity {
  Garage({required this.main, this.spare});

  @override
  CarEntity main;

  @override
  CarEntity? spare;

  Garage copyWith({CarEntity? main, CarEntity? spare}) {
    return Garage(main: main ?? this.main, spare: spare ?? this.spare);
  }

  @override
  bool operator ==(other) {
    return other is GarageEntity && other.main == main && other.spare == spare;
  }

  @override
  int get hashCode {
    return Object.hashAll([main, spare]);
  }

  @override
  String toString() {
    return 'Garage(main=$main, spare=$spare)';
  }

  Map<String, dynamic> toJson() {
    return GarageSerializer.toMap(this);
  }
}

@generatedSerializable
class Car implements CarEntity {
  Car({required this.make});

  @override
  String make;

  Car copyWith({String? make}) {
    return Car(make: make ?? this.make);
  }

  @override
  bool operator ==(other) {
    return other is CarEntity && other.make == make;
  }

  @override
  int get hashCode {
    return Object.hashAll([make]);
  }

  @override
  String toString() {
    return 'Car(make=$make)';
  }

  Map<String, dynamic> toJson() {
    return CarSerializer.toMap(this);
  }
}

// **************************************************************************
// SerializerGenerator
// **************************************************************************

const GarageSerializer garageSerializer = GarageSerializer();

class GarageEncoder extends Converter<Garage, Map> {
  const GarageEncoder();

  @override
  Map convert(Garage model) => GarageSerializer.toMap(model);
}

class GarageDecoder extends Converter<Map, Garage> {
  const GarageDecoder();

  @override
  Garage convert(Map map) => GarageSerializer.fromMap(map);
}

class GarageSerializer extends Codec<Garage, Map> {
  const GarageSerializer();

  @override
  GarageEncoder get encoder => const GarageEncoder();

  @override
  GarageDecoder get decoder => const GarageDecoder();

  static Garage fromMap(Map map) {
    return Garage(
      main: CarSerializer.fromMap(map['main'] as Map),
      spare: map['spare'] != null
          ? CarSerializer.fromMap(map['spare'] as Map)
          : null,
    );
  }

  static Map<String, dynamic> toMap(GarageEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {
      'main': CarSerializer.toMap(model.main),
      'spare': model.spare == null ? null : CarSerializer.toMap(model.spare),
    };
  }
}

abstract class GarageFields {
  static const List<String> allFields = <String>[main, spare];

  static const String main = 'main';

  static const String spare = 'spare';
}

const CarSerializer carSerializer = CarSerializer();

class CarEncoder extends Converter<Car, Map> {
  const CarEncoder();

  @override
  Map convert(Car model) => CarSerializer.toMap(model);
}

class CarDecoder extends Converter<Map, Car> {
  const CarDecoder();

  @override
  Car convert(Map map) => CarSerializer.fromMap(map);
}

class CarSerializer extends Codec<Car, Map> {
  const CarSerializer();

  @override
  CarEncoder get encoder => const CarEncoder();

  @override
  CarDecoder get decoder => const CarDecoder();

  static Car fromMap(Map map) {
    return Car(make: map['make'] as String);
  }

  static Map<String, dynamic> toMap(CarEntity? model) {
    if (model == null) {
      throw FormatException("Required field [model] cannot be null");
    }
    return {'make': model.make};
  }
}

abstract class CarFields {
  static const List<String> allFields = <String>[make];

  static const String make = 'make';
}
