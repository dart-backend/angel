# Change Log

## 10.1.0

### New in 10.1.0

* **Errors:** `SqliteExecutor` and `SqliteAsyncExecutor` classify a `SqliteException` by its extended result code (`classifyError`, of `angel3_orm` 10.3.0, which this version requires): `2067`, `1555` and `2579` (a rowid) a duplicate key, `1299` a `NOT NULL` violation, `787` a foreign key one (with `PRAGMA foreign_keys = ON`), and `275` (`CHECK`), `3091` (a value of the wrong type in a `STRICT` table), `20` (a type mismatch) and `18` (a text or blob too long) an invalid value. The column of a duplicate key of one column, a `NOT NULL` violation and a value of the wrong type in a `STRICT` table is that of the message, read by the table of the query, in any case and without a schema before it, so that the names of tables and columns may have dots and commas; a message of another table, as of a query given the table `''`, is read up to its first dot. A key of several columns, or the hidden `rowid`, names none. The constraint of a unique index on an expression is the name of the index, and that of a failed `CHECK` its name, if the table declares one by that name, which the executor reads after the error from the schema of the table, `temp`, `main` or an attached one, on the connection that ran the statement, rather than its expression. `classifySqliteError` is the function they use

## 10.0.1

### Fixes in 10.0.1

* **Docs:** The README is rewritten in plain English, with a table of contents, a section on choosing an executor, and the transaction rules split into subsections

## 10.0.0

### New in 10.0.0

* **Executors:** `SqliteAsyncExecutor` runs the queries of `angel3_orm` on a SQLite database of the `sqlite_async` package, in background isolates, so that they do not block the isolate that gives them, as on a server: it writes on one connection, and reads outside a transaction on others, in WAL mode, without waiting for a transaction. `SqliteExecutor` runs them on a database of the `sqlite3` package, synchronously, on one connection, as for tests and command-line programs. Both store values the same way, on SQLite 3.35 or later. Requires `angel3_orm` 10.2.0
* **Transactions:** A transaction holds the write lock of the database, beginning with `BEGIN IMMEDIATE`: a query given outside it waits for it to end, but for a read with `SqliteAsyncExecutor` on a pool, which runs at once and sees the rows as they were before it. The executor of its callback runs its queries in it from any zone. A transaction in a transaction is a savepoint of it, which is rolled back alone; savepoints run one at a time, so that concurrent updates and deletes in a transaction do not interleave, and transactions of separate requests one after the other. A transaction that SQLite rolled back after an error runs no more statements and throws a `StateError`, as does, with `SqliteExecutor`, one whose savepoint could not be rolled back, which is rolled back whole. A query given by code that runs after its savepoint ended, as of a timer, runs in the transaction of the savepoint. A statement given to a transaction while it commits or rolls back fails with a `StateError`, as does a statement, a transaction or `close()` given by the code of its callback to another executor then, as does one given to the executor of an ended transaction, which returns a failed `Future` rather than throwing. Once `close()` is called, a query or transaction given outside a transaction fails at once with a `StateError`, and the database closes when the transactions, and the queries given before it, have ended
* **Values:** A `DateTime` is stored as UTC text that sorts in time order, of `SqliteDialect.formatDateTime`, a `bool` as `0` or `1`, a `Uint8List` as a BLOB, and a `Map` or a `List` as JSON text. A placeholder with no value throws an `ArgumentError`
* **Reads:** With `SqliteAsyncExecutor`, a `SELECT` outside a transaction, and a union of them, runs on a connection that reads
* **Inserts:** An insert returns its row by the id of the row SQLite inserted, which may be a text id given by a default, and none if it inserted none. The insert and the select of its row are atomic: if the select fails, the row is not inserted, in a transaction too, and, with `SqliteExecutor`, in one begun on the `sqlite3` database itself
