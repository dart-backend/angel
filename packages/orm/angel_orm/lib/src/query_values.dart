import 'query.dart';

abstract class QueryValues {
  Map<String, String> get casts => {};

  Map<String, dynamic> toMap();

  String applyCast(String name, String sub) {
    if (casts.containsKey(name)) {
      var type = casts[name];
      return 'CAST ($sub as $type)';
    } else {
      return sub;
    }
  }

  /// Check if a field is in the query
  bool hasField(String fieldName) {
    var data = Map<String, dynamic>.from(toMap());
    var keys = data.keys.toList();

    return keys.contains(fieldName);
  }

  String compileInsert(Query query, String tableName) {
    var data = Map<String, dynamic>.from(toMap());
    var now = DateTime.now();

    for (var key in ['created_at', 'createdAt', 'updated_at', 'updatedAt']) {
      if (data.containsKey(key) && data[key] == null) {
        data[key] = now;
      }
    }

    var keys = data.keys.toList();
    keys.where((k) => !query.fields.contains(k)).forEach(data.remove);
    if (data.isEmpty) {
      return '';
    }
    var fieldSet = data.keys.join(', ');
    var b = StringBuffer('INSERT INTO $tableName ($fieldSet) VALUES (');
    var i = 0;

    for (var entry in data.entries) {
      if (i++ > 0) b.write(', ');

      var name = query.reserveName(entry.key);

      var s = applyCast(entry.key, '@$name');
      query.substitutionValues[name] = entry.value;
      b.write(s);
    }

    b.write(')');
    return b.toString();
  }

  String compileInsertSelect(Query query, String tableName) {
    var data = Map<String, dynamic>.from(toMap());

    var b = StringBuffer();
    var i = 0;

    for (var entry in data.entries) {
      if (i++ > 0) b.write(' AND ');
      b.write('$tableName.${entry.key} = ?');
    }

    return b.toString();
  }

  String compileForUpdate(Query query) {
    var data = toMap();
    if (data.isEmpty) {
      return '';
    }
    var now = DateTime.now();
    if (data.containsKey('created_at') && data['created_at'] == null) {
      data.remove('created_at');
    }
    if (data.containsKey('createdAt') && data['createdAt'] == null) {
      data.remove('createdAt');
    }
    if (data.containsKey('updated_at') && data['updated_at'] == null) {
      data['updated_at'] = now;
    }
    if (data.containsKey('updatedAt') && data['updatedAt'] == null) {
      data['updatedAt'] = now;
    }
    var b = StringBuffer('SET');
    var i = 0;

    for (var entry in data.entries) {
      if (i++ > 0) b.write(',');
      b.write(' ');
      b.write(entry.key);
      b.write('=');

      var name = query.reserveName(entry.key);
      var s = applyCast(entry.key, '@$name');
      query.substitutionValues[name] = entry.value;
      b.write(s);
    }
    return b.toString();
  }
}
