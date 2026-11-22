import 'package:angel3_serialize/angel3_serialize.dart';
part 'garage.g.dart';

/// Nested models: one that may be `null`, and one that must be given.
@serializable
abstract class GarageEntity {
  CarEntity get main;

  CarEntity? get spare;
}

@serializable
abstract class CarEntity {
  String get make;
}
