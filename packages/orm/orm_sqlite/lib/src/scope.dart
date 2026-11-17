import 'dart:async';

/// A transaction, or a savepoint of one, of an executor of SQLite.
class Scope {
  final Scope? parent;

  /// The context of `sqlite_async` that its statements run on, if any.
  Object? context;

  final Completer<void> done = Completer<void>();

  /// The queries and savepoints given in it that have not completed, which
  /// it waits for before it ends.
  final Set<Future<void>> running = {};

  /// The inserts given in it that have not completed, each of two
  /// statements, between which no savepoint of it may begin.
  final Set<Future<void>> inserts = {};

  bool ended = false;

  /// Whether SQLite rolled back the transaction, after an error, so that it
  /// runs no more statements, as they would run outside it.
  bool rolledBack = false;

  Scope(this.parent);

  Scope get root => parent?.root ?? this;

  /// Whether it is [other] or one of its savepoints.
  bool isWithin(Scope other) {
    for (Scope? s = this; s != null; s = s.parent) {
      if (identical(s, other)) return true;
    }
    return false;
  }
}

/// The transaction of a database and its savepoints, which all the executors
/// of the database share: the last of them runs, and the statements of the
/// others wait for it to end.
class Scopes {
  final List<Scope> _stack = [];

  /// The key of a scope in the zone of its callback.
  final Object _key = Object();

  /// Whether a statement outside a transaction waits for it to end, as on
  /// one connection, rather than running on a connection of its own.
  final bool outsideWaits;

  Scopes({required this.outsideWaits});

  Scope? get active => _stack.isEmpty ? null : _stack.last;

  bool get isEmpty => _stack.isEmpty;

  /// The scope that a statement given now runs in: that of the zone, if it is
  /// in [bound], as the code of a savepoint's callback runs in its zone, or
  /// else [bound], or `null` outside a transaction.
  ///
  /// Throws a [StateError] if [bound] has ended.
  Scope? current(Scope? bound) {
    var zone = Zone.current[_key];
    var zoneScope = zone is Scope && !zone.ended ? zone : null;
    if (bound == null) return zoneScope;
    if (bound.ended) {
      throw StateError('The transaction of this executor has ended.');
    }
    return zoneScope != null && zoneScope.isWithin(bound) ? zoneScope : bound;
  }

  /// What [scope] waits for to run a statement: the end of the last of the
  /// scopes, unless it is [scope], or, outside a transaction, of any if
  /// [outsideWaits]; or `null` if it may run one now.
  ///
  /// The caller starts its statement in the microtask of the check that
  /// gives `null`, with no `await` between, so that a savepoint cannot begin
  /// in between.
  Future<void>? blocker(Scope? scope) {
    var active = this.active;
    if (scope == null && !outsideWaits) return null;
    if (!identical(active, scope)) {
      if (active == null) {
        throw StateError('The transaction of this query has ended.');
      }
      return active.done.future;
    }
    if (scope != null && scope.root.rolledBack) {
      throw StateError(
        'SQLite rolled back the transaction after an error; it runs no more '
        'statements.',
      );
    }
    return null;
  }

  /// Runs [f] as one of the operations of [scope], which it waits for before
  /// it ends.
  Future<T> track<T>(Scope? scope, Future<T> Function() f) {
    if (scope == null) return f();
    var result = f();
    var done = result.then<void>((_) {}, onError: (_) {});
    scope.running.add(done);
    done.whenComplete(() => scope.running.remove(done));
    return result;
  }

  /// Begins [scope], as the last of the scopes.
  void push(Scope scope) => _stack.add(scope);

  /// Ends [scope].
  void end(Scope scope) {
    scope.ended = true;
    _stack.remove(scope);
    scope.done.complete();
  }

  /// Marks the transaction as rolled back, by SQLite.
  void markRolledBack() {
    if (_stack.isNotEmpty) _stack.first.rolledBack = true;
  }

  /// Runs [f] in the zone of [scope], in which a query given to any executor
  /// of the database runs in it.
  R runIn<R>(Scope scope, R Function() f) =>
      runZoned(f, zoneValues: {_key: scope});

  /// Waits for the operations given in [scope], and those they lead to, as
  /// the later steps of an operation of the ORM that was not awaited.
  Future<void> drain(Scope scope) async {
    do {
      await Future.wait(List.of(scope.running));
      await Future<void>.delayed(Duration.zero);
    } while (scope.running.isNotEmpty);
  }
}
