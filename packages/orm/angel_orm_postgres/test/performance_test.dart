// ignore: library_annotations
//@Skip('Only used for debugging issues')

import 'dart:async';
import 'dart:math';

import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/fortune.dart';
import 'models/world.dart';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.time}: ${record.message}');
  });

  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  //int _sampleSize = 1000;
  int concurrency = 200;

  // Generate a random number between 1 and 10000
  int genRandomId() {
    var rand = Random();
    return rand.nextInt(10000) + 1;
  }

  List<int> generateIds(int maxCount) {
    var result = <int>[];

    while (result.length < maxCount) {
      var id = genRandomId();
      if (!result.contains(id)) {
        result.add(id);
      }
    }

    return result;
  }

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, []);

    /*
    for (var i = 0; i < _sampleSize; i++) {
      var query = WorldQuery();
      query.values.randomNumber = _genRandomId();
      var world = (await query.insert(executor!)).value;
    }

    for (var i = 0; i < _sampleSize; i++) {
      var query = FortuneQuery();
      query.values.message = "message ${_genRandomId()}";
      var fortune = (await query.insert(executor!)).value;
    }
    */
  });

  tearDown(() async {
    await dropTables(runner);
    if (conn.isOpen) {
      await conn.close();
    }
  });

  test('select all concurrency', () async {
    var stopwatch = Stopwatch();
    stopwatch.start();

    // Fire and forget
    for (var i = 0; i < concurrency; i++) {
      FortuneQuery().get(executor!);
    }

    print("Loop time elapsed: ${stopwatch.elapsed.inMilliseconds}");

    var result = await FortuneQuery().get(executor!);

    print("Final Time elapsed: ${stopwatch.elapsed.inMilliseconds}");
    stopwatch.stop();

    expect(result, isNotNull);
  }, skip: "Not relevant");

  test('select one concurrency', () async {
    var stopwatch = Stopwatch();
    stopwatch.start();

    var id = genRandomId();
    var query = WorldQuery()..where?.id.equals(id);
    var result = await query.get(executor!);

    print("Time elapsed: ${stopwatch.elapsed.inMilliseconds}");
    stopwatch.stop();

    expect(result, isNotNull);
  }, skip: "Not relevant");

  test('update concurrency', () async {
    var stopwatch = Stopwatch();
    stopwatch.start();

    var id = genRandomId();
    var query = WorldQuery()..where?.id.equals(id);
    var result = await query.get(executor!);

    print("Time elapsed: ${stopwatch.elapsed.inMilliseconds}");
    stopwatch.stop();

    expect(result, isNotNull);
  }, skip: "Not relevant");

  test('update one', () async {
    var queryLimit = 2;
    var listOfIds = generateIds(queryLimit);

    var result = <World>[];
    for (var id in listOfIds) {
      print("=== Process $id ====");
      var query = WorldQuery();
      //query.where?.id.equals(id);
      //var optWorld = await query.getOne(executor);
      //print("getOne => $optWorld");

      query
        ..where?.id.equals(id)
        ..values.randomnumber = genRandomId();
      var updatedRec = await query.updateOne(executor);
      print("Update: $updatedRec");
      result.add(updatedRec.value);
    }
  });
}
