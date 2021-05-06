import 'dart:async';
import 'package:angel_orm/angel_orm.dart';
import 'package:test/test.dart';
import 'models/has_map.dart';

hasMapTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  close ??= (_) => null;

  setUp(() async {
    executor = await createExecutor();
  });

  tearDown(() => close!(executor));

  test('insert', () async {
    var query = HasMapQuery();
    query.values
      ..value = {'foo': 'bar'}
      ..list = ['1', 2, 3.0];
    var modelOpt = await (query.insert(executor));
    expect(modelOpt.isPresent, true);
    modelOpt.ifPresent((model) {
      print(model.toJson());
      expect(model, HasMap(value: {'foo': 'bar'}, list: ['1', 2, 3.0]));
    });
  });

  test('update', () async {
    var query = HasMapQuery();
    query.values
      ..value = {'foo': 'bar'}
      ..list = ['1', 2, 3.0];
    var modelOpt = await (query.insert(executor));
    expect(modelOpt.isPresent, true);
    if (modelOpt.isPresent) {
      var model = modelOpt.value;
      print(model.toJson());
      query = HasMapQuery()..values.copyFrom(model);
      var result = await query.updateOne(executor);
      expect(result.isPresent, true);
      result.ifPresent((m) {
        expect(m, model);
      });
    }
  });

  group('query', () {
    HasMap? initialValue;

    setUp(() async {
      var query = HasMapQuery();
      query.values
        ..value = {'foo': 'bar'}
        ..list = ['1', 2, 3.0];
      initialValue = (await query.insert(executor)).value;
    });

    test('get all', () async {
      var query = HasMapQuery();
      expect(await query.get(executor), [initialValue]);
    });

    test('map equals', () async {
      var query = HasMapQuery();
      query.where!.value.equals({'foo': 'bar'});
      expect(await query.get(executor), [initialValue]);

      query = HasMapQuery();
      query.where!.value.equals({'foo': 'baz'});
      expect(await query.get(executor), isEmpty);
    });

    test('list equals', () async {
      var query = HasMapQuery();
      query.where?.list.equals(['1', 2, 3.0]);
      var result = await query.get(executor);
      expect(result, [initialValue]);

      query = HasMapQuery();
      query.where?.list.equals(['10', 20, 30.0]);
      var result2 = await query.get(executor);
      expect(result2, isEmpty);
    });

    test('property equals', () async {
      var query = HasMapQuery()..where!.value['foo'].asString?.equals('bar');
      expect(await query.get(executor), [initialValue]);

      query = HasMapQuery()..where!.value['foo'].asString!.equals('baz');
      expect(await query.get(executor), []);
    });

    test('index equals', () async {
      var query = HasMapQuery()..where!.list[0].asString!.equals('1');
      expect(await query.get(executor), [initialValue]);

      query = HasMapQuery()..where!.list[1].asInt!.equals(3);
      expect(await query.get(executor), []);
    });
  });
}
