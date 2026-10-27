// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final mainReflection = ReflectionData(
  types: {
    Config: StaticReflectedClass(
      'Config',
      Config,
      parameters: [
        StaticReflectedParameter(
          'greeting',
          StaticReflectedType('String', _$typeOf<String>()),
          isRequired: false,
          isNamed: false,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(Config.new, p),
      annotations: [injectable],
      getMember: (o, name) => switch (name) {
        'greeting' => (o as Config).greeting,
        _ => noStaticMember,
      },
    ),
    Greeter: StaticReflectedClass(
      'Greeter',
      Greeter,
      parameters: [
        StaticReflectedParameter(
          'config',
          StaticReflectedType('Config', _$typeOf<Config>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'punctuation',
          StaticReflectedType('String', _$typeOf<String>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(
        Greeter.new,
        p,
        _$named(n, const {'punctuation': #punctuation}),
      ),
      annotations: [injectable],
      methods: [
        StaticReflectedFunction('greet', [
          StaticReflectedParameter(
            'name',
            StaticReflectedType('String', _$typeOf<String>()),
            isRequired: true,
            isNamed: false,
            hasDefaultValue: false,
          ),
        ]),
      ],
      getMember: (o, name) => switch (name) {
        'config' => (o as Greeter).config,
        'punctuation' => (o as Greeter).punctuation,
        'greet' => (o as Greeter).greet,
        _ => noStaticMember,
      },
    ),
  },
);

Type _$typeOf<T>() => T;

/// The named arguments in [n] that the constructor takes.
Map<Symbol, dynamic> _$named(
  Map<String, dynamic> n,
  Map<String, Symbol> symbols,
) => {for (var e in n.entries) ?symbols[e.key]: e.value};
