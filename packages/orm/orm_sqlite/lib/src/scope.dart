part of 'executors.dart';

/// A transaction, or a savepoint of one, of an executor of SQLite.
class _Scope {
  final _Scope? parent;

  /// The transaction it is of, or itself.
  late final _Scope root = parent?.root ?? this;

  /// The number of transactions and savepoints it is in.
  late final int depth = parent == null ? 0 : parent!.depth + 1;

  /// The transaction and its savepoints, of [root], the last of which runs:
  /// the statements of the others wait for it to end.
  late final List<_Scope> stack = parent == null ? [] : root.stack;

  /// The context of `sqlite_async` that its statements run on, if any.
  Object? context;

  final Completer<void> done = Completer<void>();

  /// The queries and savepoints given in it that have not completed, which
  /// it waits for before it ends.
  final Set<Future<void>> running = {};

  /// The statement of the transaction that runs, of [root], which the others
  /// wait for: of `sqlite_async`, whose statements are not synchronous, so
  /// that none runs after one that SQLite rolled the transaction back for,
  /// before the executor knows of it.
  Completer<void>? busy;

  bool ended = false;

  /// Whether SQLite rolled back the transaction, of [root], after an error,
  /// so that it runs no more statements, as they would run outside it.
  bool rolledBack = false;

  _Scope(this.parent);

  /// Whether it is [other] or one of its savepoints.
  bool isWithin(_Scope other) {
    for (_Scope? s = this; s != null; s = s.parent) {
      if (identical(s, other)) return true;
    }
    return false;
  }
}

/// The transactions of a database and their savepoints, which all the
/// executors of the database share.
class _Scopes {
  /// The transactions that run: one at a time if [outsideWaits].
  final Set<_Scope> _roots = {};

  /// The key of a scope in the zone of its callback.
  final Object _key = Object();

  /// Whether a statement outside a transaction, or another transaction,
  /// waits for it to end, as on one connection, rather than running on a
  /// connection of its own.
  final bool outsideWaits;

  _Scopes({required this.outsideWaits});

  /// The scope that a statement given now runs in: that of the zone, if it is
  /// in [bound], as the code of a savepoint's callback runs in its zone, or
  /// else [bound], or `null` outside a transaction.
  ///
  /// Throws a [StateError] if [bound] has ended.
  _Scope? current(_Scope? bound) {
    var zone = Zone.current[_key];
    // A savepoint that has ended, of a callback that runs later, as of a
    // timer, runs in the nearest that has not.
    var zoneScope = zone is _Scope ? zone : null;
    while (zoneScope != null && zoneScope.ended) {
      zoneScope = zoneScope.parent;
    }
    if (bound == null) return zoneScope;
    if (bound.ended) {
      throw StateError('The transaction of this executor has ended.');
    }
    return zoneScope != null && zoneScope.isWithin(bound) ? zoneScope : bound;
  }

  /// What [scope] waits for to run a statement, or `null` if it may run one
  /// now: the end of the last savepoint of its transaction, unless it is
  /// [scope], and of the statement of the transaction that runs; or, outside
  /// a transaction, the end of the one that runs, if [outsideWaits].
  Future<void>? _blocker(_Scope? scope) {
    if (scope == null) {
      return outsideWaits && _roots.isNotEmpty
          ? _roots.first.done.future
          : null;
    }
    if (scope.ended) {
      throw StateError('The transaction of this query has ended.');
    }
    var active = scope.stack.last;
    if (!identical(active, scope)) return active.done.future;
    if (scope.root.busy case var busy?) return busy.future;
    if (scope.root.rolledBack) throw _rolledBack('it runs no more statements');
    return null;
  }

  /// Calls [start] once [scope] may run a statement, in the microtask of the
  /// check, with no `await` between, so that a savepoint cannot begin in
  /// between, and returns what it returns.
  Future<T> whenReady<T>(_Scope? scope, FutureOr<T> Function() start) async {
    for (var b = _blocker(scope); b != null; b = _blocker(scope)) {
      await b;
    }
    return start();
  }

  /// Runs [statements] as the one statement of the transaction of [scope]
  /// that runs, which the others wait for.
  Future<T> hold<T>(_Scope? scope, Future<T> Function() statements) async {
    if (scope == null) return statements();
    var busy = scope.root.busy = Completer<void>();
    try {
      return await statements();
    } finally {
      scope.root.busy = null;
      busy.complete();
    }
  }

  /// Waits until no transaction runs.
  Future<void> whenIdle() async {
    while (_roots.isNotEmpty) {
      await _roots.first.done.future;
    }
  }

  /// Runs [f] as one of the operations of [scope], which it waits for before
  /// it ends.
  Future<T> track<T>(_Scope? scope, Future<T> Function() f) {
    if (scope == null) return f();
    var result = f();
    var done = result.then<void>((_) {}, onError: (_) {});
    scope.running.add(done);
    done.whenComplete(() => scope.running.remove(done));
    return result;
  }

  /// Begins [scope], as the last savepoint of its transaction.
  void push(_Scope scope) {
    scope.stack.add(scope);
    if (scope.parent == null) _roots.add(scope);
  }

  /// Ends [scope].
  void end(_Scope scope) {
    scope.ended = true;
    scope.stack.remove(scope);
    _roots.remove(scope);
    scope.done.complete();
  }

  /// Runs [f] in the zone of [scope], in which a query given to any executor
  /// of the database runs in it.
  R runIn<R>(_Scope scope, R Function() f) =>
      runZoned(f, zoneValues: {_key: scope});

  /// Waits for the operations given in [scope], and those they lead to, as
  /// the later steps of an operation of the ORM that was not awaited.
  ///
  /// It returns at once if none is running, as when the callback of the
  /// scope awaited them, as the ORM does.
  Future<void> drain(_Scope scope) async {
    while (scope.running.isNotEmpty) {
      await Future.wait(List.of(scope.running));
      // The steps that follow those, which their callbacks give.
      await Future<void>.delayed(Duration.zero);
    }
  }
}

/// The error of a statement, or a commit, of a transaction that SQLite rolled
/// back after an error.
StateError _rolledBack(String consequence) => StateError(
  'SQLite rolled back the transaction after an error; $consequence.',
);
