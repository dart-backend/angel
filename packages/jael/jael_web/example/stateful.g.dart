// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stateful.dart';

// **************************************************************************
// JaelComponentGenerator
// **************************************************************************

mixin _StatefulAppJaelTemplate implements Component<_AppState> {
  //Timer? get _timer;
  @override
  void beforeDestroy();

  @override
  DomNode render() {
    return h('div', {}, [text('Tick count: '), text(state.ticks.toString())]);
  }
}
