import 'package:angel3_orm_test/src/models/has_car.dart';
import 'package:test/test.dart';

void main() async {
  /// See https://github.com/dart-backend/angel/pull/98
  test('enum field with custom deserializer should be parsed consistently', () {
    final query = HasCarQuery();
    final hasCar = query.parseRow([null, null, null, 'R', null]).value;
    expect(hasCar.color, equals(Color.red));
  });
}
