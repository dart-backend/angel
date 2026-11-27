# Angel3 ORM Service

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_service?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/orm_service/LICENSE)

Service implementation that wraps over Angel3 ORM Query classes.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
    angel3_orm_service: ^10.0.0
```

## Usage

Brief snippet (check `example/main.dart` for setup, etc.):

```dart
// Create an ORM-backed service.
var todoService = OrmService<int, Todo, TodoQuery>(
  executor,
  () => TodoQuery(),
  readData: (req, res) => todoSerializer.decode(req.bodyAsMap),
);

// Because we provided `readData`, the todoService can face the Web.
// **IMPORTANT:** Providing the type arguments is an ABSOLUTE MUST if your
// model has `int` IDs (this is the case when using `angel3_orm_generator`
// and `Model`).
app.use<int, Todo, OrmService<int, Todo, TodoQuery>>(
  '/api/todos',
  todoService,
);
```

## Querying

A REST client can filter and sort the records of `index` and the other methods with query parameters:

* `?level=100` matches the records whose `level` column is `100`. The value is converted to the column's type (a number, a boolean or a date). A parameter that names no column, or a value that cannot be converted, is a `400 Bad Request`.
* `?$sort=name` sorts by a column. Only the query's own columns are accepted, as the name is written into the SQL; any other is a `400 Bad Request`. On the server, `$sort` can also be a map of columns to `1` or `-1`, such as `{'name': -1}` for descending order.

On the server, `params['query']` can also be a callback that is given the query, such as `(TodoQuery q) => q.where!.isComplete.isFalse`.

## Updates

`modify` (`PATCH`) changes only the fields it is given, and `update` (`PUT`) replaces every field of the record. Both change one record, by its id, which an `id` in the data does not change.

## Ids of text, as UUIDs

A model whose `id` is text, as `@Column(type: ColumnType.uuid, indexType: IndexType.primaryKey)`, has its `id` given on each insert, as the database does not generate it: `create` of data without one is a `400 Bad Request`. Give it in a hook if clients do not:

```dart
var users = app.use('/users', OrmService<String?, User, UserQuery>(executor, () => UserQuery()));
users.beforeCreated.listen((e) => e.data = (e.data as User).copyWith(id: Uuid().v4()));
```

`validateId` refuses an id that cannot be a record's before it is queried, as one that is not a UUID, which PostgreSQL would refuse with an error of its own (a `400`, see [Errors](#errors)):

```dart
OrmService<String?, User, UserQuery>(executor, () => UserQuery(), validateId: isUuid);
```

An id it refuses is a `404 Not Found` of `read`, `update`, `modify` and `remove`, a `400 Bad Request` of `?id=` and of `create`, and no record of `readMany`.

## Errors

An error of the database that is of the request, as its executor of `angel3_orm_postgres`, `angel3_orm_mysql` or `angel3_orm_sqlite` classifies it, is answered with an HTTP error:

| Error of the database | Response |
| --- | --- |
| A duplicate key, as an `id` or an email that exists | `409 Conflict` |
| A foreign key: a record that refers to none, or the remove of one that others refer to | `409 Conflict` |
| A missing value of a column that requires one | `400 Bad Request` |
| An invalid value, as a malformed UUID on PostgreSQL or text too long | `400 Bad Request` |

Its message names the column or the constraint, as `A record of the same "uuid_users_pkey" exists.`, not the value, which the error of the database may quote. That error is the `error` of the `AngelHttpException`, for the server's logs. Any other error is thrown as it is, a `500`. `OrmService.httpErrorOf` gives the HTTP error of a `QueryError`, for queries of your own:

```dart
try {
  await query.insert(executor);
} catch (e) {
  var error = executor.classifyError(e);
  if (error == null) rethrow;
  throw OrmService.httpErrorOf(error);
}
```

## A database of each tenant

`OrmService.of` gives each call the executor of a function of its params, rather than one of its own, as the database of the tenant of a request. A middleware tells the tenant, of something the client cannot forge, as a claim of its user, and puts it in `req.serviceParams`, which are the params of each call of the request's service:

```dart
final pools = <String, QueryExecutor>{};

app.fallback((req, res) {
  req.serviceParams['tenant'] = tenantOf(req);
  return true;
});

app.use('/todos', OrmService<int?, Todo, TodoQuery>.of(
  (params) async {
    var tenant = params?['tenant'];
    if (tenant is! String || !knownTenants.contains(tenant)) {
      throw AngelHttpException.notFound();
    }
    return pools[tenant] ??= await openPool(tenant);
  },
  () => TodoQuery(),
));

app.shutdownHooks.add((_) async {
  for (var pool in pools.values) {
    await pool.close();
  }
});
```

* **Once of each call.** The function is called once of each call that queries, as `read` or `update`, after its ids are checked, as of `validateId`, so that an id that cannot be a record's is a `404` without it; and before its query. An error it throws, as the `404` of a tenant that is not one, is that of the call.
* **Clients cannot choose it.** A client's query parameters are under `query` of the params, as filters of the query's columns, so `?tenant=b` is a `400`, not the tenant `b`.
* **Errors** of the database of a call are classified by its executor, so tenants of PostgreSQL and of MySQL may share a service.
* **The pools are yours.** The service keeps none: open each tenant's when it is first needed, and close them when the app closes. With `angel3_production`, each isolate opens its own.
* The `executor` of such a service throws a `StateError`, as it has none of its own.
