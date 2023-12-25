# Angel3 Route

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_route?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/route/LICENSE)

A powerful, isomorphic routing library for Dart.

`angel3_route` exposes a routing system that takes the shape of a tree. This tree structure can be easily navigated, in a fashion somewhat similar to a filesystem. The `Router` API is a very straightforward interface that allows for your code to take a shape similar to the route tree. Users of Laravel and Express will be very happy.

`angel3_route` does not require the use of [Angel 3](https://pub.dev/packages/angel3_framework), and has minimal dependencies. Thus, it can be used in any application, regardless of framework. This includes Web apps, Flutter apps, CLI apps, and smaller servers which do not need all the features of the Angel framework.

## Contents

- [Angel3 Route](#angel3-route)
  - [Contents](#contents)
  - [Examples](#examples)
    - [Routing](#routing)
    - [Hierarchy](#hierarchy)
  - [In the Browser](#in-the-browser)
  - [Route State](#route-state)
  - [Route Parameters](#route-parameters)

## Examples

### Routing

If you use [Angel3](https://pub.dev/packages/angel3_framework), every `Angel` instance is a `Router` in itself.

```dart
void main() {
  final router = Router();
  
  router.get('/users', () {});
  
  router.post('/users/:id/timeline', (String id) {});
  
  router.get('/square_root/:id([0-9]+)', (n) { 
    return { 'result': pow(int.parse(n), 0.5) };
  });
  
  // You can also have parameters auto-parsed.
  //
  // Supports int, double, and num.
  router.get('/square_root/int:id([0-9]+)', (int n) { 
      return { 'result': pow(n, 0.5) };
    });
  
  router.group('/show/:id', (router) {
    router.get('/reviews', (id) {
      return someQuery(id).reviews;
    });
    
    // Optionally restrict params to a RegExp
    router.get('/reviews/:reviewId([A-Za-z0-9_]+)', (id, reviewId) {
      return someQuery(id).reviews.firstWhere(
        (r) => r.id == reviewId);
    });
  }, middleware: [put, middleware, here]);

  // Grouping can also take async callbacks.
  await router.groupAsync('/hello', (router) async {
    var name = await getNameFromFileSystem();
    router.get(name, (req, res) => '...');
  });
}
```

The default `Router` does not give any notification of routes being changed, because there is no inherent stream of URL's for it to listen to. This is good, because a server needs a lot of flexibility with which to handle requests.

### Hierarchy

```dart
void main() {
  final router = Router();
  
  router
    .chain('middleware1')
    .chain('other_middleware')
    .get('/hello', () {
      print('world');
    });
  
  router.group('/user/:id', (router) {
    router.get('/balance', (id) async {
      final user = await someQuery(id);
      return user.balance;
    });
  });
}
```

See [the tests](test/route/no_params.dart) for good examples.

## In the Browser

Supports both hashed routes and pushState. The `BrowserRouter` interface exposes a `Stream<RoutingResult> onRoute`, which can be listened to for changes. It will fire `"NULL"` whenever no route is matched.

`angel3_route` will also automatically intercept `<a>` elements and redirect them to your routes.

To prevent this for a given anchor, do any of the following:

- Do not provide an `href`
- Provide a `download` or `target` attribute on the element
- Set `rel="external"`
  
## Route State

```dart
main() {
  final router = BrowserRouter();
  // ..
  router.onRoute.listen((route) {
    if (route == null)
      throw 404;
    else route.state['foo'] = 'bar';
  });

  router.listen(); // Start listening
}
```

For applications where you need to access a chain of handlers, consider using `onResolve` instead. You can see an example in `web/shared/basic.dart`.

## Route Parameters

Routes can have parameters, as seen in the above examples. Use `allParams` in a `RoutingResult` to get them as a nice `Map`:

```dart
var router = Router();
router.get('/book/:id/authors', () => ...);

var result = router.resolve('/book/foo/authors');
var params = result.allParams; // {'id': 'foo'};
```
