import 'dart:async';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';
import 'models/car.dart';

final DateTime y2k = DateTime(2000, 1, 1);

void standaloneTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  close ??= (_) => null;
  test('to where', () {
    var query = CarQuery();
    query.where
      ?..familyFriendly.isTrue
      ..recalledAt.lessThanOrEqualTo(y2k, includeTime: false);
    var whereClause = query.where?.compile(tableName: 'cars');
    //print('Where clause: $whereClause');
    expect(whereClause,
        'cars.family_friendly = TRUE AND cars.recalled_at <= \'2000-01-01\'');
  });

  test('parseRow', () {
    // 'id', 'created_at',  'updated_at', 'make', 'description', 'family_friendly', 'recalled_at'
    // var row = [0, 'Mazda', 'CX9', true, y2k, y2k, y2k];
    var row = [0, y2k, y2k, 'Mazda', 'CX9', true, y2k, 80000.00];
    //print(row);
    var carOpt = CarQuery().deserialize(row);
    expect(carOpt.isPresent, true);
    carOpt.ifPresent((car) {
      //print(car.toJson());
      expect(car.id, '0');
      expect(car.make, 'Mazda');
      expect(car.description, 'CX9');
      expect(car.familyFriendly, true);
      expect(
          y2k.toIso8601String(), startsWith(car.recalledAt!.toIso8601String()));
      expect(
          y2k.toIso8601String(), startsWith(car.createdAt!.toIso8601String()));
      expect(
          y2k.toIso8601String(), startsWith(car.updatedAt!.toIso8601String()));
      expect(car.price, 80000.00);
    });
  });

  group('queries', () {
    QueryExecutor? executor;

    setUp(() async {
      executor = await createExecutor();
    });

    tearDown(() => close!(executor!));

    group('selects', () {
      test('select all', () async {
        var cars = await CarQuery().get(executor!);
        expect(cars, []);
      });

      group('with data', () {
        Car? ferrari;

        setUp(() async {
          var query = CarQuery();
          query.values
            ..make = 'Ferrari東'
            ..createdAt = y2k
            ..updatedAt = y2k
            ..description = 'Vroom vroom!'
            //..price = 120000.00
            ..familyFriendly = false;
          ferrari = (await query.insert(executor!)).value;
        });

        test('where clause is applied', () async {
          var query = CarQuery()..where!.familyFriendly.isTrue;
          var cars = await query.get(executor!);
          expect(cars, isEmpty);

          var sportsCars = CarQuery()..where!.familyFriendly.isFalse;
          cars = await sportsCars.get(executor!);
          print(cars.map((c) => c.toJson()));

          var car = cars.first;
          expect(car.make, ferrari!.make);
          expect(car.description, ferrari!.description);
          expect(car.familyFriendly, ferrari!.familyFriendly);
          expect(car.recalledAt, isNull);
        });

        test('union', () async {
          var query1 = CarQuery()..where?.make.like('%Fer%');
          var query2 = CarQuery()..where?.familyFriendly.isTrue;
          var query3 = CarQuery()..where?.description.equals('Submarine');
          var union = query1.union(query2).unionAll(query3);
          //print(union.compile({}));
          var cars = await union.get(executor!);
          expect(cars, hasLength(1));
        });

        test('or clause', () async {
          var query = CarQuery()
            ..where!.make.like('Fer%')
            ..orWhere((where) => where
              ..familyFriendly.isTrue
              ..make.equals('Honda'));
          //print(query.compile({}));
          var cars = await query.get(executor!);
          expect(cars, hasLength(1));
        });

        test('limit obeyed', () async {
          var query = CarQuery()..limit(0);
          //print(query.compile({}));
          var cars = await query.get(executor!);
          expect(cars, isEmpty);
        });

        test('get one', () async {
          var id = int.parse(ferrari!.id!);
          var query = CarQuery()..where!.id.equals(id);
          var carOpt = await query.getOne(executor!);
          expect(carOpt.isPresent, true);
          carOpt.ifPresent((car) {
            expect(car, ferrari);
          });
        });

        test('delete one', () async {
          var id = int.parse(ferrari!.id!);
          var query = CarQuery()..where!.id.equals(id);
          var carOpt = await (query.deleteOne(executor!));
          expect(carOpt.isPresent, true);
          carOpt.ifPresent((car) {
            var car = carOpt.value;
            expect(car.toJson(), ferrari!.toJson());
          });

          var cars = await CarQuery().get(executor!);
          expect(cars, isEmpty);
        });

        test('delete stream', () async {
          var query = CarQuery()
            ..where!.make.equals('Ferrari東')
            ..orWhere((w) => w.familyFriendly.isTrue);
          //print(query.compile({}, preamble: 'DELETE FROM "cars"'));

          var cars = await query.delete(executor!);
          expect(cars, hasLength(1));
          expect(cars.first.toJson(), ferrari!.toJson());
        });

        test('update', () async {
          var query = CarQuery()
            ..where!.id.equals(int.parse(ferrari!.id!))
            ..values.make = 'Hyundai';
          var cars = await query.update(executor!);
          expect(cars, hasLength(1));
          expect(cars.first.make, 'Hyundai');
        });

        test('update car', () async {
          var cloned = ferrari!.copyWith(make: 'Angel');
          var query = CarQuery()..values.copyFrom(cloned);
          var carOpt = await (query.updateOne(executor!));
          expect(carOpt.isPresent, true);
          carOpt.ifPresent((car) {
            var car = carOpt.value;
            //print(car.toJson());
            expect(car.toJson(), cloned.toJson());
          });
        });
      });
    });

    test('insert', () async {
      var recalledAt = DateTime.now();
      var query = CarQuery();
      var now = DateTime.now();
      query.values
        ..make = 'Honda'
        ..description = 'Hello'
        ..familyFriendly = true
        ..recalledAt = recalledAt
        ..createdAt = now
        ..updatedAt = now;
      var carOpt = await (query.insert(executor!));
      expect(carOpt.isPresent, true);
      carOpt.ifPresent((car) {
        var car = carOpt.value;
        expect(car.id, isNotNull);
        expect(car.make, 'Honda');
        expect(car.description, 'Hello');
        expect(car.familyFriendly, isTrue);
        expect(
            dateYmdHms.format(car.recalledAt!), dateYmdHms.format(recalledAt));
        expect(car.createdAt, allOf(isNotNull, equals(car.updatedAt)));
      });
    });

    test('insert car', () async {
      var recalledAt = DateTime.now();
      var beetle = Car(
          make: 'Beetle',
          description: 'Herbie',
          familyFriendly: true,
          recalledAt: recalledAt);
      var query = CarQuery()..values.copyFrom(beetle);
      var carOpt = await (query.insert(executor!));
      expect(carOpt.isPresent, true);
      carOpt.ifPresent((car) {
        //print(car.toJson());
        expect(car.make, beetle.make);
        expect(car.description, beetle.description);
        expect(car.familyFriendly, beetle.familyFriendly);
        expect(dateYmdHms.format(car.recalledAt!),
            dateYmdHms.format(beetle.recalledAt!));
      });
    });
  });
}
