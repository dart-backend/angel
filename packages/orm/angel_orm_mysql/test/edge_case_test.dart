import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:test/test.dart';
import 'common.dart';
import 'models/book.dart';
import 'models/unorthodox.dart';

void main() {
  late MySQLConnection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  setUp(() async {
    conn = await openMySqlConnection();
    executor = await createExecutor(conn);
    runner = await createTables(conn, [
      UnorthodoxMigration(),
      WeirdJoinMigration(),
      SongMigration(),
      NumbaMigration(),
      AuthorMigration(),
      FooMigration(),
      FooPivotMigration(),
      BookMigration()
    ]);
  });

  tearDown(() async {
    await dropTables(runner);
  });

  test('can create object with no id', () async {
    var query = UnorthodoxQuery()..values.name = 'World';
    var modelOpt = await query.insert(executor);
    expect(modelOpt.isPresent, true);
    modelOpt.ifPresent((model) {
      expect(model, Unorthodox(name: 'World'));
    });
  }, skip: "Primary key cannot be null");

  group('relations on non-model', () {
    Unorthodox? unorthodox;

    setUp(() async {
      //if (unorthodox == null) {
      var query = UnorthodoxQuery()..values.name = 'Hey';

      var unorthodoxOpt = await query.insert(executor);
      unorthodoxOpt.ifPresent((value) {
        unorthodox = value;
      });
      //}
    });

    test('belongs to', () async {
      var query = WeirdJoinQuery()..values.joinName = unorthodox!.name;
      var modelOpt = await query.insert(executor);
      expect(modelOpt.isPresent, true);
      modelOpt.ifPresent((model) {
        //print(model.toJson());
        expect(model.id, isNotNull); // Postgres should set this.
        expect(model.unorthodox, unorthodox);
      });
    });

    group('layered', () {
      WeirdJoin? weirdJoin;
      Song? girlBlue;

      setUp(() async {
        var wjQuery = WeirdJoinQuery()..values.joinName = unorthodox!.name;

        var weirdJoinOpt = await wjQuery.insert(executor);
        //weirdJoin = (await wjQuery.insert(executor)).value;
        weirdJoinOpt.ifPresent((value1) async {
          weirdJoin = value1;
          var gbQuery = SongQuery()
            ..values.weirdJoinId = value1.id
            ..values.title = 'Girl Blue';

          var girlBlueOpt = await gbQuery.insert(executor);
          girlBlueOpt.ifPresent((value2) {
            girlBlue = value2;
          });
        });
      });

      test('has one', () async {
        var query = WeirdJoinQuery()..where!.id.equals(weirdJoin!.id!);
        var wjOpt = await query.getOne(executor);
        expect(wjOpt.isPresent, true);
        wjOpt.ifPresent((wj) {
          //print(wj.toJson());
          expect(wj.song, girlBlue);
        });
      });

      test('has many', () async {
        var numbas = <Numba>[];

        for (var i = 0; i < 15; i++) {
          var query = NumbaQuery()
            ..values.parent = weirdJoin!.id
            ..values.i = i;
          var modelObj = await query.insert(executor);
          expect(modelObj.isPresent, true);
          modelObj.ifPresent((model) {
            numbas.add(model);
          });
        }

        var query = WeirdJoinQuery()..where!.id.equals(weirdJoin!.id!);
        var wjObj = await query.getOne(executor);
        expect(wjObj.isPresent, true);
        wjObj.ifPresent((wj) {
          //print(wj.toJson());
          expect(wj.numbas, numbas);
        });
      });

      test('many to many', () async {
        var fooQuery = FooQuery()..values.bar = 'baz';
        var fooBar =
            await fooQuery.insert(executor).then((foo) => foo.value.bar);
        var pivotQuery = FooPivotQuery()
          ..values.weirdJoinId = weirdJoin!.id
          ..values.fooBar = fooBar;
        await pivotQuery.insert(executor);
        fooQuery = FooQuery()..where!.bar.equals('baz');

        var fooOpt = await fooQuery.getOne(executor);
        expect(fooOpt.isPresent, true);
        fooOpt.ifPresent((foo) {
          //print(foo.toJson());
          //print(weirdJoin!.toJson());
          expect(foo.weirdJoins[0].id, weirdJoin!.id);
        });
      }, skip: "Primary key cannot be null");
    });
  });
}
