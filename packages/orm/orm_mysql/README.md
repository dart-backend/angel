# Angel3 ORM for MySQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_mysql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm_mysql/LICENSE)

This package contains the SQL executor required by Angel3 ORM to work with MySQL or MariaDB databases. Both executors, `MySqlExecutor` and `MariaDbExecutor`, use the [`mysql_dart`](https://pub.dev/packages/mysql_dart) driver and work with MySQL and MariaDB; they differ in how a `DateTime` is stored.

## Supported databases

* MariaDB 10.2.x or later
* MySQL 8.x or later

**Note** MySQL below version 8.0 and MariaDB below version 10.2.0 are not supported as Angel3 ORM requires common table expressions (CTE) to work.

## Usage

1. Create a model with `Entity` suffix, i.e. `CarEntity` in a `car.dart`

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
    import 'package:angel3_migration_runner/mysql.dart';
    import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
    import 'package:mysql_dart/mysql_dart.dart';

    import 'car.dart';

    void main() async {
    
        // Setup the connections
        var conn = await MySQLConnection.createConnection(
            databaseName: 'orm_test',
            port: 3306,
            host: "localhost",
            userName: 'test',
            password: 'Test123',
            secure: true);
        await conn.connect(timeoutMs: 10000);

        var executor = MySqlExecutor(conn);

        // Create the `Car` table
        var runner = MySqlMigrationRunner(conn, migrations: [CarMigration()]);
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

## MySqlExecutor

This SQL executor is implemented using [`mysql_dart`](https://pub.dev/packages/mysql_dart) driver. It works with `MySQL` 8.0+.

### Connecting to MySQL

```dart
    import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
    import 'package:logging/logging.dart';
    import 'package:mysql_dart/mysql_dart.dart';

    var connection = await MySQLConnection.createConnection(
        host: "localhost",
        port: 3306,
        databaseName: "orm_test",
        userName: "test",
        password: "test123",
        secure: true);
    await connection.connect(timeoutMs: 10000);

    var logger = Logger('orm_mysql');
    var executor = MySqlExecutor(connection, logger: logger);
```

### Known Limitation for MySqlExecutor

* `Blob` data type mapping is not supported.
* A `timestamp` column, which the server converts from and to the `time_zone` of the session, is read and written as a `datetime` one is. The migration runner creates `timeStamp` columns as `datetime`.
* A `DateTime` is stored as local time: a UTC one is converted to local time when it is sent, and a `datetime` column is read back as local time. See [Date and time](#date-and-time).

## MariaDbExecutor

This SQL executor is implemented using [`mysql_dart`](https://pub.dev/packages/mysql_dart) driver. It works with `MariaDB` 10.2+ database that stores a `DateTime` as UTC.

### Connecting to MariaDB

```dart
    import 'package:angel3_orm_mysql/angel3_orm_mysql.dart';
    import 'package:logging/logging.dart';
    import 'package:mysql_dart/mysql_dart.dart';

    var connection = await MySQLConnection.createConnection(
        host: "localhost",
        port: 3306,
        databaseName: "orm_test",
        userName: "test",
        password: "test123",
        secure: true);
    await connection.connect(timeoutMs: 10000);

    var logger = Logger('orm_mariadb');
    var executor = MariaDbExecutor(connection, logger: logger);
```

### Known Limitation for MariaDbExecutor

* `Blob` type mapping is not supported.
* A `timestamp` column, which the server converts from and to the `time_zone` of the session, is read and written as a `datetime` one is. The migration runner creates `timeStamp` columns as `datetime`.
* A `DateTime` is stored as UTC: a local one is converted to UTC when it is sent, and a `datetime` column is read back as UTC. See [Date and time](#date-and-time).

## Date and time

A `datetime` column has no time zone, so the two executors store the same `DateTime` differently: `MySqlExecutor` as local time, and `MariaDbExecutor` as UTC. Each reads back what it wrote as the same moment. Where the application's time zone is not UTC, a time written by one executor is read, or compared, shifted by the offset by the other, so use one executor for a database, or run the application at UTC.

A `DateTime` given for a `date` column is converted too, before the server keeps its date, so a date may be stored as the day before or after: a local `DateTime(2020, 1, 2)` is `2020-01-01 16:00` UTC at UTC+8, which `MariaDbExecutor` stores as `2020-01-01`. Give the date of a `date` column as a `DateTime` of the time zone of the executor: UTC for `MariaDbExecutor` (`DateTime.utc(2020, 1, 2)`), and local time for `MySqlExecutor`.

A zero date or time (`0000-00-00`), which MySQL and MariaDB store where a date is invalid and the SQL mode allows it, is read as `null`, as is an invalid date stored under `ALLOW_INVALID_DATES`, such as `2024-02-30`, rather than as another day.

## Transactions

The queries of a connection run one at a time. A transaction holds the connection until it ends, so a query given in it to another executor of the connection, such as that of the application, runs in the transaction, as a transaction begun in it is of it: MySQL and MariaDB nest none. Use the executor given to the transaction. The queries given to it before the transaction ends, even those not waited for, and the later queries of an operation of the ORM they start, such as the update of an `update`, run in it, before its `COMMIT` or `ROLLBACK`; one given after it has ended throws a `StateError`, as does `close`, of its executor or of another of the connection, in it. Await the queries of a transaction, so that their errors roll it back.
