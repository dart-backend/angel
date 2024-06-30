import 'package:angel3_client/angel3_client.dart' as c;
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_rethinkdb/angel3_rethinkdb.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:logging/logging.dart';
import 'package:belatuk_rethinkdb/belatuk_rethinkdb.dart';
import 'package:test/test.dart';
import 'common.dart';

void main() {
  Angel app;
  late TestClient client;
  RethinkDb r;
  late c.Service todoService;

  setUp(() async {
    r = RethinkDb();
    var conn = await r.connect();

    app = Angel();
    app.use('/todos', RethinkService(conn, r.table('todos')));

    app.errorHandler = (e, req, res) async {
      print('Whoops: $e');
    };

    app.logger = Logger.detached('angel')..onRecord.listen(print);

    client = await connectTo(app);
    todoService = client.service('todos');
  });

  tearDown(() => client.close());

  test('index', () async {
    var result = await todoService.index();
    print('Response: $result');
    expect(result, isList);
  });

  test('create+read', () async {
    var todo = Todo(title: 'Clean your room');
    var creation = await todoService.create(todo.toJson());
    print('Creation: $creation');

    var id = creation['id'];
    var result = await todoService.read(id);

    print('Response: $result');
    expect(result, isMap);
    expect(result['id'], equals(id));
    expect(result['title'], equals(todo.title));
    expect(result['completed'], equals(todo.completed));
  });

  test('modify', () async {
    var todo = Todo(title: 'Clean your room');
    var creation = await todoService.create(todo.toJson());
    print('Creation: $creation');

    var id = creation['id'];
    var result = await todoService.modify(id, {'title': 'Eat healthy'});

    print('Response: $result');
    expect(result, isMap);
    expect(result['id'], equals(id));
    expect(result['title'], equals('Eat healthy'));
    expect(result['completed'], equals(todo.completed));
  });

  test('remove', () async {
    var todo = Todo(title: 'Clean your room');
    var creation = await todoService.create(todo.toJson());
    print('Creation: $creation');

    var id = creation['id'];
    var result = await todoService.remove(id);

    print('Response: $result');
    expect(result, isMap);
    expect(result['id'], equals(id));
    expect(result['title'], equals(todo.title));
    expect(result['completed'], equals(todo.completed));
  });
}
