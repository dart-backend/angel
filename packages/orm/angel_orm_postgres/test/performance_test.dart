// ignore: library_annotations
@Skip('Only used for debugging issues')

import 'dart:async';
import 'dart:math';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

import 'models/fortune.dart';
import 'models/world.dart';

void performanceTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  QueryExecutor? executor;

  //int _sampleSize = 1000;

  int concurrency = 200;

  // Generate a random number between 1 and 10000
  int genRandomId() {
    var rand = Random();
    return rand.nextInt(10000) + 1;
  }

  setUp(() async {
    print("Run setup");
    executor = await createExecutor();

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

  tearDown(() => close!(executor!));

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
  });

  test('select one concurrency', () async {
    var stopwatch = Stopwatch();
    stopwatch.start();

    var id = genRandomId();
    var query = WorldQuery()..where?.id.equals(id);
    var result = await query.get(executor!);

    print("Time elapsed: ${stopwatch.elapsed.inMilliseconds}");
    stopwatch.stop();

    expect(result, isNotNull);
  });

  test('update concurrency', () async {
    var stopwatch = Stopwatch();
    stopwatch.start();

    var id = genRandomId();
    var query = WorldQuery()..where?.id.equals(id);
    var result = await query.get(executor!);

    print("Time elapsed: ${stopwatch.elapsed.inMilliseconds}");
    stopwatch.stop();

    expect(result, isNotNull);
  });
}
