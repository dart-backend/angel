# Tests

The tests need a MongoDB server on the default port (27017), with a `root` user whose password is `Qwerty` (authentication database `admin`). It is `localhost` unless the `MONGO_HOST` environment variable names another host.

The tests use the `testData` and `serviceTest` collections of the `testDB` database, which MongoDB creates on first use, and empty them before and after each test.

```bash
    dart test
```

For example, with a server on another machine:

```bash
    MONGO_HOST=172.19.137.42 dart test
```
