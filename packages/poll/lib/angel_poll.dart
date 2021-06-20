import 'dart:async';
import 'package:collection/collection.dart';
import 'package:angel_client/angel_client.dart';

/// A [Service] that facilitates real-time updates via the long polling of an [inner] service.
///
/// Works well with [ServiceList].
class PollingService extends Service {
  /// The underlying [Service] that does the actual communication with the server.
  final Service inner;

  /// Perform computations after polling to discern whether new items were created.
  final bool checkForCreated;

  /// Perform computations after polling to discern whether items were modified.
  final bool checkForModified;

  /// Perform computations after polling to discern whether items were removed.
  final bool checkForRemoved;

  /// An [EqualityBy] used to compare the ID's of two items.
  ///
  /// Defaults to comparing the [idField] of two `Map` instances.
  final EqualityBy compareId;

  /// An [Equality] used to discern whether two items, with the same [idField], are the same item.
  ///
  /// Defaults to [MapEquality], which deep-compares `Map` instances.
  final Equality compareItems;

  /// A [String] used as an index through which to compare `Map` instances.
  ///
  /// Defaults to `id`.
  final String idField;

  /// If `true` (default: `false`), then `index` events will be handled as a [Map] containing a `data` field.
  ///
  /// See https://github.com/angel-dart/paginate.
  final bool asPaginated;

  final List _items = [];
  final List<StreamSubscription> _subs = [];

  final StreamController<List<dynamic>> _onIndexed = StreamController(),
      _onRead = StreamController(),
      _onCreated = StreamController(),
      _onModified = StreamController(),
      _onUpdated = StreamController(),
      _onRemoved = StreamController();

  late Timer _timer;

  @override
  Angel get app => inner.app;

  @override
  Stream<List<dynamic>> get onIndexed => _onIndexed.stream;

  @override
  Stream get onRead => _onRead.stream;

  @override
  Stream get onCreated => _onCreated.stream;

  @override
  Stream get onModified => _onModified.stream;

  @override
  Stream get onUpdated => _onUpdated.stream;

  @override
  Stream get onRemoved => _onRemoved.stream;

  PollingService(this.inner, Duration interval,
      {this.checkForCreated = true,
      this.checkForModified = true,
      this.checkForRemoved = true,
      this.idField = 'id',
      this.asPaginated = false,
      EqualityBy? compareId,
      this.compareItems = const MapEquality()})
      : compareId = compareId ?? EqualityBy((map) => map[idField]) {
    _timer = Timer.periodic(interval, (_) {
      index().catchError((error) {
        _onIndexed.addError(error as Object);
      });
    });

    var streams = <Stream, StreamController>{
      inner.onRead: _onRead,
      inner.onCreated: _onCreated,
      inner.onModified: _onModified,
      inner.onUpdated: _onUpdated,
      inner.onRemoved: _onRemoved,
    };

    streams.forEach((stream, ctrl) {
      _subs.add(stream.listen(ctrl.add, onError: ctrl.addError));
    });

    _subs.add(
      inner.onIndexed.listen(
        _handleIndexed,
        onError: _onIndexed.addError,
      ),
    );
  }

  @override
  Future close() async {
    _timer.cancel();
    _subs.forEach((s) => s.cancel());
    await _onIndexed.close();
    await _onRead.close();
    await _onCreated.close();
    await _onModified.close();
    await _onUpdated.close();
    await _onRemoved.close();
  }

  // TODO: To revisit this logic
  @override
  Future<List<dynamic>> index([Map? params]) {
    return inner.index().then((data) {
      //return asPaginated == true ? data['data'] : data;
      //return asPaginated == true ? data[0] : data;
      return data!;
    });
  }

/*
  @override
  Future index([Map params]) {
  }
*/
  @override
  Future remove(id, [Map<String, dynamic>? params]) {
    return inner.remove(id, params).then((result) {
      _items.remove(result);
      return result;
    }).catchError(_onRemoved.addError);
  }

  dynamic _handleUpdate(result) {
    var index = -1;

    for (var i = 0; i < _items.length; i++) {
      if (compareId.equals(_items[i], result)) {
        index = i;
        break;
      }
    }

    if (index > -1) {
      _items[index] = result;
    }

    return result;
  }

  @override
  Future update(id, data, [Map<String, dynamic>? params]) {
    return inner
        .update(id, data, params)
        .then(_handleUpdate)
        .catchError(_onUpdated.addError);
  }

  @override
  Future modify(id, data, [Map<String, dynamic>? params]) {
    return inner
        .modify(id, data, params)
        .then(_handleUpdate)
        .catchError(_onModified.addError);
  }

  @override
  Future create(data, [Map<String, dynamic>? params]) {
    return inner.create(data, params).then((result) {
      _items.add(result);
      return result;
    }).catchError(_onCreated.addError);
  }

  @override
  Future read(id, [Map<String, dynamic>? params]) {
    return inner.read(id, params);
  }

  void _handleIndexed(List<dynamic> data) {
    //var items = asPaginated == true ? data['data'] : data;
    var items = data;
    var changesComputed = false;

    if (checkForCreated != false) {
      var newItems = <int, dynamic>{};

      for (var i = 0; i < items.length; i++) {
        var item = items[i];

        if (!_items.any((i) => compareId.equals(i, item))) {
          newItems[i] = item;
        }
      }

      newItems.forEach((index, item) {
        _items.insert(index, item);
        _onCreated.add([item]);
      });

      changesComputed = newItems.isNotEmpty;
    }

    if (checkForRemoved != false) {
      var removedItems = <int, dynamic>{};

      for (var i = 0; i < _items.length; i++) {
        var item = _items[i];

        if (!items.any((i) => compareId.equals(i, item))) {
          removedItems[i] = item;
        }
      }

      removedItems.forEach((index, item) {
        _items.removeAt(index);
        _onRemoved.add([item]);
      });

      changesComputed = changesComputed || removedItems.isNotEmpty;
    }

    if (checkForModified != false) {
      var modifiedItems = <int, dynamic>{};

      for (var item in items) {
        for (var i = 0; i < _items.length; i++) {
          var localItem = _items[i];

          if (compareId.equals(item, localItem)) {
            if (!compareItems.equals(item, localItem)) {
              modifiedItems[i] = item;
            }
            break;
          }
        }
      }

      modifiedItems.forEach((index, item) {
        _onModified.add([_items[index] = item]);
      });

      changesComputed = changesComputed || modifiedItems.isNotEmpty;
    }

    if (!changesComputed) {
      _items
        ..clear()
        ..add(items);
      _onIndexed.add([items]);
    }
  }
}
