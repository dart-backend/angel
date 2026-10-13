// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct the `@injectable` classes of this library; pass it to [StaticReflector.combine].
final servicesReflection = ReflectionData(
  types: {
    Config: StaticReflectedClass(
      'Config',
      Config,
      parameters: [
        ReflectedParameter(
          'name',
          const [],
          StaticReflectedType('String', _$typeOf<String>()),
          false,
          false,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(Config.new, p),
    ),
    Logger: StaticReflectedClass(
      'Logger',
      Logger,
      parameters: [],
      create: (p, n) => Logger(),
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
          'log',
          const [],
          StaticReflectedType('Logger', _$typeOf<Logger>()),
          false,
          true,
          hasDefaultValue: false,
        ),
        ReflectedParameter(
          'retries',
          const [],
          StaticReflectedType('int', _$typeOf<int>()),
          false,
          true,
          hasDefaultValue: true,
        ),
        ReflectedParameter(
          'queue',
          const [],
          StaticReflectedType('col.Queue<int>', _$typeOf<col.Queue<int>>()),
          false,
          true,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Function.apply(
        Greeter.new,
        p,
        _$named(n, const {'log': #log, 'retries': #retries, 'queue': #queue}),
      ),
    ),
    Mailer: StaticReflectedClass(
      'Mailer',
      Mailer,
      parameters: [
        ReflectedParameter(
          'config',
          const [],
          StaticReflectedType('Config', _$typeOf<Config>()),
          true,
          true,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Mailer(config: n['config']),
    ),
    Clock: StaticReflectedClass(
      'Clock',
      Clock,
      parameters: [],
      create: (p, n) => Clock(),
    ),
    Shape: StaticReflectedClass('Shape', Shape),
    Callbacks: StaticReflectedClass(
      'Callbacks',
      Callbacks,
      parameters: [
        ReflectedParameter(
          'onQueue',
          const [],
          StaticReflectedType(
            'void Function(col.Queue<int>)',
            _$typeOf<void Function(col.Queue<int>)>(),
          ),
          false,
          true,
          hasDefaultValue: false,
        ),
        ReflectedParameter(
          'pair',
          const [],
          StaticReflectedType(
            '(int, {String s})',
            _$typeOf<(int, {String s})>(),
          ),
          false,
          true,
          hasDefaultValue: false,
        ),
        ReflectedParameter(
          'single',
          const [],
          StaticReflectedType('(int,)', _$typeOf<(int,)>()),
          false,
          true,
          hasDefaultValue: false,
        ),
        ReflectedParameter(
          'handler',
          const [],
          StaticReflectedType('Handler', _$typeOf<Handler>()),
          false,
          true,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Function.apply(
        Callbacks.new,
        p,
        _$named(n, const {
          'onQueue': #onQueue,
          'pair': #pair,
          'single': #single,
          'handler': #handler,
        }),
      ),
    ),
    Pay$Pal: StaticReflectedClass(
      'Pay\$Pal',
      Pay$Pal,
      parameters: [
        ReflectedParameter(
          'a\$b',
          const [],
          StaticReflectedType('int', _$typeOf<int>()),
          false,
          true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) =>
          Function.apply(Pay$Pal.new, p, _$named(n, const {'a\$b': #a$b})),
    ),
    Sub: StaticReflectedClass(
      'Sub',
      Sub,
      parameters: [
        ReflectedParameter(
          'ids',
          const [],
          StaticReflectedType('col.HashSet<int>', _$typeOf<col.HashSet<int>>()),
          true,
          false,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Sub(p[0]),
    ),
    Limits: StaticReflectedClass(
      'Limits',
      Limits,
      parameters: [
        ReflectedParameter(
          'max',
          const [],
          StaticReflectedType('int', _$typeOf<int>()),
          false,
          true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) =>
          Function.apply(Limits.new, p, _$named(n, const {'max': #max})),
    ),
    Labels: StaticReflectedClass(
      'Labels',
      Labels,
      parameters: [
        ReflectedParameter(
          'labels',
          const [],
          StaticReflectedType('List<String>', _$typeOf<List<String>>()),
          false,
          true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) =>
          Function.apply(Labels.new, p, _$named(n, const {'labels': #labels})),
    ),
    Retrying: StaticReflectedClass(
      'Retrying',
      Retrying,
      parameters: [
        ReflectedParameter(
          'retries',
          const [],
          StaticReflectedType('int', _$typeOf<int>()),
          false,
          true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(
        Retrying.new,
        p,
        _$named(n, const {'retries': #retries}),
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
