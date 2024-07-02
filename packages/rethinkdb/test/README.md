# Tests

The tests expect you to have installed RethinkDB. You must have a `testDB` database available, and a server ready at the default port. Also, the tests expect a table named `todos`. To create the table, run the following command:

```bash
    dart test/bootstrap.dart
```
