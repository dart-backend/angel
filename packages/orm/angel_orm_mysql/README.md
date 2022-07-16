# Angel3 ORM for MySQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_mysql?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/orm/angel_orm_mysql/LICENSE)

This package contains the SQL Executor required by Angel3 ORM to work with MySQL and MariaDB respectively. In order to better support the differences in MySQL and MariaDb underlying protocols, two different drives have to be used. For MariaDb 10.2.x, `mysql1` driver provides the best results, while `mysql_client` driver handles MySQL 8.x.x without issues.

* MariaDbExecutor
* MySqlExecutor

## Supported database version

* MariaDb 10.2.x
* MySQL 8.x

**Note** MySQL below version 8.0 and MariaDB below version 10.2 are not supported as Angel3 ORM requires common table expressions (CTE).

## Connecting to MariaDB database 10.2.x

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

## Connecting to MySQL database 8.x

```dart
    import 'package:mysql_client/mysql_client.dart';

    var connection = await MySQLConnection.createConnection(
        host: "localhost",
        port: 3306,
        databaseName: "orm_test",
        userName: "test",
        password: "test123",
        secure: false);

    var logger = Logger('orm_mysql');
    await connection.connect(timeoutMs: 10000);
    var executor = MySqlExecutor(connection, logger: logger);
```

### Issues

* Blob
* DateTime value not in UTC
* Transaction is broken

## Creating a new database in MariaDB/MySQL

1. Login to MariaDB/MySQL database console with the following command.

```bash
    mysql -u root -p
```

1. Run the following commands to create a new database, `orm_test` and grant both local and remote access to user, `test`. Replace `orm_test`, `test` and `test123` with your own database name, username and password respectively.

```mysql
    create database orm_test;
    
    create user 'test'@'localhost' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'localhost';

    create user 'test'@'%' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'%';
```

## Known limitation

### Using `mysql1` driver on MariabDb

* Blob
* DateTime value not in UTC
* Transaction is broken

### Using `mysql1` driver on MySQL

* Blob is not supported

### Using `mysql_client` driver on MariabDb

* Blob is not supported

### Using `mysql_client` driver on MySQL

* Blob is not supported
