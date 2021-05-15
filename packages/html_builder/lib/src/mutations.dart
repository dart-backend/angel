import 'node.dart';
import 'node_builder.dart';

/// Returns a function that rebuilds an arbitrary [Node] by applying the [transform] to it.
Node Function(Node) rebuild(NodeBuilder Function(NodeBuilder) transform,
    {bool selfClosing = false}) {
  return (node) =>
      transform(NodeBuilder.from(node)).build(selfClosing: selfClosing);
}

/// Applies [f] to all children of this node, recursively.
///
/// Use this alongside [rebuild].
Node Function(Node) rebuildRecursive(Node Function(Node) f) {
  Node _build(Node node) {
    return NodeBuilder.from(f(node)).mapChildren(_build).build();
  }

  return _build;
}
