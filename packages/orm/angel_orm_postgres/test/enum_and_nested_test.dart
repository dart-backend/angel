import 'package:angel3_orm/angel3_orm.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/has_car.dart';

void main() {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog);
  late QueryExecutor executor;

  var executorFunc = pg(['has_car']);

  setUp(() async {
    executor = await executorFunc();
  });

  tearDown(() async {
    await closePg(executor);
  });

  test('insert', () async {
    var query = HasCarQuery()
      ..values.type = CarType.sedan
      ..values.color = Color.red;
    var resultOpt = await (query.insert(executor));
    expect(resultOpt.isPresent, true);
    resultOpt.ifPresent((result) {
      expect(result.type, CarType.sedan);
      expect(result.color, Color.red);
    });
  });

  group('query', () {
    HasCar? initialValue;

    setUp(() async {
      var query = HasCarQuery();
      query.values.type = CarType.sedan;
      initialValue = (await query.insert(executor)).value;
    });

    test('query by enum', () async {
      // Check for mismatched type
      var query = HasCarQuery()..where!.type.equals(CarType.atv);
      var result = await query.get(executor);
      expect(result, isEmpty);

      query = HasCarQuery()..where!.type.equals(initialValue!.type);
      var oneResult = await query.getOne(executor);
      expect(oneResult.value, initialValue);
    });
  });
}
