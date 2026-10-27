import 'dart:async';
import 'dart:convert';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/file.dart';
import 'package:pool/pool.dart';

/// Persists in-memory changes to a file on disk, stored as a JSON list of
/// objects.
///
/// Values are kept as JSON has them: a [DateTime] given to [create],
/// [modify] or [update] is stored, and returned, as its ISO 8601 string. To
/// work with typed values, such as dates, convert them where the meaning of
/// a field is known, e.g. with a [TypedService] or a model's `fromMap`.
///
/// The file is read again when its modification time or its size changes,
/// so that most edits made outside of the service are picked up. One that
/// keeps the size, within the resolution of the file system's times, can be
/// missed, and overwritten by the next write.
class JsonFileService extends Service<String, Map<String, dynamic>> {
  FileStat? _lastStat;
  final Pool _mutex = Pool(1);
  bool _closed = false;
  Future<void>? _closing;
  late MapService _store;

  /// Whether the service made [_store], which it then closes.
  final bool _ownsStore;
  final File file;

  /// A service of [file], over [store], or else a [MapService] made with
  /// [allowRemoveAll] (`false` by default) and [allowQuery] (`true` by
  /// default). Those are set on a [store] itself, so passing one with a
  /// [store] that has another value throws an [ArgumentError].
  ///
  /// The service closes a store it made, not a [store] it is given.
  JsonFileService(
    this.file, {
    bool? allowRemoveAll,
    bool? allowQuery,
    MapService? store,
  }) : _ownsStore = store == null {
    if (store != null &&
        ((allowRemoveAll != null && allowRemoveAll != store.allowRemoveAll) ||
            (allowQuery != null && allowQuery != store.allowQuery))) {
      throw ArgumentError(
        'allowRemoveAll and allowQuery are set on the store, which has '
        'other values.',
      );
    }
    _store =
        store ??
        MapService(
          allowRemoveAll: allowRemoveAll ?? false,
          allowQuery: allowQuery ?? true,
        );
  }

  /// The full copy of the data that a save writes before it writes [file].
  File get _backup => file.parent.childFile('${file.basename}.tmp');

  /// Reads the file into the store, if it changed since it was last read or
  /// written. Called with [_mutex] held.
  Future<void> _load() async {
    var stat = await file.stat();
    if (stat.type == FileSystemEntityType.notFound) {
      await file.writeAsString(json.encode([]));
      stat = await file.stat();
    }
    var last = _lastStat;
    // Changed either way, as a file restored from a backup can be older.
    if (last != null &&
        stat.modified == last.modified &&
        stat.size == last.size) {
      return;
    }

    // An error reading it, such as a denied permission, is thrown as it is.
    var items = _decode(await file.readAsString());
    if (items == null) {
      // Cut off as it was written, if the backup of its save is whole.
      items = await _restore();
      stat = await file.stat();
    } else if (await _backup.exists()) {
      // Left by a save that was cut off before the file was written, or
      // after: the file is the one that is whole.
      await _deleteBackup();
    }
    _store.items
      ..clear()
      ..addAll(items);
    _lastStat = stat;
  }

  /// The records of [contents], or null if it is not a JSON list of
  /// objects.
  static List<Map<String, dynamic>>? _decode(String contents) {
    try {
      return [
        for (var item in json.decode(contents) as List)
          Map<String, dynamic>.from(item as Map),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Writes [file] again from the backup of a save that was cut off, and
  /// returns its records, or throws a 500 if there is none that is whole.
  Future<List<Map<String, dynamic>>> _restore() async {
    var backup = _backup;
    var items = await backup.exists()
        ? _decode(await backup.readAsString())
        : null;
    if (items == null) {
      // The server's file, not the request, is at fault. Its path is in the
      // error, which is logged, not in the message, which the client gets.
      throw AngelHttpException(
        message: 'The data of this service cannot be read.',
        error: FormatException(
          'The data file ${file.path} is not a JSON list of objects.',
        ),
      );
    }
    await file.writeAsString(await backup.readAsString(), flush: true);
    await _deleteBackup();
    return items;
  }

  Future<void> _deleteBackup() async {
    try {
      await _backup.delete();
    } catch (_) {
      // The next save writes it again.
    }
  }

  /// Writes the store to the file, and remembers the file as written, so
  /// that the next call does not read it again. Called with [_mutex] held.
  ///
  /// It writes a whole copy next to [file] first, then [file] in place, so
  /// that a mount, a symlink and the file's permissions stay as they are,
  /// and a save cut off as [file] is written, as by a full disk, is restored
  /// from the copy by the next call.
  ///
  /// If it fails, the file is read again by the next call, so that a change
  /// that was not saved is not served either.
  Future<void> _save() async {
    try {
      // As JSON has them, also values a store of its own may add, which
      // may fail as a write does.
      var contents = json.encode(_store.items, toEncodable: _toEncodable);
      await _backup.writeAsString(contents, flush: true);
      await file.writeAsString(contents, flush: true);
    } catch (_) {
      _lastStat = null;
      rethrow;
    }
    await _deleteBackup();
    try {
      _lastStat = await file.stat();
    } catch (_) {
      // Saved, so not a failure: the next call reads the file again.
      _lastStat = null;
    }
  }

  /// Runs [body] on the store read from the file, with [_mutex] held.
  Future<T> _read<T>(Future<T> Function() body) => _locked(() async {
    await _load();
    return body();
  });

  /// Runs [body] on the store read from the file, and writes the store
  /// back, all with [_mutex] held, so that no other call reads or writes the
  /// file in between and loses the change.
  Future<T> _write<T>(Future<T> Function() body) => _locked(() async {
    await _load();
    T result;
    try {
      result = await body();
    } on AngelHttpException {
      // Of the request, such as a 404, which changes nothing.
      rethrow;
    } catch (_) {
      // A store may have changed its records before it threw; read the
      // file again, rather than serve a change that is not saved.
      _lastStat = null;
      rethrow;
    }
    await _save();
    return result;
  });

  /// Runs [body] with [_mutex] held. After [close], it fails with a
  /// [StateError], as a future, not at once.
  Future<T> _locked<T>(Future<T> Function() body) async {
    if (_closed) {
      throw StateError('The JsonFileService of ${file.path} is closed.');
    }
    return _mutex.withResource(body);
  }

  /// Waits for the reads and writes in progress, then closes the store, if
  /// the service made it. Calls made after it fail with a [StateError].
  @override
  Future close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    await _mutex.close();
    if (_ownsStore) _store.close();
  }

  @override
  Future<List<Map<String, dynamic>>> index([
    Map<String, dynamic>? params,
  ]) async => [
    // Copied in one pass, rather than one per record.
    for (var record in json.decode(
      json.encode(
        await _read(() => _store.index(params)),
        toEncodable: _toEncodable,
      ),
    ) as List)
      record as Map<String, dynamic>,
  ];

  @override
  Future<Map<String, dynamic>> read(id, [Map<String, dynamic>? params]) async =>
      _jsonify(await _read(() => _store.read(id, params)));

  @override
  Future<Map<String, dynamic>> create(
    data, [
    Map<String, dynamic>? params,
  ]) async {
    // Before the store, so that a value JSON does not have fails here.
    var record = _jsonify(data);
    return _jsonify(await _write(() => _store.create(record, params)));
  }

  @override
  Future<Map<String, dynamic>> remove(
    id, [
    Map<String, dynamic>? params,
  ]) async => _jsonify(await _write(() => _store.remove(id, params)));

  @override
  Future<Map<String, dynamic>> update(
    id,
    data, [
    Map<String, dynamic>? params,
  ]) async {
    var record = _jsonify(data);
    return _jsonify(await _write(() => _store.update(id, record, params)));
  }

  @override
  Future<Map<String, dynamic>> modify(
    id,
    data, [
    Map<String, dynamic>? params,
  ]) async {
    var record = _jsonify(data);
    return _jsonify(await _write(() => _store.modify(id, record, params)));
  }
}

/// [value] as `json.encode` takes it: a [DateTime] as its ISO 8601 string,
/// any other value by its `toJson()`, as `json.encode` does by default.
Object? _toEncodable(Object? value) =>
    value is DateTime ? value.toIso8601String() : (value as dynamic).toJson();

/// [map] as JSON has it, so that the store holds what the file holds, as
/// `json.encode` makes it, which also reports a value it cannot encode, or a
/// cycle. The maps and lists are new ones, so this also copies a record
/// deeply, as a store copies only the record itself.
Map<String, dynamic> _jsonify(Map map) =>
    json.decode(json.encode(map, toEncodable: _toEncodable))
        as Map<String, dynamic>;
