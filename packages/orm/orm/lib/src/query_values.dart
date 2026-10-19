import 'query.dart';

abstract class QueryValues {
  // The parameter name reserved for each column, in [_namesQuery]; reused when
  // the values are compiled again (e.g. a query inserted twice), so a value
  // replaces the previous one instead of leaving it as an unused parameter.
  final Map<String, String> _names = {};
  Query? _namesQuery;

  Map<String, String> get casts => {};

  String _nameFor(Query query, String column) {
    if (!identical(query, _namesQuery)) {
      _names.clear();
      _namesQuery = query;
    }
    return _names[column] ??= query.reserveName(column);
  }

  /// The name of the parameter of [column] in the SQL that these values
  /// last compiled for [query], as by [compileInsert], such as `id` of
  /// `@id`, or `null` if they compiled none of it for [query].
  String? parameterNameOf(Query query, String column) =>
      identical(query, _namesQuery) ? _names[column] : null;

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

      var name = _nameFor(query, entry.key);

      var s = applyCast(entry.key, '@$name');
      query.substitutionValues[name] = entry.value;
      b.write(s);
    }

    b.write(')');
    return b.toString();
  }

  @Deprecated(
    'Not used: an insert into a table without an id returns the values it '
    'inserted, as a row of no key cannot be selected again by its values.',
  )
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

      var name = _nameFor(query, entry.key);
      var s = applyCast(entry.key, '@$name');
      query.substitutionValues[name] = entry.value;
      b.write(s);
    }
    return b.toString();
  }
}
