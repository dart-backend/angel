import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/leg.dart';

void main() {
  Logger.root.level = Level.INFO; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });

  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;
  Leg? originalLeg;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [LegMigration(), FootMigration()]);
    var query = LegQuery()..values.name = 'Left';
    originalLeg = (await query.insert(executor)).value;
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) {
      await conn.close();
    }
  });

  test('sets to null if no child', () async {
    //print(LegQuery().compile({}));
    var query = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var legOpt = await (query.getOne(executor));
    expect(legOpt.isPresent, true);
    legOpt.ifPresent((leg) {
      //print(leg.toJson());
      expect(leg.name, originalLeg?.name);
      expect(leg.id, originalLeg?.id);
      expect(leg.foot, isNull);
    });
  }, skip: "Failed under concurrency tests");

  test('can fetch one foot', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 5.64;
    var legQuery = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var footOpt = await (footQuery.insert(executor));
    var legOpt = await (legQuery.getOne(executor));
    expect(footOpt.isPresent, true);
    expect(legOpt.isPresent, true);
    legOpt.ifPresent((leg) {
      expect(leg.name, originalLeg!.name);
      expect(leg.id, originalLeg!.id);
      footOpt.ifPresent((foot) {
        expect(leg.foot, isNotNull);
        expect(leg.foot!.id, foot.id);
        expect(leg.foot!.nToes, foot.nToes);
      });
    });
  });

  test('only fetches one foot even if there are multiple', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 24;
    var legQuery = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var footOpt = await (footQuery.insert(executor));
    var legOpt = await (legQuery.getOne(executor));
    expect(footOpt.isPresent, true);
    expect(legOpt.isPresent, true);
    legOpt.ifPresent((leg) {
      expect(leg.name, originalLeg!.name);
      expect(leg.id, originalLeg!.id);
      expect(leg.foot, isNotNull);
      footOpt.ifPresent((foot) {
        expect(leg.foot!.id, foot.id);
        expect(leg.foot!.nToes, foot.nToes);
      });
    });
  });

  test('sets foot on update', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 5.64;
    var legQuery = LegQuery()
      ..where!.id.equals(int.parse(originalLeg!.id!))
      ..values.copyFrom(originalLeg!.copyWith(name: 'Right'));
    var footOpt = await (footQuery.insert(executor));
    var legOpt = await (legQuery.updateOne(executor));
    expect(footOpt.isPresent, true);
    expect(legOpt.isPresent, true);
    legOpt.ifPresent((leg) {
      //print(leg.toJson());
      expect(leg.name, 'Right');
      expect(leg.foot, isNotNull);
      footOpt.ifPresent((foot) {
        expect(leg.foot!.id, foot.id);
        expect(leg.foot!.nToes, foot.nToes);
      });
    });
  });

  test('sets foot on delete', () async {
    var footQuery = FootQuery()
      ..values.legId = int.parse(originalLeg!.id!)
      ..values.nToes = 5.64;
    var legQuery = LegQuery()..where!.id.equals(int.parse(originalLeg!.id!));
    var footOpt = await (footQuery.insert(executor));
    var legOpt = await (legQuery.deleteOne(executor));
    expect(footOpt.isPresent, true);
    expect(legOpt.isPresent, true);
    legOpt.ifPresent((leg) {
      //print(leg.toJson());
      expect(leg.name, originalLeg?.name);
      expect(leg.foot, isNotNull);
      footOpt.ifPresent((foot) {
        expect(leg.foot!.id, foot.id);
        expect(leg.foot!.nToes, foot.nToes);
      });
    });
  });

  test('sets null on false subquery', () async {
    var legQuery = LegQuery()
      ..where!.id.equals(originalLeg!.idAsInt)
      ..foot.where!.legId.equals(originalLeg!.idAsInt + 1024);
    var legOpt = await (legQuery.getOne(executor));
    expect(legOpt.isPresent, true);
    legOpt.ifPresent((leg) {
      expect(leg.foot, isNull);
    });
  });
}
