import 'package:angel3_migration_runner/angel3_migration_runner.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'common.dart';
import 'models/person.dart';
import 'models/person_order.dart';

void main() {
  late Connection conn;
  late QueryExecutor executor;
  late MigrationRunner runner;

  Person? originalPerson;
  PersonOrder? originalOrder1;
  PersonOrder? originalOrder2;

  setUp(() async {
    conn = await openPgConnection();
    executor = await createExecutor(conn);
    runner =
        await createTables(conn, [PersonMigration(), PersonOrderMigration()]);
    var query = PersonQuery()
      ..values.name = 'DebuggerX'
      ..values.age = 29;
    originalPerson = (await query.insert(executor)).value;

    var orderQuery = PersonOrderQuery()
      ..values.personId = originalPerson!.idAsInt
      ..values.name = 'Order1'
      ..values.price = 128
      ..values.deleted = false;

    originalOrder1 = (await orderQuery.insert(executor)).value;

    orderQuery = PersonOrderQuery()
      ..values.personId = originalPerson!.idAsInt
      ..values.name = 'Order2'
      ..values.price = 256
      ..values.deleted = true;

    originalOrder2 = (await orderQuery.insert(executor)).value;
  });

  tearDown(() async => await dropTables(runner));

  test('select person with last order info', () async {
    var orderQuery = PersonOrderQuery();
    var query = PersonWithLastOrderQuery();
    query.join(
        orderQuery.tableName, PersonFields.id, PersonOrderFields.personId,
        alias: 'po');
    query.where?.name.equals(originalPerson!.name!);
    query.orderBy('po.id', descending: true);
    var personWithOrderInfo = await query.getOne(executor);
    expect(personWithOrderInfo.value.lastOrderName, originalOrder2?.name);
  });

  test('select person with last valid order info', () async {
    var orderQuery = PersonOrderQuery();
    var query = PersonWithLastOrderQuery();
    query.join(
        orderQuery.tableName, PersonFields.id, PersonOrderFields.personId,
        alias: 'po');
    query.where?.name.equals(originalPerson!.name!);
    query.orderBy('po.id', descending: true);
    query.where?.raw('po.deleted = false');
    var personWithOrderInfo = await query.getOne(executor);
    expect(personWithOrderInfo.value.lastOrderName, originalOrder1?.name);
  });

  test('select orders with person info', () async {
    var personQuery = PersonQuery();
    var query = OrderWithPersonInfoQuery();
    query.join(
        personQuery.tableName, PersonOrderFields.personId, PersonFields.id,
        alias: 'P');
    query.where?.raw("P.name = '${originalPerson?.name}'");
    var orders = await query.get(executor);
    expect(
        orders.every((element) =>
            element.personName == originalPerson?.name &&
            element.personAge == originalPerson?.age),
        true);
  });

  test('select orders with multi order by fields', () async {
    var query = PersonOrderQuery();
    query.orderBy(PersonOrderFields.id, descending: true);
    query.orderBy(PersonOrderFields.personId, descending: true);
    var orders = await query.get(executor);
    expect(orders.first.idAsInt > orders.last.idAsInt, true);
  });
}
