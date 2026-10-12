# Tests

The tests need a RethinkDB server on the default port (28015), with an `admin` user and no password. It is `localhost` unless the `RETHINKDB_HOST` environment variable names another host.

The tests use the `todos` table of the `testDB` database. To create both, if missing, run:

```bash
    dart test/bootstrap.dart
```

For example, with a server on another machine:

```bash
    RETHINKDB_HOST=172.19.137.42 dart test/bootstrap.dart
    RETHINKDB_HOST=172.19.137.42 dart test
```
