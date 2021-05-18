import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';
import 'models/custom_expr.dart';

customExprTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  Numbers? numbersModel;

  close ??= (_) => null;

  setUp(() async {
    executor = await createExecutor();

    var now = DateTime.now();
    var nQuery = NumbersQuery();
    nQuery.values
      ..createdAt = now
      ..updatedAt = now;
    var numbersModelOpt = await nQuery.insert(executor);
    numbersModelOpt.ifPresent((v) {
      numbersModel = v;
    });
  });

  tearDown(() => close!(executor));

  test('fetches correct result', () async {
    expect(numbersModel?.two, 2);
  });

  test('in relation', () async {
    var abcQuery = AlphabetQuery();
    abcQuery.values
      ..value = 'abc'
      ..numbersId = numbersModel!.idAsInt
      ..createdAt = numbersModel!.createdAt
      ..updatedAt = numbersModel!.updatedAt;
    var abcOpt = await (abcQuery.insert(executor));
    expect(abcOpt.isPresent, true);
    abcOpt.ifPresent((abc) {
      expect(abc.numbers, numbersModel);
      expect(abc.numbers?.two, 2);
      expect(abc.value, 'abc');
    });
  });
}
