import 'dart:convert';
import 'package:angel_framework/angel_framework.dart';
//import 'package:json_god/json_god.dart' as god;

@deprecated
class CustomMapService extends Service {
  final List<Map> _items = [];

  Iterable<Map> tailor(Iterable<Map> items, Map? params) {
    if (params == null) return items;

    var r = items;

    if (params['query'] is Map) {
      var query = params['query'] as Map;

      for (var key in query.keys) {
        r = r.where((m) => m[key] == query[key]);
      }
    }

    return r;
  }

  @override
  Future<List<Map>> index([params]) async => tailor(_items, params).toList();

  @override
  Future<Map> read(id, [Map? params]) async {
    return tailor(_items, params).firstWhere((m) => m['id'] == id,
        orElse: (() => throw AngelHttpException.notFound()));
  }

  @override
  Future<Map> create(data, [params]) async {
    var d = data is Map ? data : (jsonDecode(data as String) as Map?)!;
    d['id'] = _items.length.toString();
    _items.add(d);
    return d;
  }

  @override
  Future remove(id, [params]) async {
    if (id == null) _items.clear();
  }
}

class Author {
  String? id, name;

  Author({this.id, this.name});

  Map toJson() => {'id': id, 'name': name};
}

class Book {
  String? authorId, title;

  Book({this.authorId, this.title});

  Map toJson() => {'authorId': authorId, 'title': title};
}

class Chapter {
  String? bookId, title;
  int? pageCount;

  Chapter({this.bookId, this.title, this.pageCount});
}
