import 'package:test/test.dart';

import 'models/has_car.dart';

void main() async {
  /// See https://github.com/dart-backend/angel/pull/98
  test('enum field with custom deserializer should be parsed consistently', () {
    final query = HasCarQuery();
    final hasCar = query.parseRow([null, null, null, 'R', null]).value;
    expect(hasCar.color, equals(Color.red));
  });
}
