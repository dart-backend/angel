// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'services.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final servicesReflection = ReflectionData(
  types: {
    Config: StaticReflectedClass(
      'Config',
      Config,
      parameters: [
        StaticReflectedParameter(
          'name',
          StaticReflectedType('String', _$typeOf<String>()),
          isRequired: false,
          isNamed: false,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(Config.new, p),
      annotations: [injectable],
    ),
    Logger: StaticReflectedClass(
      'Logger',
      Logger,
      parameters: [],
      create: (p, n) => Logger(),
      annotations: [injectable],
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
          'log',
          StaticReflectedType('Logger', _$typeOf<Logger>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'retries',
          StaticReflectedType('int', _$typeOf<int>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: true,
        ),
        StaticReflectedParameter(
          'queue',
          StaticReflectedType('col.Queue<int>', _$typeOf<col.Queue<int>>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Function.apply(
        Greeter.new,
        p,
        _$named(n, const {'log': #log, 'retries': #retries, 'queue': #queue}),
      ),
      annotations: [injectable],
    ),
    Mailer: StaticReflectedClass(
      'Mailer',
      Mailer,
      parameters: [
        StaticReflectedParameter(
          'config',
          StaticReflectedType('Config', _$typeOf<Config>()),
          isRequired: true,
          isNamed: true,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Mailer(config: n['config']),
      annotations: [injectable],
    ),
    Clock: StaticReflectedClass(
      'Clock',
      Clock,
      parameters: [],
      create: (p, n) => Clock(),
      annotations: [injectable],
      methods: [StaticReflectedFunction('now', [])],
      getMember: (o, name) => switch (name) {
        'now' => (o as Clock).now,
        _ => null,
      },
    ),
    Shape: StaticReflectedClass('Shape', Shape, annotations: [injectable]),
    Callbacks: StaticReflectedClass(
      'Callbacks',
      Callbacks,
      parameters: [
        StaticReflectedParameter(
          'onQueue',
          StaticReflectedType(
            'void Function(col.Queue<int>)',
            _$typeOf<void Function(col.Queue<int>)>(),
          ),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'pair',
          StaticReflectedType(
            '(int, {String s})',
            _$typeOf<(int, {String s})>(),
          ),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'single',
          StaticReflectedType('(int,)', _$typeOf<(int,)>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'handler',
          StaticReflectedType('Handler', _$typeOf<Handler>()),
          isRequired: false,
          isNamed: true,
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
      annotations: [injectable],
    ),
    Pay$Pal: StaticReflectedClass(
      'Pay\$Pal',
      Pay$Pal,
      parameters: [
        StaticReflectedParameter(
          'a\$b',
          StaticReflectedType('int', _$typeOf<int>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) =>
          Function.apply(Pay$Pal.new, p, _$named(n, const {'a\$b': #a$b})),
      annotations: [injectable],
    ),
    Sub: StaticReflectedClass(
      'Sub',
      Sub,
      parameters: [
        StaticReflectedParameter(
          'ids',
          StaticReflectedType('col.HashSet<int>', _$typeOf<col.HashSet<int>>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Sub(p[0]),
      annotations: [injectable],
    ),
    Limits: StaticReflectedClass(
      'Limits',
      Limits,
      parameters: [
        StaticReflectedParameter(
          'max',
          StaticReflectedType('int', _$typeOf<int>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) =>
          Function.apply(Limits.new, p, _$named(n, const {'max': #max})),
      annotations: [injectable],
    ),
    Labels: StaticReflectedClass(
      'Labels',
      Labels,
      parameters: [
        StaticReflectedParameter(
          'labels',
          StaticReflectedType('List<String>', _$typeOf<List<String>>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) =>
          Function.apply(Labels.new, p, _$named(n, const {'labels': #labels})),
      annotations: [injectable],
    ),
    Retrying: StaticReflectedClass(
      'Retrying',
      Retrying,
      parameters: [
        StaticReflectedParameter(
          'retries',
          StaticReflectedType('int', _$typeOf<int>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: true,
        ),
      ],
      create: (p, n) => Function.apply(
        Retrying.new,
        p,
        _$named(n, const {'retries': #retries}),
      ),
      annotations: [injectable],
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
