import 'router.dart';

/// A chain of arbitrary handlers obtained by routing a path.
class MiddlewarePipeline<T> {
  /// All the possible routes that matched the given path.
  final Iterable<RoutingResult<T>> routingResults;
  final List<T> _handlers = [];

  /// An ordered list of every handler delegated to handle this request.
  List<T> get handlers {
    /*
    if (_handlers != null) return _handlers;
    final handlers = <T>[];

    for (var result in routingResults) {
      handlers.addAll(result.allHandlers);
    }

    return _handlers = handlers;

    */
    if (_handlers.isNotEmpty) {
      return _handlers;
    }

    for (var result in routingResults) {
      _handlers.addAll(result.allHandlers);
    }

    return _handlers;
  }

  MiddlewarePipeline(Iterable<RoutingResult<T>> routingResults)
      : routingResults = routingResults.toList();
}

/// Iterates through a [MiddlewarePipeline].
class MiddlewarePipelineIterator<T> implements Iterator<RoutingResult<T>> {
  final MiddlewarePipeline<T> pipeline;
  final Iterator<RoutingResult<T>> _inner;

  MiddlewarePipelineIterator(this.pipeline)
      : _inner = pipeline.routingResults.iterator;

  @override
  RoutingResult<T> get current => _inner.current;

  @override
  bool moveNext() => _inner.moveNext();
}
