# Angel3 OpenAPI

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_openapi?include_prereleases)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/openapi/LICENSE)

[OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0) documents of Angel3 applications, built from their routes and the services they mount, and served with a [Swagger UI](https://swagger.io/tools/swagger-ui/) page. Describe what a route cannot tell, such as summaries and schemas, and the rest is kept up to date with the app.

- [Installation](#installation)
- [Usage](#usage)
- [What is documented](#what-is-documented)
  - [Routes](#routes)
  - [Services](#services)
- [Describing operations](#describing-operations)
  - [Schemas](#schemas)
  - [Security](#security)
  - [Anything else](#anything-else)
  - [Controllers](#controllers)
- [Serving the document](#serving-the-document)
- [Things to know](#things-to-know)

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_framework: ^10.2.0
  angel3_openapi: ^10.0.0
```

## Usage

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_openapi/angel3_openapi.dart';

Future<void> main() async {
  var app = Angel();

  var openApi = OpenApi(title: 'Todo API', version: '1.0.0');
  // GET /openapi.json, and the Swagger UI page at GET /docs.
  await app.configure(openApi.configureServer);

  app.use('/todos', MapService());
  app.get('/stats/int:year', (req, res) => {'year': req.params['year']});

  await AngelHttp(app).startServer('127.0.0.1', 3000);
}
```

Open `http://127.0.0.1:3000/docs`. The document is built from the app's routes when it is asked for, so routes added after `configureServer` are in it too. See the [example](example/main.dart) for schemas and descriptions.

## What is documented

### Routes

Each route of an HTTP method and a path is an operation, with its path parameters, of the routes of groups and mounted routers too:

| Route | Operation |
| --- | --- |
| `app.get('/users/:id', ...)` | `GET /users/{id}`, with a `string` parameter `id` |
| `app.get('/items/int:id', ...)` | `GET /items/{id}`, with an `integer` parameter; `double:` and `num:` are `number` |
| `app.get('/files/:name([a-z]+)', ...)` | `GET /files/{name}`, with a `pattern` of `^[a-z]+$` |
| `app.get('/pages/:page?', ...)` | `GET /pages/{page}` and `GET /pages`, with and without it |
| `app.get('/assets/*', ...)` | None: OpenAPI has no wildcards |
| `app.all(...)`, `app.fallback(...)` | None: they are of no one method |

A route's `name` is its `operationId`: `app.get('/users/:id', handler).name = 'readUser'`. Without a description, an operation has a `200` response.

### Services

A service mounted with `app.use` documents its operations, tagged with its path:

| Operation | Service method |
| --- | --- |
| `GET /todos` | `index` |
| `POST /todos` | `create`, a `201` |
| `GET /todos/{id}` | `read` |
| `PATCH /todos/{id}` | `modify` |
| `PUT /todos/{id}` | `update` |
| `DELETE /todos/{id}` | `remove` |

The `index` of a `DocumentedService` of `angel3_framework` lists the query parameters it takes: `$sort` and `$limit` of a `MapService`, and `$sort` and one of each column of an `OrmService` of `angel3_orm_service` 10.1.0, as `GET /todos?is_complete=true`. A service of your own lists its own by implementing it.

A `DocumentedService` also tells of the errors its methods may give besides those below, which their operations list: a `409` of `create`, `modify`, `update` and `remove` of an `OrmService` of `angel3_orm_service`, of a duplicate key or a foreign key. A service of your own implements both `indexQueryParameters` and `errorResponses`.

Each operation also has a `400` response, of a body, query or id the service cannot take, and those of an item a `404`. The `{id}` is of the type of the service's ids: an `integer` of a `Service<int?, ...>`, as an `OrmService<int?, Todo, TodoQuery>`, a `number` of a `double` or `num`, and a `string` otherwise.

The other routes of a service are left out: `POST /todos/{id}`, another way to `update`, and `DELETE /todos`, which removes every item, and most services refuse. The schema of its items is that of the name of its data type, if there is one: `Todo` of an `OrmService<int?, Todo, TodoQuery>`, the name `angel3_serialize_generator` gives the schema of the model (see [Schemas](#schemas)). Give another schema, or a tag, with `describeService`:

```dart
openApi.describeService('todos', schema: OpenApi.ref('Todo'), tag: 'Todos');
```

## Describing operations

`describe` adds what a route cannot tell, of a method and a path written as the route is, or as OpenAPI writes it:

```dart
openApi.describe(
  'GET',
  '/users/{id}',
  OpenApiOperation(
    summary: 'Read a user',
    tags: ['users'],
    queryParameters: {
      'fields': {'type': 'string'},
    },
    responses: {
      200: OpenApiResponse('The user', schema: OpenApi.ref('User')),
      404: OpenApiResponse('No such user'),
    },
  ),
);
```

`requestBody` is the JSON Schema of a request's JSON body. Of a service's operation, `describe` replaces the one the service gives.

### Schemas

`angel3_serialize_generator` 10.1.0 generates the JSON Schema of each `@serializable` model. `OpenApi.schemasOf` collects them, with those of the models they hold, and `OpenApi.ref` of a serializer's `schemaName` refers to one:

```dart
var openApi = OpenApi(
  title: 'Todo API',
  schemas: OpenApi.schemasOf([TodoSerializer.addJsonSchemas]),
);
// Its items are of the schema Todo, of its data type.
app.use('/todos', OrmService<int?, Todo, TodoQuery>(executor, () => TodoQuery()));
```

A service is matched by the name of its `Data` type (`Service.dataType`), without `?`. A service of a `Map`, as a `MapService`, or of a type that has no schema of its name, has none unless `describeService` gives it, as does one of a program compiled with `--obfuscate`, whose type names are not kept:

```dart
openApi.describeService('todos', schema: OpenApi.ref(TodoSerializer.schemaName));
```

Or give schemas of your own, by name:

```dart
var openApi = OpenApi(
  title: 'Todo API',
  schemas: {
    'User': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
      },
    },
  },
);
```

### Security

A route protected by the middleware of `angel3_auth` 10.1.0 documents its security, of the routes of a service or of a chained router too:

```dart
app.get('/me', chain([
  requireAuthentication<User>(),
  (req, res) => req.container!.makeAsync<User>(),
]));
app.chain([requireAuthentication<User>()]).mount('/api', api);
```

| Middleware | `security` | Response |
| --- | --- | --- |
| `requireAuthentication<User>()` | A `Bearer` JWT | `403` |
| `forceBasicAuth<User>()` | A `Bearer` JWT, or Basic | `401` |

Their schemes, `bearer` and `basic`, are in `components.securitySchemes`. `angel3_auth` also reads a JWT of the `token` cookie, and of the `token` query parameter if `allowTokenInQuery`: give those schemes in `extra` if clients use them. A middleware of your own documents its requirement when tagged with a `SecurityRequirement` of `angel3_framework`:

```dart
const apiKey = SecurityScheme('apiKey', {
  'type': 'apiKey',
  'in': 'header',
  'name': 'X-API-Key',
});

RequestHandler requireApiKey(String key) =>
    const SecurityRequirement([apiKey]).tag(
      (RequestContext req, ResponseContext res) =>
          req.headers?.value('x-api-key') == key,
    );
```

A handler of several requirements needs each, of one of its schemes. The security of a service protected by its hooks, as `beforeAll`, cannot be seen: describe it with `describe`. An operation described with a `security` of its `extra` keeps it.

### Anything else

`extra` adds to the document, or to an operation, what the rest does not give, as security schemes of your own:

```dart
var openApi = OpenApi(
  title: 'Todo API',
  extra: {
    'components': {
      'securitySchemes': {
        'bearer': {'type': 'http', 'scheme': 'bearer'},
      },
    },
    'security': [
      {'bearer': <String>[]},
    ],
  },
);
```

The `components` of `extra` join those of `schemas` and of the handlers: its `securitySchemes` are added to those of the handlers, and any other of its keys, as `schemas`, replaces theirs.

### Controllers

Annotate a method of a `Controller` with `@OpenApiOperation`, which takes what `describe` does:

```dart
@Expose('/users')
class UserController extends Controller {
  @Expose('/:id')
  @OpenApiOperation(
    summary: 'Read a user',
    tags: ['users'],
    responses: {
      200: OpenApiResponse('The user'),
      404: OpenApiResponse('No such user'),
    },
  )
  Map<String, dynamic> read(String id) => {'id': id};
}
```

The annotations are read through the app's reflector, as the controller's `@Expose` annotations are: a `MirrorsReflector`, or the reflection data of `angel3_container_generator` without `dart:mirrors`, of an `@injectable` controller whose library imports `angel3_openapi`. A `describe` of the same operation takes precedence over the annotation.

## Serving the document

`configureServer` serves:

- **The document** at `documentPath`, `openapi.json` by default.
- **The Swagger UI page** at `uiPath`, `docs` by default, or no page with `uiPath: null`. It loads Swagger UI 5.34.1 from jsDelivr; give `swaggerUiUrl` to load it from elsewhere, such as a copy of `swagger-ui-dist` that `angel3_static` serves.

Without `configureServer`, `openApi.documentOf(app)` gives the document, and `openApi.swaggerUiPage(url)` the page.

## Things to know

- **Who may read it.** The document lists every route of the app. Configure it only where it should be public, or put a middleware before it that checks who asks.
- **In production** (`ANGEL_ENV=production`), the document is built once, when first asked for, and again after `describe`.
- **Mounted apps.** The services of an app mounted with `app.mount('/api', api)`, and of one mounted in it, are documented as services, under the path of the mount: `GET /api/todos`, tagged `api/todos`, which `describeService('api/todos', ...)` describes. Those of a mount of a parameter, as `app.mount('/orgs/:org', org)`, are documented as plain routes.
