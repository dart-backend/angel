import 'dart:async';

import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
import 'package:optional/optional.dart';
part 'main.g.dart';

void main() async {
  var query = EmployeeQuery()
    ..where!.firstName.equals('Rich')
    ..where!.lastName.equals('Person')
    ..orWhere((w) => w.salary.greaterThanOrEqualTo(75000))
    ..join('companies', 'company_id', 'id');

  var richPerson = await query.getOne(const _FakeExecutor());
  if (richPerson.isPresent) {
    print(richPerson.value.toJson());
  }
}

class _FakeExecutor extends QueryExecutor {
  const _FakeExecutor();

  @override
  Future<List<List>> query(
    String tableName,
    String? query,
    Map<String, dynamic> substitutionValues, {
    String returningQuery = '',
    String resultQuery = '',
    List<String> returningFields = const [],
  }) async {
    var now = DateTime.now();
    print(
      '_FakeExecutor received query: $query and values: $substitutionValues',
    );
    // A row of the query's fields, in their order.
    return [
      [1, now, now, 'Rich', 'Person', 'rich-1', 100000.0],
    ];
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) {
    throw UnsupportedError('Transactions are not supported.');
  }

  @override
  Dialect get dialect => const PostgreSQLDialect();
}

@orm
@serializable
abstract class EmployeeEntity extends Model {
  String? get firstName;

  String? get lastName;

  @Column(indexType: IndexType.unique)
  abstract String? uniqueId;

  double? get salary;
}
