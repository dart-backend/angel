// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'using_components.dart';

// **************************************************************************
// JaelComponentGenerator
// **************************************************************************

mixin _MyAppJaelTemplate implements Component<dynamic> {
  @override
  DomNode render() {
    return h('div', {}, [
      h('h1', {}, [text('Welcome to my app')]),
      LabeledInput(name: "username")
    ]);
  }
}

mixin _LabeledInputJaelTemplate implements Component<dynamic> {
  String? get name;
  @override
  DomNode render() {
    return h('div', {}, [
      h('label', {}, [
        h('b', {}, [text(name.toString()), text(':')])
      ]),
      h('br', {}, []),
      h(
          'input',
          {'name': name, 'placeholder': "Enter ${name!}...", 'type': "text"},
          [])
    ]);
  }
}
