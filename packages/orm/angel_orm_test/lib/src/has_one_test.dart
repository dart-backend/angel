import 'dart:async';
import 'package:angel_orm/angel_orm.dart';
import 'package:test/test.dart';
import 'models/leg.dart';

hasOneTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  Leg? originalLeg;
  close ??= (_) => null;

  setUp(() async {
    executor = await createExecutor();
    var query = LegQuery()..values.name = 'Left';
    originalLeg = (await query.insert(executor)).value;
  });

  tearDown(() => close!(executor));

  test('sets to null if no child', () async {
    print(LegQuery().compile(Set()));
    var query = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var leg = await (query.getOne(executor) as FutureOr<Leg>);
    print(leg.toJson());
    expect(leg.name, originalLeg!.name);
    expect(leg.id, originalLeg!.id);
    expect(leg.foot, isNull);
  });

  test('can fetch one foot', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 5.64;
    var legQuery = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var foot = await (footQuery.insert(executor) as FutureOr<Foot>);
    var leg = await (legQuery.getOne(executor) as FutureOr<Leg>);

    expect(leg.name, originalLeg!.name);
    expect(leg.id, originalLeg!.id);
    expect(leg.foot, isNotNull);
    expect(leg.foot!.id, foot.id);
    expect(leg.foot!.nToes, foot.nToes);
  });

  test('only fetches one foot even if there are multiple', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 24;
    var legQuery = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var foot = await (footQuery.insert(executor) as FutureOr<Foot>);
    var leg = await (legQuery.getOne(executor) as FutureOr<Leg>);
    expect(leg.name, originalLeg!.name);
    expect(leg.id, originalLeg!.id);
    expect(leg.foot, isNotNull);
    expect(leg.foot!.id, foot.id);
    expect(leg.foot!.nToes, foot.nToes);
  });

  test('sets foot on update', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 5.64;
    var legQuery = LegQuery()
      ..where!.id.equals(int.parse(originalLeg!.id!))
      ..values.copyFrom(originalLeg!.copyWith(name: 'Right'));
    var foot = await (footQuery.insert(executor) as FutureOr<Foot>);
    var leg = await (legQuery.updateOne(executor) as FutureOr<Leg>);
    print(leg.toJson());
    expect(leg.name, 'Right');
    expect(leg.foot, isNotNull);
    expect(leg.foot!.id, foot.id);
    expect(leg.foot!.nToes, foot.nToes);
  });

  test('sets foot on delete', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 5.64;
    var legQuery = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var foot = await (footQuery.insert(executor) as FutureOr<Foot>);
    var leg = await (legQuery.deleteOne(executor) as FutureOr<Leg>);
    print(leg.toJson());
    expect(leg.name, originalLeg!.name);
    expect(leg.foot, isNotNull);
    expect(leg.foot!.id, foot.id);
    expect(leg.foot!.nToes, foot.nToes);
  });

  test('sets null on false subquery', () async {
    var legQuery = LegQuery()
      ..where!.id.equals(originalLeg!.idAsInt!)
      ..foot!.where!.legId.equals(originalLeg!.idAsInt! + 1024);
    var leg = await (legQuery.getOne(executor) as FutureOr<Leg>);
    expect(leg.foot, isNull);
  });
}
