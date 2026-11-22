import 'package:test/test.dart';

import 'models/garage.dart';

void main() {
  var car = Car(make: 'Fiat');

  test('a null nested model serializes as null', () {
    expect(GarageSerializer.toMap(Garage(main: car)), {
      'main': {'make': 'Fiat'},
      'spare': null,
    });
  });

  test('a nested model serializes as its map', () {
    var garage = Garage(main: car, spare: Car(make: 'Seat'));
    expect(GarageSerializer.toMap(garage)['spare'], {'make': 'Seat'});
  });

  test('a non-nullable nested model is read back', () {
    var garage = GarageSerializer.fromMap({
      'main': {'make': 'Fiat'},
    });
    expect(garage.main, car);
    expect(garage.spare, isNull);
  });

  test('a missing non-nullable nested model throws', () {
    expect(() => GarageSerializer.fromMap({}), throwsA(isA<TypeError>()));
  });

  test('round trip', () {
    var garage = Garage(main: car, spare: Car(make: 'Seat'));
    expect(GarageSerializer.fromMap(GarageSerializer.toMap(garage)), garage);
  });
}
