import 'dart:async';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_test/src/models/car.dart';

@Expose('/api/cars')
class CarController extends Controller {
  @Expose('/luxury')
  Future<List<Car>> getLuxuryCars(QueryExecutor connection) {
    var query = CarQuery();
    query.where
      ?..familyFriendly.equals(false)
      ..createdAt.year.greaterThanOrEqualTo(2014)
      ..make.isIn(['Ferrari', 'Lamborghini', 'Mustang', 'Lexus']);
    return query.get(connection);
  }
}
