import 'node.dart';

/// Helper class to build nodes.
class NodeBuilder {
  final String tagName;
  final Map<String, dynamic> attributes;
  final Iterable<Node> children;
  Node? _existing;

  NodeBuilder(this.tagName,
      {this.attributes: const {}, this.children: const []});

  /// Creates a [NodeBuilder] that just spits out an already-existing [Node].
  factory NodeBuilder.existing(Node existingNode) =>
      NodeBuilder(existingNode.tagName).._existing = existingNode;

  factory NodeBuilder.from(Node node) => NodeBuilder(node.tagName,
      attributes: Map<String, dynamic>.from(node.attributes),
      children: List<Node>.from(node.children));

  /// Builds the node.
  Node build({bool selfClosing: false}) =>
      _existing ??
      (selfClosing
          ? SelfClosingNode(tagName, attributes)
          : Node(tagName, attributes, children));

  /// Produce a modified copy of this builder.
  NodeBuilder change(
      {String? tagName,
      Map<String, dynamic>? attributes,
      Iterable<Node>? children}) {
    return NodeBuilder(tagName ?? this.tagName,
        attributes: attributes ?? this.attributes,
        children: children ?? this.children);
  }

  NodeBuilder changeTagName(String tagName) => change(tagName: tagName);

  NodeBuilder changeAttributes(Map<String, dynamic> attributes) =>
      change(attributes: attributes);

  NodeBuilder changeChildren(Iterable<Node> children) =>
      change(children: children);

  NodeBuilder changeAttributesMapped(
      Map<String, dynamic> Function(Map<String, dynamic>) f) {
    var map = Map<String, dynamic>.from(attributes);
    return changeAttributes(f(map));
  }

  NodeBuilder changeChildrenMapped(Iterable<Node> Function(List<Node>) f) {
    var list = List<Node>.from(children);
    return changeChildren(f(list));
  }

  NodeBuilder mapChildren(Node Function(Node) f) =>
      changeChildrenMapped((list) => list.map(f));

  NodeBuilder mapAttributes(
          MapEntry<String, dynamic> Function(String, dynamic) f) =>
      changeAttributesMapped((map) => map.map(f));

  NodeBuilder setAttribute(String name, dynamic value) =>
      changeAttributesMapped((map) => map..[name] = value);

  NodeBuilder addChild(Node child) =>
      changeChildrenMapped((list) => list..add(child));

  NodeBuilder removeChild(Node child) =>
      changeChildrenMapped((list) => list..remove(child));

  NodeBuilder removeAttribute(String name) =>
      changeAttributesMapped((map) => map..remove(name));

  NodeBuilder setId(String id) => setAttribute('id', id);

  NodeBuilder setClassName(String className) =>
      setAttribute('class', className);

  NodeBuilder setClasses(Iterable<String> classes) =>
      setClassName(classes.join(' '));

  NodeBuilder setClassesMapped(Iterable<String> Function(List<String>) f) {
    var clazz = attributes['class'];
    var classes = <String>[];

    if (clazz is String)
      classes.addAll(clazz.split(' '));
    else if (clazz is Iterable) classes.addAll(clazz.map((s) => s.toString()));

    return setClasses(f(classes));
  }

  NodeBuilder addClass(String className) => setClassesMapped(
      (classes) => classes.contains(className) ? classes : classes
        ..add(className));

  NodeBuilder removeClass(String className) =>
      setClassesMapped((classes) => classes..remove(className));

  NodeBuilder toggleClass(String className) =>
      setClassesMapped((classes) => classes.contains(className)
          ? (classes..remove(className))
          : (classes..add(className)));
}
