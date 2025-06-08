# Angel3 ORM for MySQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_mysql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel_orm_mysql/LICENSE)

This package contains the SQL executor required by Angel3 ORM to work with MySQL or MariaDB databases. In order to better support both MySQL and MariaDB, two different flavors of drives have been included; `mysql_client` and `mysql1`. They are implmented as `MySqlExecutor` and `MariaDbExecutor` respectively.

## Supported databases

* MariaDD 10.2.x or later
* MySQL 8.x or later

**Note** MySQL below version 8.0 and MariaDB below version 10.2.0 are not supported as Angel3 ORM requires common table expressions (CTE) to work.

## Usage

1. Create a model, i.e. `car.dart`

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
    import 'package:angel3_migration_runner/angel3_migration_runner.dart';
    import 'package:angel3_orm/angel3_orm.dart';
    import 'package:logging/logging.dart';
    import 'package:mysql_client/mysql_client.dart';
    import 'models/car.dart';

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
        var runner = MysqlMigrationRunner(conn, migrations: [CarMigration()]);
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

This SQL executor is implemented using [`mysql_client`](https://pub.dev/packages?q=mysql_client) driver. It works with both `MySQL` 8.0+ and `MariaDB` 10.2+ database.

### Connecting to MySQL or MariaDB

```dart
    import 'package:mysql_client/mysql_client.dart';

    var connection = await MySQLConnection.createConnection(
        host: "localhost",
        port: 3306,
        databaseName: "orm_test",
        userName: "test",
        password: "test123",
        secure: true);

    var logger = Logger('orm_mysql');
    await connection.connect(timeoutMs: 10000);
    var executor = MySqlExecutor(connection, logger: logger);
```

### Known Limitation for MySqlExecutor

* `Blob` data type mapping is not support.
* `timestamp` data type mapping is not supported. Use `datetime` instead.
* UTC datetime is not supported.

## MariaDBExecutor

This SQL executor is implemented using [`mysql1`](https://pub.dev/packages?q=mysql1) driver. It only works with `MariaDB` 10.2+ database. Do not use this for `MySQL` 8.0+ database.

### Connecting to MariaDB

```dart
    import 'package:mysql1/mysql1.dart';

    var settings = ConnectionSettings(
        host: 'localhost',
        port: 3306,
        db: 'orm_test',
        user: 'test',
        password: 'test123');
    var connection = await MySqlConnection.connect(settings);

    var logger = Logger('orm_mariadb');
    var executor = MariaDbExecutor(connection, logger: logger);
```

### Known Limitation for MariaDBExecutor

* `Blob` type mapping is not supported.
* `timestamp` mapping is not supported. Use `datetime` instead.
* Only UTC datetime is supported. None UTC datetime will be automatically converted into UTC datetime.

## Compatibility Matrix

### MariaDB 10.2+

|                 | Create |  Read  | Update | Delete |
|-----------------|--------|--------|--------|--------|
| MySqlExecutor   |    Y   |   Y    |    Y   |    Y   |
| MariaDBExecutor |    Y   |   Y    |    Y   |    Y   |

### MySQL 8.0+

|                 | Create |  Read  | Update | Delete |
|-----------------|--------|--------|--------|--------|
| MySqlExecutor   |    Y   |   Y    |    Y   |    Y   |
| MariaDBExecutor |    N   |   N    |    N   |    N   |
