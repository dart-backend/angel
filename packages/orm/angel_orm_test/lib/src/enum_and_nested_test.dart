import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';
import 'models/has_car.dart';

void enumAndNestedTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  close ??= (_) => null;

  setUp(() async {
    executor = await createExecutor();
  });

  test('insert', () async {
    var query = HasCarQuery()..values.type = CarType.sedan;
    var resultOpt = await (query.insert(executor));
    expect(resultOpt.isPresent, true);
    resultOpt.ifPresent((result) {
      expect(result.type, CarType.sedan);
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
