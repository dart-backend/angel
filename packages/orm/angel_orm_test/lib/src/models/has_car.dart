import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';

// import 'car.dart';
part 'has_car.g.dart';

// Map _carToMap(Car car) => car.toJson();

// Car _carFromMap(map) => CarSerializer.fromMap(map as Map);

enum CarType { sedan, suv, atv }

@orm
@serializable
abstract class _HasCar extends Model {
  // TODO: Do this without explicit serializers
  // @SerializableField(
  //     serializesTo: Map, serializer: #_carToMap, deserializer: #_carFromMap)
  // Car get car;

  @SerializableField(isNullable: false, defaultValue: CarType.sedan)
  CarType? get type;
}
