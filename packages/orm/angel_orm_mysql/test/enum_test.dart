import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'models/has_car.dart';

void main() async {
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });

  /// See https://github.com/dart-backend/angel/pull/98
  test('enum field with custom deserializer should be parsed consistently', () {
    final query = HasCarQuery();
    final hasCar = query.parseRow([null, null, null, null, 'R']).value;
    expect(hasCar.color, equals(Color.red));
  });
}
