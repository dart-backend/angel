import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
import 'package:angel3_orm_service/angel3_orm_service.dart';
import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'pokemon.dart';

void main() {
  late Logger logger;
  late PostgreSqlExecutor executor;
  late Service<int?, Pokemon> pokemonService;

  setUp(() async {
    var conn = await Connection.open(
      Endpoint(
        host: Platform.environment['POSTGRES_HOSTNAME'] ?? 'localhost',
        port: 5432,
        database: Platform.environment['POSTGRES_DB'] ?? 'postgres',
        username: Platform.environment['POSTGRES_USERNAME'] ?? 'postgres',
        password: Platform.environment['POSTGRES_PASSWORD'] ?? 'postgres',
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );

    hierarchicalLoggingEnabled = true;
    logger = Logger.detached('orm_service');
    logger.level = Level.ALL;
    if (Platform.environment['log'] == '1') logger.onRecord.listen(print);
    executor = PostgreSqlExecutor(conn, logger: logger);

    await conn.execute('''
    CREATE TEMPORARY TABLE pokemons (
      id serial,
      species varchar,
      name varchar,
      level integer,
      type1 integer,
      type2 integer,
      created_at timestamp,
      updated_at timestamp
    );
    ''');

    pokemonService = OrmService(executor, () => PokemonQuery());
  });

  tearDown(() async {
    await executor.close();
    pokemonService.close();
    logger.clearListeners();
  });

  test('create', () async {
    var blaziken = await pokemonService.create(
      Pokemon(
        species: 'Blaziken',
        level: 100,
        type1: PokemonType.fire,
        type2: PokemonType.fighting,
      ),
    );
    print(blaziken);
    expect(blaziken.id, isNotNull);
    expect(blaziken.species, 'Blaziken');
    expect(blaziken.level, 100);
    expect(blaziken.type1, PokemonType.fire);
    expect(blaziken.type2, PokemonType.fighting);
  });

  group('after create', () {
    late Pokemon giratina;
    late Pokemon pikachu;

    setUp(() async {
      giratina = await pokemonService.create(
        Pokemon(
          species: 'Giratina',
          name: 'My First Legendary',
          level: 54,
          type1: PokemonType.ghost,
          type2: PokemonType.dragon,
        ),
      );
      pikachu = await pokemonService.create(
        Pokemon(species: 'Pikachu', level: 100, type1: PokemonType.electric),
      );
    });

    group('a client query parameter', () {
      Future<List<Pokemon>> clientIndex(Map<String, dynamic> query) =>
          pokemonService.index({'provider': Providers.rest, 'query': query});

      Matcher badRequest = throwsA(
        isA<AngelHttpException>().having(
          (e) => e.statusCode,
          'statusCode',
          400,
        ),
      );

      test('is converted to the type of an int column', () async {
        expect(await clientIndex({'level': '100'}), [pikachu]);
      });

      test('that is not a number is a 400 for an int column', () async {
        expect(() => clientIndex({'level': 'high'}), badRequest);
      });

      test('for an enum column is a 400', () async {
        expect(() => clientIndex({'type1': 'electric'}), badRequest);
      });

      test('naming no column is a 400', () async {
        expect(() => clientIndex({'nickname': 'x'}), badRequest);
      });

      test(
        'naming no column from the server is still an ArgumentError',
        () async {
          expect(
            () => pokemonService.index({
              'query': {'nickname': 'x'},
            }),
            throwsArgumentError,
          );
        },
      );
    });

    group('update', () {
      test("keeps the values a query callback sets", () async {
        await pokemonService.update(
          int.parse(pikachu.id!),
          pikachu.copyWith(level: 5),
          {'query': (PokemonQuery q) => q.values.name = 'Set by a callback'},
        );
        var updated = await pokemonService.read(int.parse(pikachu.id!));
        expect(updated.level, 5);
        expect(updated.name, 'Set by a callback');
      });

      test('changes one record, even if the query matches more', () async {
        await pokemonService.update(
          int.parse(pikachu.id!),
          pikachu.copyWith(level: 7),
          {
            'query': (PokemonQuery q) =>
                q.orWhere((w) => w.species.equals('Giratina')),
          },
        );
        var all = await pokemonService.index();
        expect(all.where((p) => p.level == 7), hasLength(1));
      });
    });

    group('modify', () {
      Future<Pokemon> stored(Pokemon p) async =>
          (await pokemonService.read(int.parse(p.id!)));

      test(
        'called on the server, changes only the fields that are not null',
        () async {
          await pokemonService.modify(
            int.parse(pikachu.id!),
            Pokemon(species: null, level: null, type1: null, name: 'Sparky'),
          );
          var updated = await stored(pikachu);
          expect(updated.name, 'Sparky');
          expect(updated.species, 'Pikachu');
          expect(updated.level, 100);
          expect(updated.type1, PokemonType.electric);
        },
      );

      test('for a PATCH, changes only the fields in its body', () async {
        var app = Angel();
        // A readData that fills in the fields a model requires, as an app's
        // might: they are not in the body, so they must not be stored.
        app.use(
          '/api/pokemon',
          OrmService<int?, Pokemon, PokemonQuery>(
            executor,
            () => PokemonQuery(),
            readData: (req, res) => PokemonSerializer.fromMap({
              'species': 'Placeholder',
              'level': 1,
              'type1': 0,
              ...req.bodyAsMap,
            }),
          ),
        );
        var rq =
            MockHttpRequest('PATCH', Uri.parse('/api/pokemon/${pikachu.id}'))
              ..headers.contentType = ContentType.json
              ..write(json.encode({'name': 'Sparky', 'type2': null}));
        await rq.close();
        await AngelHttp(app).handleRequest(rq);
        expect(rq.response.statusCode, 200);

        var updated = await stored(pikachu);
        expect(updated.name, 'Sparky');
        expect(updated.species, 'Pikachu');
        expect(updated.level, 100);
        expect(updated.type2, isNull);
      });

      test('with nothing to change returns the record', () async {
        var same = await pokemonService.modify(
          int.parse(pikachu.id!),
          Pokemon(species: null, level: null, type1: null),
        );
        expect(same.species, 'Pikachu');
      });
    });

    group('index', () {
      test('default', () async {
        expect(await pokemonService.index(), contains(giratina));
        expect(await pokemonService.index(), contains(pikachu));
      });

      test('with callback', () async {
        var result = await pokemonService.index({
          'query': (PokemonQuery query) async {
            query.where!.level.equals(pikachu.level!);
          },
        });

        expect(result, [pikachu]);
      });

      test('search params', () async {
        Future<List<Pokemon>> searchByType1(PokemonType type1) async {
          var query = {PokemonFields.type1: type1};
          var params = {'query': query};
          return await pokemonService.index(params);
        }

        expect(await searchByType1(PokemonType.ghost), [giratina]);
        expect(await searchByType1(PokemonType.electric), [pikachu]);
        expect(await searchByType1(PokemonType.grass), []);
      });

      group(r'$sort', () {
        test('by name', () async {
          expect(
            await pokemonService.index({
              'query': {r'$sort': 'level'},
            }),
            [giratina, pikachu],
          );
        });

        test('map number', () async {
          expect(
            await pokemonService.index({
              'query': {
                r'$sort': {'type1': -1},
              },
            }),
            [giratina, pikachu],
          );
          expect(
            await pokemonService.index({
              'query': {
                r'$sort': {'type1': 100},
              },
            }),
            [pikachu, giratina],
          );
        });

        test('map string', () async {
          expect(
            await pokemonService.index({
              'query': {
                r'$sort': {'type1': '-1'},
              },
            }),
            [giratina, pikachu],
          );
          expect(
            await pokemonService.index({
              'query': {
                r'$sort': {'type1': 'foo'},
              },
            }),
            [pikachu, giratina],
          );
        });

        group('only by a column, so a client cannot inject SQL', () {
          const injection =
              "(CASE WHEN (SELECT 1)=1 THEN id ELSE name END); DROP TABLE pokemons";
          Matcher badRequest = throwsA(
            isA<AngelHttpException>().having(
              (e) => e.statusCode,
              'statusCode',
              400,
            ),
          );

          for (var (form, sort) in [
            ('string', injection),
            ('map', {injection: 1}),
          ]) {
            test('given as a $form', () async {
              expect(
                () => pokemonService.index({
                  'provider': Providers.rest,
                  'query': {r'$sort': sort},
                }),
                badRequest,
              );
              // The table is still there, with both pokemons.
              expect(await pokemonService.index(), hasLength(2));
            });
          }
        });
      });
    });

    group('findOne', () {
      test('default', () async {
        expect(
          await pokemonService.findOne({
            'query': {PokemonFields.name: giratina.name},
          }),
          giratina,
        );
        expect(
          await pokemonService.findOne({
            'query': {PokemonFields.level: pikachu.level},
          }),
          pikachu,
        );
        expect(
          () => pokemonService.findOne({
            'query': {PokemonFields.level: pikachu.level! * 3},
          }),
          throwsA(TypeMatcher<AngelHttpException>()),
        );
      });

      test('nonexistent throws 404', () {
        expect(
          () => pokemonService.findOne({
            'query': {PokemonFields.type1: PokemonType.poison},
          }),
          throwsA(TypeMatcher<AngelHttpException>()),
        );
      });
    });

    group('read', () {
      test('default', () async {
        expect(await pokemonService.read(pikachu.idAsInt), pikachu);
        expect(await pokemonService.read(giratina.idAsInt), giratina);
      });

      test('nonexistent throws 404', () {
        expect(
          () => pokemonService.read(999),
          throwsA(TypeMatcher<AngelHttpException>()),
        );
      });
    });

    group('readMany', () {
      test('returns the records with the ids', () async {
        // In no particular order: the query has no ORDER BY.
        expect(
          await pokemonService.readMany([giratina.idAsInt, pikachu.idAsInt]),
          unorderedEquals([giratina, pikachu]),
        );
        expect(await pokemonService.readMany([giratina.idAsInt]), [giratina]);
        expect(await pokemonService.readMany([pikachu.idAsInt]), [pikachu]);
      });

      test('leaves out null ids and ids with no record', () async {
        expect(await pokemonService.readMany([null, pikachu.idAsInt, 999]), [
          pikachu,
        ]);
        expect(await pokemonService.readMany([null]), isEmpty);
      });

      test('needs at least one id', () {
        expect(() => pokemonService.readMany([]), throwsArgumentError);
      });
    });

    group('update', () {
      test('default', () async {
        expect(
          await pokemonService.update(
            giratina.idAsInt,
            giratina.copyWith(name: 'Hello'),
          ),
          giratina.copyWith(name: 'Hello'),
        );
      });

      test('nonexistent throws 404', () {
        expect(
          () => pokemonService.update(999, giratina.copyWith(name: 'Hello')),
          throwsA(TypeMatcher<AngelHttpException>()),
        );
      });
    });

    group('remove', () {
      Matcher httpError(int statusCode) => throwsA(
        isA<AngelHttpException>().having(
          (e) => e.statusCode,
          'statusCode',
          statusCode,
        ),
      );

      /// A service that lets clients remove all records.
      OrmService<int?, Pokemon, PokemonQuery> removeAllService() =>
          OrmService(executor, () => PokemonQuery(), allowRemoveAll: true);

      test('removes and returns the record with the id', () async {
        expect(await pokemonService.remove(pikachu.idAsInt), pikachu);
        expect(await pokemonService.index(), [giratina]);
        expect(() => pokemonService.read(pikachu.idAsInt), httpError(404));
      });

      test('a nonexistent id is a 404, and removes nothing', () async {
        expect(() => pokemonService.remove(999), httpError(404));
        expect(await pokemonService.index(), hasLength(2));
      });

      test('a client cannot remove all, unless allowed', () async {
        expect(
          () => pokemonService.remove(null, {'provider': Providers.rest}),
          httpError(403),
        );
        expect(await pokemonService.index(), hasLength(2));
      });

      test('removes all, when allowed', () async {
        await removeAllService().remove(null, {'provider': Providers.rest});
        expect(await pokemonService.index(), isEmpty);
      });

      test('with no id, removes only the records the query matches', () async {
        await removeAllService().remove(null, {
          'provider': Providers.rest,
          'query': {'species': 'Pikachu'},
        });
        expect(await pokemonService.index(), [giratina]);
      });
    });
  });
}
