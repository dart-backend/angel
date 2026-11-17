# Change Log

## 10.0.0

### New in 10.0.0

* **Executors:** `SqliteAsyncExecutor` runs the queries of `angel3_orm` on a SQLite database of the `sqlite_async` package, in background isolates, so that they do not block the isolate that gives them, as on a server: it writes on one connection, and reads outside a transaction on others, in WAL mode, without waiting for a transaction. `SqliteExecutor` runs them on a database of the `sqlite3` package, synchronously, on one connection, as for tests and command-line programs. Both store values the same way, on SQLite 3.35 or later. Requires `angel3_orm` 10.2.0
* **Transactions:** A transaction holds the database, beginning with `BEGIN IMMEDIATE`: a query given outside it waits for it to end. The executor of its callback runs its queries in it from any zone. A transaction in a transaction is a savepoint of it, which is rolled back alone; savepoints run one at a time, so that concurrent updates and deletes in a transaction do not interleave. A transaction that SQLite rolled back after an error runs no more statements and throws a `StateError`
* **Values:** A `DateTime` is stored as UTC text that sorts in time order, of `SqliteDialect.formatDateTime`, a `bool` as `0` or `1`, a `List<int>` as a BLOB, and a `Map` or another `List` as JSON text
* **Inserts:** An insert returns its row by the id of the row SQLite inserted, which may be a text id given by a default, and none if it inserted none
