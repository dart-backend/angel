/// Framework features that read annotations through the reflector, with
/// generated reflection data instead of `dart:mirrors`.
library;

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';

part 'app.g.dart';

@injectable
@Expose('/items')
class ItemController extends Controller {
  String getItem(int id) => 'get $id';
  String putItem(int id) => 'put $id';
  String deleteItem(int id) => 'delete $id';
  // Verb-like prefixes that are not whole words: plain GET routes.
  String posts() => 'posts';
  String headers() => 'headers';
  String getter() => 'getter';

  @Expose('/search')
  String search(@Query('q') String q) => 'search $q';

  @noExpose
  String hidden() => 'hidden';
}

/// An annotation that names a static member of its class.
@injectable
@Expose('/limits')
class LimitsController extends Controller {
  static const maxPath = '/max';

  @Expose(maxPath)
  String max() => 'max';
}

void interceptor(RequestContext req, ResponseContext res) {
  res
    ..write('Middleware')
    ..close();
}

bool interceptService(RequestContext req, ResponseContext res) {
  res.write('Service with ');
  return true;
}

@injectable
@Middleware([interceptService])
class QueryService extends Service {
  @override
  @Middleware([interceptor])
  Future<Map?> read(id, [Map? params]) async => params;
}

int hookCalls = 0;

void countHook(dynamic e) => hookCalls++;

@injectable
@Hooks(before: [countHook])
class CountedService extends Service {
  @override
  @Hooks(after: [countHook])
  Future<List> index([params]) async => [];
}

@injectable
@Middleware([interceptor])
String annotatedHandler(RequestContext req, ResponseContext res) =>
    'This should not be shown.';

@injectable
String hello(String name) => 'Hello, $name!';
