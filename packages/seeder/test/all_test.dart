import 'dart:async';

import 'package:angel_framework/angel_framework.dart';
import 'package:angel_seeder/angel_seeder.dart';
import 'package:test/test.dart';

main() {
  test('create one', () async {
    var app = new Angel()..use('/todos', new TodoService());

    await app.configure(seed(
        'todos',
        new SeederConfiguration<Todo>(delete: false, count: 10, template: {
          'text': (Faker faker) => 'Clean your room, ${faker.person.name()}!',
          'completed': false
        })));

    var todos = await app.findService('todos').index();
    print('Todos: \n${todos.map((todo) => "  - $todo").join("\n")}');

    expect(todos, isList);
    expect(todos, hasLength(10));
  });
}

class TodoService extends Service {
  final List<Todo> todos = [];

  @override
  index([params]) => myData();

  Future<List<Todo>> myData() {
    var completer = Completer<List<Todo>>();
    completer.complete(todos);
    return completer.future;
  }

  @override
  create(data, [params]) async {
    if (data is Todo) {
      todos.add(data..id = todos.length.toString());
      return data;
    } else if (data is Map) {
      todos.add(new Todo.fromJson(data)..id = todos.length.toString());
      return data;
    } else
      throw new AngelHttpException.badRequest();
  }
}

class Todo extends Model {
  final String text;
  final bool completed;

  Todo({String id, this.text, this.completed: false}) {
    this.id = id;
  }

  factory Todo.fromJson(Map data) => new Todo(
      id: data['id'], text: data['text'], completed: data['completed']);

  @override
  toString() => '${completed ? "Complete" : "Incomplete"}: $text';
}
