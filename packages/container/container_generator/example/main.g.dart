// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct the `@injectable` classes of this library; pass it to [StaticReflector.combine].
final mainReflection = ReflectionData(
  types: {
    Config: StaticReflectedClass(
      'Config',
      Config,
      parameters: [
        ReflectedParameter(
          'greeting',
          const [],
          StaticReflectedType('String', _$typeOf<String>()),
          false,
          false,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(Config.new, p),
    ),
    Greeter: StaticReflectedClass(
      'Greeter',
      Greeter,
      parameters: [
        ReflectedParameter(
          'config',
          const [],
          StaticReflectedType('Config', _$typeOf<Config>()),
          true,
          false,
          hasDefaultValue: false,
        ),
        ReflectedParameter(
          'punctuation',
          const [],
          StaticReflectedType('String', _$typeOf<String>()),
          false,
          true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(
        Greeter.new,
        p,
        _$named(n, const {'punctuation': #punctuation}),
      ),
    ),
  },
);

Type _$typeOf<T>() => T;

/// The named arguments in [n] that the constructor takes.
Map<Symbol, dynamic> _$named(
  Map<String, dynamic> n,
  Map<String, Symbol> symbols,
) => {
  for (var e in n.entries)
    if (symbols[e.key] case var s?) s: e.value,
};
