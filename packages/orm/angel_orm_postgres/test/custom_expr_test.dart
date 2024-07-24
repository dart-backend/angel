import 'package:angel3_orm/angel3_orm.dart';
import 'package:belatuk_pretty_logging/belatuk_pretty_logging.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/custom_expr.dart';

void main() {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog);
  late QueryExecutor executor;
  late Numbers numbersModel;
  var executorFunc = pg(['custom_expr']);

  setUp(() async {
    executor = await executorFunc();

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

  tearDown(() async {
    await closePg(executor);
  });

  test('fetches correct result', () async {
    expect(numbersModel.two, 2);
  });

  test('in relation', () async {
    var abcQuery = AlphabetQuery();
    abcQuery.values
      ..value = 'abc'
      ..numbersId = numbersModel.idAsInt
      ..createdAt = numbersModel.createdAt
      ..updatedAt = numbersModel.updatedAt;
    var abcOpt = await (abcQuery.insert(executor));
    expect(abcOpt.isPresent, true);
    abcOpt.ifPresent((abc) {
      expect(abc.numbers, numbersModel);
      expect(abc.numbers?.two, 2);
      expect(abc.value, 'abc');
    });
  });
}
