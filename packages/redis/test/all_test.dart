import 'dart:io';

import 'package:angel3_http_exception/angel3_http_exception.dart';
import 'package:angel3_redis/angel3_redis.dart';
import 'package:resp_client/resp_client.dart';
import 'package:resp_client/resp_commands.dart';
import 'package:resp_client/resp_server.dart';
import 'package:test/test.dart';

void main() async {
  late RespServerConnection connection;
  late RedisService service;

  setUp(() async {
    var env = Platform.environment;
    connection = await connectSocket(
      env['REDIS_HOST'] ?? 'localhost',
      port: int.parse(env['REDIS_PORT'] ?? '6379'),
    );
    service = RedisService(
      RespCommandsTier2(RespClient(connection)),
      prefix: 'angel_redis_test',
    );
  });

  tearDown(() => connection.close());

  test('index', () async {
    // Wipe
    await service.respCommands.flushDb();
    await service.create({'id': '0', 'name': 'Tobe'});
    await service.create({'id': '1', 'name': 'Osakwe'});

    var output = await service.index();
    expect(
      output,
      unorderedEquals([
        <String, dynamic>{'id': '0', 'name': 'Tobe'},
        <String, dynamic>{'id': '1', 'name': 'Osakwe'},
      ]),
    );
  });

  test('index ignores id counter and other prefixes', () async {
    await service.respCommands.flushDb();
    await service.create({'name': 'generated'});
    await service.respCommands.set('angel_redis_testx:1', '{"id":"1"}');
    await service.respCommands.set('angel_redis_test:raw', 'not json');

    var output = await service.index();
    expect(output, hasLength(1));
    expect(output.single, containsPair('name', 'generated'));
  });

  test('index with glob characters in prefix', () async {
    await service.respCommands.flushDb();
    var globService = RedisService(service.respCommands, prefix: 'a?');
    await globService.create({'id': '1'});
    await service.respCommands.set('ab:2', '{"id":"2"}');
    expect(await globService.index(), [
      <String, dynamic>{'id': '1'},
    ]);
  });

  test('create with id', () async {
    var input = {'id': 'foo', 'bar': 'baz'};
    var output = await service.create(input);
    expect(input, output);
  });

  test('create with existing id', () async {
    await service.respCommands.flushDb();
    await service.create({'id': 'dup', 'n': 1});
    expect(
      () => service.create({'id': 'dup', 'n': 2}),
      throwsA(const TypeMatcher<AngelHttpException>()),
    );
  });

  test('record id cannot clobber the id counter', () async {
    await service.respCommands.flushDb();
    await service.create({'id': 'angel_redis:id', 'x': 1});
    await service.update('angel_redis:id', {'x': 2});
    var output = await service.create({'name': 'generated'});
    expect(output['id'], '1');
  });

  test('non-object values are not records', () async {
    await service.respCommands.set('angel_redis_test:raw', '42');
    for (var call in [
      () => service.read('raw'),
      () => service.modify('raw', {'x': 1}),
      () => service.remove('raw'),
    ]) {
      await expectLater(
        call,
        throwsA(
          isA<AngelHttpException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    }
    expect(await service.respCommands.get('angel_redis_test:raw'), '42');
  });

  test('rejects invalid options', () {
    expect(
      () => RedisService(service.respCommands, batchSize: 0),
      throwsRangeError,
    );
    expect(
      () => RedisService(service.respCommands, maxWriteAttempts: 0),
      throwsRangeError,
    );
  });

  test('create with non-string id', () async {
    await service.respCommands.flushDb();
    var output = await service.create({'id': 5});
    expect(output, {'id': '5'});
    expect(await service.read('5'), output);
  });

  test('create without id skips taken ids', () async {
    await service.respCommands.flushDb();
    await service.create({'id': '1', 'owner': 'client'});
    var output = await service.create({'owner': 'generated'});
    expect(output['id'], isNot('1'));
    expect(await service.read('1'), {'id': '1', 'owner': 'client'});
  });

  test('create without id', () async {
    var input = {'bar': 'baz'};
    var output = await (service.create(input));
    print(output);
    expect(output.keys, contains('id'));
    expect(output, containsPair('bar', 'baz'));
  });

  test('read', () async {
    var id = 'poobah${DateTime.now().millisecondsSinceEpoch}';
    var input = await service.create({'id': id, 'bar': 'baz'});
    expect(await service.read(id), input);
  });

  test('modify', () async {
    var id = 'jamboree${DateTime.now().millisecondsSinceEpoch}';
    await service.create({'id': id, 'bar': 'baz', 'yes': 'no'});
    var output = await service.modify(id, {'bar': 'quux'});
    expect(output, {'id': id, 'bar': 'quux', 'yes': 'no'});
    expect(await service.read(id), output);
  });

  test('update', () async {
    var id = 'hoopla${DateTime.now().millisecondsSinceEpoch}';
    await service.create({'id': id, 'bar': 'baz'});
    var output = await service.update(id, {'yes': 'no'});
    expect(output, {'id': id, 'yes': 'no'});
    expect(await service.read(id), output);
  });

  test('remove', () async {
    var id = 'gelatin${DateTime.now().millisecondsSinceEpoch}';
    var input = await service.create({'id': id, 'bar': 'baz'});
    expect(await service.remove(id), input);
    expect(await service.respCommands.exists(['angel_redis_test:$id']), 0);
  });

  test('concurrent remove and read', () async {
    await service.respCommands.flushDb();
    await service.create({'id': 'a'});
    await service.create({'id': 'b'});
    var results = await Future.wait([service.remove('a'), service.read('b')]);
    expect(results, [
      {'id': 'a'},
      {'id': 'b'},
    ]);
  });

  test('concurrent modify keeps both changes', () async {
    await service.respCommands.flushDb();
    await service.create({'id': 'm'});
    await Future.wait([
      service.modify('m', {'x': 1}),
      service.modify('m', {'y': 2}),
    ]);
    expect(await service.read('m'), {'id': 'm', 'x': 1, 'y': 2});
  });

  test('remove nonexistent', () async {
    expect(
      () => service.remove('definitely_does_not_exist'),
      throwsA(const TypeMatcher<AngelHttpException>()),
    );
  });
}
