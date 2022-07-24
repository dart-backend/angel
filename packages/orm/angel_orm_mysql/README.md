# Angel3 ORM for MySQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_mysql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/orm/angel_orm_mysql/LICENSE)

This package contains the SQL executor required by Angel3 ORM to work with MySQL and MariaDB respectively. In order to better support both MySQL and MariaDB, two different flavors of drives have been included; `mysql_client` and `mysql1`. They are implmented as `MySqlExecutor` and `MariaDbExecutor` respectively.

## Supported databases

* MariaDD 10.2.x or greater
* MySQL 8.x or greater

**Note** MySQL below version 8.0 and MariaDB below version 10.2.0 are not supported as Angel3 ORM requires common table expressions (CTE) to work.

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

## Creating a new database in MariaDB or MySQL

1. Login to MariaDB/MySQL database console with the following command.

```bash
    mysql -u root -p
```

1. Run the following commands to create a new database, `orm_test` and grant both local and remote access to user, `test`. Replace `orm_test`, `test` and `test123` with your own database name, username and password respectively.

```mysql
    create database orm_test;
    
    -- Granting localhost access only
    create user 'test'@'localhost' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'localhost';

    -- Granting localhost and remote access
    create user 'test'@'%' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'%';
```

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
