import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';
import 'models/tree.dart';

void hasManyTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  Tree? appleTree;
  late int treeId;
  close ??= (_) => null;

  setUp(() async {
    var query = TreeQuery()..values.rings = 10;

    executor = await createExecutor();
    appleTree = (await query.insert(executor)).value;
    treeId = int.parse(appleTree!.id!);
  });

  tearDown(() => close!(executor));

  test('list is empty if there is nothing', () {
    expect(appleTree!.rings, 10);
    expect(appleTree!.fruits, isEmpty);
  });

  group('mutations', () {
    Fruit? apple, banana;

    void verify(Tree tree) {
      //print(tree.fruits!.map(FruitSerializer.toMap).toList());
      expect(tree.fruits, hasLength(2));
      expect(tree.fruits[0].commonName, apple!.commonName);
      expect(tree.fruits[1].commonName, banana!.commonName);
    }

    setUp(() async {
      var appleQuery = FruitQuery()
        ..values.treeId = treeId
        ..values.commonName = 'Apple';

      var bananaQuery = FruitQuery()
        ..values.treeId = treeId
        ..values.commonName = 'Banana';
      var appleOpt = await appleQuery.insert(executor);
      var bananaOpt = await bananaQuery.insert(executor);
      appleOpt.ifPresent((a) {
        apple = a;
      });
      bananaOpt.ifPresent((a) {
        banana = a;
      });
    });

    test('can fetch any children', () async {
      var query = TreeQuery()..where!.id.equals(treeId);
      var treeOpt = await (query.getOne(executor));
      expect(treeOpt.isPresent, true);
      treeOpt.ifPresent((tree) {
        verify(tree);
      });
    });

    test('sets on update', () async {
      var tq = TreeQuery()
        ..where!.id.equals(treeId)
        ..values.rings = 24;
      var treeOpt = await (tq.updateOne(executor));
      expect(treeOpt.isPresent, true);
      treeOpt.ifPresent((tree) {
        verify(tree);
        expect(tree.rings, 24);
      });
    });

    test('sets on delete', () async {
      var tq = TreeQuery()..where!.id.equals(treeId);
      var treeOpt = await (tq.deleteOne(executor));
      expect(treeOpt.isPresent, true);
      treeOpt.ifPresent((tree) {
        verify(tree);
      });
    });

    test('returns empty on false subquery', () async {
      var tq = TreeQuery()
        ..where!.id.equals(treeId)
        ..fruits.where!.commonName.equals('Kiwi');
      var treeOpt = await (tq.getOne(executor));
      expect(treeOpt.isPresent, true);
      treeOpt.ifPresent((tree) {
        expect(tree.fruits, isEmpty);
      });
    });
  });
}
