import 'dart:async';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_orm_service/angel3_orm_service.dart';
import 'package:test/test.dart';

import 'pokemon.dart';

/// An executor that is never called: the query parameters of a service are
/// those of its query, not of its database.
class _NoExecutor implements QueryExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No database is used: ${invocation.memberName}');
}

void main() {
  test(r'$sort, and the columns a query parameter can match', () {
    var service = OrmService<int?, Pokemon, PokemonQuery>(
      _NoExecutor(),
      () => PokemonQuery(),
    );
    var parameters = service.indexQueryParameters;
    expect(parameters[r'$sort'], {
      'type': 'string',
      'enum': PokemonQuery().fields,
      'description': 'The column to sort by',
    });
    expect(parameters..remove(r'$sort'), {
      'id': {'type': 'integer'},
      'created_at': {'type': 'string', 'format': 'date-time'},
      'updated_at': {'type': 'string', 'format': 'date-time'},
      'species': {'type': 'string'},
      'name': {'type': 'string'},
      'level': {'type': 'integer'},
      // Not type1 and type2, of enums, which a query parameter cannot match.
    });
  });

  test('none if allowQuery is false', () {
    var service = OrmService<int?, Pokemon, PokemonQuery>(
      _NoExecutor(),
      () => PokemonQuery(),
      allowQuery: false,
    );
    expect(service.indexQueryParameters, isEmpty);
  });

  test(r'only $sort of a query created asynchronously', () {
    var service = OrmService<int?, Pokemon, PokemonQuery>(
      _NoExecutor(),
      () => Future.value(PokemonQuery()),
    );
    expect(service.indexQueryParameters.keys, [r'$sort']);
  });
}
