# Angel3 ORM for PostgreSQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_postgres?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm_postgres/LICENSE)

Angel3 ORM for working with PostgreSQL database 14 or later.

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Migrating to 8.1.0 and above

`postgres` has been upgraded from 2.x.x to 3.x.x since version 8.1.0. This is a breaking change as `postgres` 3.x.x has revamped its API. Therefore when upgrading to 8.1.0 and beyond, the PostgreSQL connection settings need to be migrated. The rest should remain the same. Please see the example for the new PostgreSQL connection settings.

## Usage

1. Create a model with `Entity` suffix, i.e. `CarEntity` in `car.dart`

   ```dart
    import 'package:angel3_migration/angel3_migration.dart';
    import 'package:angel3_orm/angel3_orm.dart';
    import 'package:angel3_serialize/angel3_serialize.dart';
    import 'package:optional/optional.dart';
    
    part 'car.g.dart';

    @serializable
    @orm
    class CarEntity extends Model {
        String? make;
        String? description;
        bool? familyFriendly;
        DateTime? recalledAt;
        double? price;
    }
   ```

2. Run the following command to generate the required `.g.dart` file for the model.

    ```bash
    dart run build_runner build
    ```

3. Write the query program. i.e. `CarPersistence.dart`

    ```dart
    import 'package:angel3_migration_runner/postgres.dart';
    import 'package:angel3_orm_postgres/angel3_orm_postgres.dart';
    import 'package:postgres/postgres.dart';

    import 'car.dart';

    void main() async {
    
        // Setup the connections
        final conn = await Connection.open(
            Endpoint(
                host: 'localhost',
                port: 5432,
                database: 'postgres',
                username: 'postgres',
                password: 'postgres'),
            settings: ConnectionSettings(sslMode: SslMode.disable));

        var executor = PostgreSqlExecutor(conn);

        // Create the `Car` table
        var runner = PostgresMigrationRunner(conn, migrations: [CarMigration()]);
        await runner.up();

        var query = CarQuery();
        query.values
            ..make = 'Ferrari'
            ..description = 'Vroom vroom!'
            ..price = 1200000.00
            ..familyFriendly = false;
        
        // insert a new record into the `cars` table
        var ferrari = (await query.insert(executor)).value;
    }
    ```

## Transactions

`transaction` runs its callback in a transaction, which is committed if the callback completes, and rolled back if it throws. The error is thrown as it is.

```dart
var car = await executor.transaction((tx) async {
  var query = CarQuery()..values.make = 'Ferrari';
  return (await query.insert(tx)).value;
});
```

PostgreSQL does not nest transactions, so `transaction` on the executor the callback is given runs in a savepoint instead. What it does is rolled back if it throws, even when the outer callback catches the error, and committed with the outer transaction otherwise.

```dart
await executor.transaction((tx) async {
  await insertOrder(tx);
  try {
    await tx.transaction((inner) => sendInvoice(inner));
  } on InvoiceException {
    // Only the savepoint is rolled back; the order is kept.
  }
});
```

* Use the executor given to the callback. Calling `transaction` on the executor of the connection from inside the callback throws, as the connection is in use.
* Savepoints at one level of nesting run one at a time. A transaction or savepoint waits for the savepoints started inside it, even those not awaited, before it is committed, released or rolled back.
* A query on the executor of the transaction made while a savepoint is open, rather than on the executor of the savepoint, is part of that savepoint, and rolled back with it.
* `PostgreSqlPoolExecutor.transaction` runs the transaction on a connection of the pool, and nests savepoints the same way.
