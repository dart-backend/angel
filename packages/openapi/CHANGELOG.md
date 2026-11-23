# Change Log

## 10.0.0

### New in 10.0.0

* **Documents:** `OpenApi` builds an OpenAPI 3.1 document of an app: an operation of each route of an HTTP method, of groups and mounted routers too, with its path parameters (`integer` of `int:`, `number` of `double:` and `num:`, a `pattern` of a regular expression, and both paths of an optional one), and its `name` as its `operationId`. Routes of a wildcard, or of any method, are left out
* **Services:** A service mounted with `app.use` documents its `index`, `create`, `read`, `modify`, `update` and `remove`, with the `201` that `create` responds with, which `describeService` gives a schema and a tag
* **Descriptions:** `describe` adds a summary, tags, query parameters, request and response schemas, and more of the Operation Object of `extra`, of a path as the route writes it or as OpenAPI does. `schemas` are the document's `components`, which `OpenApi.ref` refers to
* **Schemas:** `OpenApi.schemasOf` collects the JSON Schemas that `angel3_serialize_generator` 10.1.0 generates of `@serializable` models, with those of the models they hold
* **Controllers:** A method of a `Controller` is described by an `@OpenApiOperation` annotation, read through the app's reflector, `MirrorsReflector` or the reflection data of `angel3_container_generator`
* **Serving:** `configureServer` serves the document at `/openapi.json` and a Swagger UI page at `/docs`, built when asked for, so routes added later are documented, and once in production
