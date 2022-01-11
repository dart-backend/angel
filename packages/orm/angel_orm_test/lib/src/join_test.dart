import 'dart:async';
import 'dart:math';

import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

import 'models/person.dart';
import 'models/person_order.dart';

void joinTests(FutureOr<QueryExecutor> Function() createExecutor,
    {FutureOr<void> Function(QueryExecutor)? close}) {
  late QueryExecutor executor;
  Person? originalPerson;
  PersonOrder? originalOrder1;
  PersonOrder? originalOrder2;
  close ??= (_) => null;

  setUp(() async {
    executor = await createExecutor();
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

  tearDown(() => close!(executor));

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
    query.orderBy(PersonOrderFields.personId, descending: true);
    query.orderBy(PersonOrderFields.id, descending: true);
    var orders = await query.get(executor);
    expect(orders.first.personId > orders.last.personId, true);
  });
}
