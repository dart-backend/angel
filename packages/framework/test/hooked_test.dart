import 'dart:convert';
import 'dart:io';
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'common.dart';

void main() {
  Map headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };

  late Angel app;
  late HttpServer server;
  late String url;
  late http.Client client;
  late HookedService todoService;

  setUp(() async {
    app = Angel(reflector: MirrorsReflector());
    client = http.Client();
    app.use('/todos', MapService());
    app.use('/books', BookService());

    todoService = app.findHookedService<MapService>('todos')
        as HookedService<dynamic, dynamic, Service>;

    todoService.beforeAllStream().listen((e) {
      print('Fired ${e.eventName}! Data: ${e.data}; Params: ${e.params}');
    });

    app.errorHandler = (e, req, res) {
      throw e.error as Object;
    };

    server = await AngelHttp(app).startServer();
    url = 'http://${server.address.host}:${server.port}';
  });

  tearDown(() async {
    await server.close(force: true);
    client.close();
  });

  test('listen before and after', () async {
    var count = 0;

    todoService
      ..beforeIndexed.listen((_) {
        count++;
      })
      ..afterIndexed.listen((_) {
        count++;
      });

    var response = await client.get(Uri.parse('$url/todos'));
    print(response.body);
    expect(count, equals(2));
  });

  test('cancel before', () async {
    todoService.beforeCreated
      ..listen((HookedServiceEvent event) {
        event.cancel({'hello': 'hooked world'});
      })
      ..listen((HookedServiceEvent event) {
        event.cancel({'this_hook': 'should never run'});
      });

    var response = await client.post(Uri.parse('$url/todos'),
        body: json.encode({'arbitrary': 'data'}),
        headers: headers as Map<String, String>);
    print(response.body);
    var result = json.decode(response.body) as Map;
    expect(result['hello'], equals('hooked world'));
  });

  test('cancel after', () async {
    todoService.afterIndexed
      ..listen((HookedServiceEvent event) async {
        // Hooks can be Futures ;)
        event.cancel([
          {'angel': 'framework'}
        ]);
      })
      ..listen((HookedServiceEvent event) {
        event.cancel({'this_hook': 'should never run either'});
      });

    var response = await client.get(Uri.parse('$url/todos'));
    print(response.body);
    var result = json.decode(response.body) as List;
    expect(result[0]['angel'], equals('framework'));
  });

  test('asStream() fires', () async {
    var stream = todoService.afterCreated.asStream();
    await todoService.create({'angel': 'framework'});
    expect(await stream.first.then((e) => e.result['angel']), 'framework');
  });

  test('metadata', () async {
    final service = HookedService(IncrementService())..addHooks(app);
    expect(service.inner, isNot(const IsInstanceOf<MapService>()));
    IncrementService.times = 0;
    await service.index();
    expect(IncrementService.times, equals(2));
  });

  test('inject request + response', () async {
    var books = app.findService('books')
        as HookedService<dynamic, dynamic, Service<dynamic, dynamic>>;

    books.beforeIndexed.listen((e) {
      expect([e.request, e.response], everyElement(isNotNull));
      print('Indexing books at path: ${e.request?.path}');
    });

    var response = await client.get(Uri.parse('$url/books'));
    print(response.body);

    var result = json.decode(response.body);
    expect(result, isList);
    expect(result, isNotEmpty);
    expect(result[0], equals({'foo': 'bar'}));
  });

  test('contains provider in before and after', () async {
    var svc = HookedService(AnonymousService(index: ([p]) async => []));

    void ensureProviderIsPresent(HookedServiceEvent e) {
      var type = e.isBefore ? 'before' : 'after';
      print('Params to $type ${e.eventName}: ${e.params}');
      expect(e.params, isMap);
      expect(e.params.keys, contains('provider'));
      expect(e.params['provider'], const IsInstanceOf<Providers>());
    }

    svc
      ..beforeAll(ensureProviderIsPresent)
      ..afterAll(ensureProviderIsPresent);

    await svc.index({'provider': const Providers('testing')});
  });
}
