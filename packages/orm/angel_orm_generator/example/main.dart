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

  var richPerson = await (query.getOne(_FakeExecutor()) as FutureOr<Employee>);
  print(richPerson.toJson());
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
    return [
      [1, 'Rich', 'Person', 100000.0, now, now],
    ];
  }

  @override
  Future<T> transaction<T>(FutureOr<T> Function(QueryExecutor) f) {
    throw UnsupportedError('Transactions are not supported.');
  }

  @override
  // TODO: implement dialect
  Dialect get dialect => PostgreSQLDialect();
}

@orm
@serializable
abstract class _Employee extends Model {
  String? get firstName;

  String? get lastName;

  @Column(indexType: IndexType.unique)
  String? uniqueId;

  double? get salary;
}
