import 'dart:io';

/// The RethinkDB server the tests use: `RETHINKDB_HOST`, or `localhost`.
final String rethinkHost =
    Platform.environment['RETHINKDB_HOST'] ?? 'localhost';

class Todo {
  String? title;
  bool completed;

  Todo({this.title, this.completed = false});

  Map toJson() {
    return {'title': title, 'completed': completed == true};
  }
}
