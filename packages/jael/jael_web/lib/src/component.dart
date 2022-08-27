import 'dom_node.dart';

abstract class Component<State> extends DomNode {
  late State state;

  DomNode render();

  void afterMount() {}

  void beforeDestroy() {}

  void setState(State newState) {}
}
