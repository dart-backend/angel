import 'dart:async';

import 'package:angel_framework/angel_framework.dart';
import 'package:angel_container/mirrors.dart';
import 'package:angel_seeder/angel_seeder.dart';
import 'package:test/test.dart';

void main() {
  test('create one', () async {
    var app = Angel(reflector: MirrorsReflector())
      ..use('/todos', TodoService());

    await app.configure(seed(
        'todos',
        SeederConfiguration<Todo>(delete: false, count: 10, template: {
          'text': (Faker faker) => 'Clean your room, ${faker.person.name()}!',
          'completed': false
        })));

    var todos = await app.findService('todos')!.index();
    print('Todos: \n${todos.map((todo) => "  - $todo").join("\n")}');

    expect(todos, isList);
    expect(todos, hasLength(10));
  });
}

class TodoService extends Service {
  final List<Todo> todos = [];

  @override
  Future<List<Todo>> index([params]) => myData();

  Future<List<Todo>> myData() {
    var completer = Completer<List<Todo>>();
    completer.complete(todos);
    return completer.future;
  }

  @override
  Future<Object> create(data, [params]) async {
    if (data is Todo) {
      todos.add(data..id = todos.length.toString());
      return data;
    } else if (data is Map) {
      todos.add(Todo.fromJson(data)..id = todos.length.toString());
      return data;
    } else {
      throw AngelHttpException.badRequest();
    }
  }
}

class Todo extends Model {
  final String? text;
  final bool? completed;

  Todo({String? id, this.text, this.completed: false}) {
    this.id = id;
  }

  factory Todo.fromJson(Map data) => Todo(
      id: data['id'] as String?,
      text: data['text'] as String?,
      completed: data['completed'] as bool?);

  @override
  String toString() => '${completed! ? "Complete" : "Incomplete"}: $text';
}
