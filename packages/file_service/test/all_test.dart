import 'dart:convert';

import 'package:angel3_file_service/angel3_file_service.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fs;
  late File dbFile;
  late JsonFileService service;

  setUp(() async {
    fs = MemoryFileSystem();
    dbFile = fs.file('db.json');
    service = JsonFileService(dbFile);

    await dbFile.writeAsString('''
    [
      {"id": "0", "foo": "bar"},
      {"id": "1", "foo": "baz"},
      {"id": "2", "foo": "quux"}
    ]
    ''');
  });

  tearDown(() => service.close());

  test('index no params', () async {
    expect(await service.index(), [
      {'id': '0', 'foo': 'bar'},
      {'id': '1', 'foo': 'baz'},
      {'id': '2', 'foo': 'quux'},
    ]);
  });

  test('index with query', () async {
    expect(
      await service.index({
        'query': {'foo': 'bar'},
      }),
      [
        {'id': '0', 'foo': 'bar'},
      ],
    );
  });

  test('read', () async {
    expect(await service.read('2'), {'id': '2', 'foo': 'quux'});
  });

  test('modify', () async {
    await service.modify('2', {'baz': 'quux'});
    expect(await service.read('2'), containsPair('baz', 'quux'));
    // A patch keeps the other fields.
    expect(await service.read('2'), containsPair('foo', 'quux'));
  });

  test('modify of a missing id is a 404, and creates nothing', () async {
    await expectLater(
      service.modify('9', {'baz': 'quux'}),
      throwsA(
        isA<AngelHttpException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
    expect(await service.index(), hasLength(3));
  });

  group('values are kept as JSON has them', () {
    test('a string that looks like a date stays a string', () async {
      await dbFile.writeAsString(
        json.encode([
          {'id': '20240101', 'code': '20241231'},
        ]),
      );
      expect(await service.read('20240101'), {
        'id': '20240101',
        'code': '20241231',
      });
    });

    test('a DateTime is stored, and returned, as its ISO string', () async {
      var due = DateTime.utc(2026, 10, 25);
      var created = await service.create({'due': due});
      expect(created['due'], due.toIso8601String());
      // Read again from the file, by another service.
      var other = JsonFileService(dbFile);
      addTearDown(other.close);
      expect(
        (await other.read(created['id'] as String))['due'],
        due.toIso8601String(),
      );
    });
  });

  test('writes at the same time are all kept', () async {
    // On a real file system, whose times change with each write, so that
    // another call would read the file again between a change and its save.
    await service.close();
    var dir = await const LocalFileSystem().systemTempDirectory.createTemp();
    addTearDown(() => dir.delete(recursive: true));
    dbFile = dir.childFile('db.json');
    await dbFile.writeAsString(
      json.encode([
        {'id': '0'},
        {'id': '1'},
        {'id': '2'},
      ]),
    );
    service = JsonFileService(dbFile);
    await Future.wait([
      for (var i = 0; i < 20; i++) service.create({'n': i}),
      for (var i = 0; i < 20; i++) service.index(),
    ]);
    expect(await service.index(), hasLength(23));
    var other = JsonFileService(dbFile);
    addTearDown(other.close);
    expect(await other.index(), hasLength(23));
  });

  test('a file changed by someone else is read again', () async {
    expect(await service.index(), hasLength(3));
    // With the same modification time, as within the resolution of a file
    // system's times: only its size tells.
    var modified = (await dbFile.stat()).modified;
    await dbFile.writeAsString(
      json.encode([
        {'id': '0', 'foo': 'edited'},
      ]),
    );
    await dbFile.setLastModified(modified);
    expect(await service.index(), [
      {'id': '0', 'foo': 'edited'},
    ]);
  });

  test('a file that is not a JSON list of objects is a 500', () async {
    await dbFile.writeAsString('[1, 2');
    await expectLater(
      service.index(),
      throwsA(
        isA<AngelHttpException>()
            .having((e) => e.statusCode, 'status', 500)
            // The path is in the error, which is logged, not in the message,
            // which the client gets.
            .having((e) => e.message, 'message', isNot(contains('db.json')))
            .having((e) => '${e.error}', 'error', contains('db.json')),
      ),
    );
  });

  test('allowRemoveAll or allowQuery with a store is an error', () {
    expect(
      () => JsonFileService(
        dbFile,
        allowRemoveAll: false,
        store: MapService(allowRemoveAll: true),
      ),
      throwsArgumentError,
    );
  });

  test('a record handed out shares nothing with the store', () async {
    var created = await service.create({
      'address': {'city': 'A'},
      'tags': ['a'],
    });
    (created['address'] as Map)['city'] = 'X';
    (created['tags'] as List).add('x');
    var read = await service.read(created['id'] as String);
    (read['address'] as Map)['city'] = 'Y';
    expect(
      await service.read(created['id'] as String),
      containsPair('address', {'city': 'A'}),
    );
    expect(
      await service.read(created['id'] as String),
      containsPair('tags', ['a']),
    );
    expect(await dbFile.readAsString(), isNot(contains('"X"')));
  });

  test('a value a store adds is saved as JSON has it', () async {
    var stamped = JsonFileService(dbFile, store: _StampingStore());
    addTearDown(stamped.close);
    var created = await stamped.create({'foo': 'new'});
    expect(created['stamp'], '2026-10-25T00:00:00.000Z');
    expect(await dbFile.readAsString(), contains('2026-10-25T00:00:00.000Z'));
  });

  test('a call after close is a StateError, as a future', () async {
    var other = JsonFileService(dbFile);
    await other.close();
    late Future<void> index;
    // Not thrown at once, so that catchError on the future catches it.
    expect(() => index = other.index(), returnsNormally);
    await expectLater(
      index,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('JsonFileService'),
        ),
      ),
    );
  });

  test('allowRemoveAll or allowQuery that a store has is no error', () {
    expect(
      () => JsonFileService(dbFile, allowQuery: true, store: MapService()),
      returnsNormally,
    );
  });

  test('a save leaves no file of its own next to the data file', () async {
    await service.create({'foo': 'saved'});
    expect(await fs.file('db.json.tmp').exists(), isFalse);
    expect(json.decode(await dbFile.readAsString()), hasLength(4));
  });

  test('a save that fails leaves the data file as it was', () async {
    var before = await dbFile.readAsString();
    // Where the save writes first, so that writing fails.
    await fs.directory('db.json.tmp').create();
    await expectLater(service.create({'foo': 'unsaved'}), throwsA(anything));
    expect(await dbFile.readAsString(), before);
    // Nor is the change served.
    await fs.directory('db.json.tmp').delete();
    expect(await service.index(), hasLength(3));
  });

  test('a store that throws after a change leaves none served', () async {
    var throwing = JsonFileService(dbFile, store: _ThrowingStore());
    addTearDown(throwing.close);
    await expectLater(throwing.create({'foo': 'half'}), throwsStateError);
    expect(await throwing.index(), hasLength(3));
  });

  test('a value with toJson is stored as its JSON', () async {
    var created = await service.create({'owner': _Owner('ann')});
    expect(created['owner'], {'name': 'ann'});
    expect(await dbFile.readAsString(), contains('"name":"ann"'));
  });

  test('close closes only a store the service made, once', () async {
    var given = _CountingStore();
    await JsonFileService(dbFile, store: given).close();
    expect(given.closed, 0);
    var own = JsonFileService(dbFile);
    // Again, it is the same close, so the store is closed once.
    expect(identical(own.close(), own.close()), isTrue);
    await own.close();
  });

  test('a missing file is made, as an empty list', () async {
    var missing = JsonFileService(fs.file('missing.json'));
    addTearDown(missing.close);
    expect(await missing.index(), isEmpty);
    expect(await fs.file('missing.json').readAsString(), '[]');
  });

  group('a save', () {
    test('writes a symlinked file through its link', () async {
      await fs.file('real.json').writeAsString('[]');
      await fs.link('linked.json').create('real.json');
      var linked = JsonFileService(fs.file('linked.json'));
      addTearDown(linked.close);
      await linked.create({'foo': 'through'});
      expect(await fs.isLink('linked.json'), isTrue);
      expect(await fs.file('real.json').readAsString(), contains('through'));
    });

    test('cut off as the file is written is restored from its copy', () async {
      var whole = json.encode([
        {'id': '0', 'foo': 'whole'},
      ]);
      await fs.file('db.json.tmp').writeAsString(whole);
      await dbFile.writeAsString(whole.substring(0, whole.length ~/ 2));
      expect(await service.index(), [
        {'id': '0', 'foo': 'whole'},
      ]);
      expect(await dbFile.readAsString(), whole);
      expect(await fs.file('db.json.tmp').exists(), isFalse);
    });

    test('cut off before the file is written leaves the file', () async {
      await fs.file('db.json.tmp').writeAsString(json.encode([]));
      expect(await service.index(), hasLength(3));
      expect(await fs.file('db.json.tmp').exists(), isFalse);
    });
  });

  group('a value JSON does not have is an error, and stores nothing', () {
    for (var (name, value) in <(String, Object)>[
      ('without toJson', Uri.parse('https://example.com')),
      ('with a toJson that throws', _BrokenOwner()),
    ]) {
      test(name, () async {
        await expectLater(
          service.create({'foo': value}),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        expect(await service.index(), hasLength(3));
      });
    }

    test('a cycle', () async {
      var cyclic = <String, dynamic>{};
      cyclic['self'] = cyclic;
      await expectLater(
        service.create(cyclic),
        throwsA(isA<JsonCyclicError>()),
      );
      expect(await service.index(), hasLength(3));
    });
  });

  test(
    'a value a store adds that JSON does not have serves no change',
    () async {
      var adding = JsonFileService(dbFile, store: _UriStore());
      addTearDown(adding.close);
      await expectLater(
        adding.create({'foo': 'new'}),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(await adding.index(), hasLength(3));
    },
  );

  test('records of index share nothing with the store', () async {
    await service.create({
      'address': {'city': 'A'},
    });
    var all = await service.index();
    (all.last['address'] as Map)['city'] = 'X';
    expect((await service.index()).last['address'], {'city': 'A'});
  });

  test('a 404 does not make the file be read again', () async {
    expect(await service.index(), hasLength(3));
    await expectLater(service.remove('9'), throwsA(isA<AngelHttpException>()));
    // An edit that keeps the size and the time, which only a read would see.
    var stat = await dbFile.stat();
    var contents = await dbFile.readAsString();
    await dbFile.writeAsString(contents.replaceFirst('bar', 'BAR'));
    await dbFile.setLastModified(stat.modified);
    expect((await service.read('0'))['foo'], 'bar');
  });

  test('close waits for a write in progress', () async {
    var other = JsonFileService(dbFile);
    var created = other.create({'last': true});
    await other.close();
    // Written by the time close completes.
    expect(await dbFile.readAsString(), contains('"last":true'));
    await created;
  });

  test('update', () async {
    await service.update('2', {'baz': 'quux'});
    expect(await service.read('2'), containsPair('baz', 'quux'));
    expect(await service.read('2'), isNot(containsPair('foo', 'quux')));
  });

  test('delete', () async {
    await service.remove('2');
    expect(await service.index(), [
      {'id': '0', 'foo': 'bar'},
      {'id': '1', 'foo': 'baz'},
    ]);
  });
}

/// A store that adds a value JSON does not have, a [DateTime].
class _StampingStore extends MapService {
  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) => super.create({...data, 'stamp': DateTime.utc(2026, 10, 25)}, params);
}

/// A store that adds a record, then throws.
class _ThrowingStore extends MapService {
  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) async {
    await super.create(data, params);
    throw StateError('failed after the change');
  }
}

class _Owner {
  final String name;
  _Owner(this.name);
  Map<String, dynamic> toJson() => {'name': name};
}

class _CountingStore extends MapService {
  int closed = 0;

  @override
  void close() => closed++;
}

/// A model whose toJson fails, as on a field that is null.
class _BrokenOwner {
  Map<String, dynamic> toJson() =>
      throw NoSuchMethodError.withInvocation(this, Invocation.getter(#name));
}

/// A store that adds a value JSON does not have, a [Uri].
class _UriStore extends MapService {
  @override
  Future<Map<String, dynamic>> create(
    Map<String, dynamic> data, [
    Map<String, dynamic>? params,
  ]) => super.create({...data, 'link': Uri.parse('https://example.com')});
}
