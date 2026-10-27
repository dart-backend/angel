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
      getMember: (o, name) => switch (name) {
        'name' => (o as Config).name,
        _ => noStaticMember,
      },
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
      getMember: (o, name) => switch (name) {
        'config' => (o as Greeter).config,
        'log' => (o as Greeter).log,
        'retries' => (o as Greeter).retries,
        'queue' => (o as Greeter).queue,
        _ => noStaticMember,
      },
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
      getMember: (o, name) => switch (name) {
        'config' => (o as Mailer).config,
        _ => noStaticMember,
      },
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
        _ => noStaticMember,
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
      getMember: (o, name) => switch (name) {
        'onQueue' => (o as Callbacks).onQueue,
        'pair' => (o as Callbacks).pair,
        'single' => (o as Callbacks).single,
        'handler' => (o as Callbacks).handler,
        _ => noStaticMember,
      },
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
      getMember: (o, name) => switch (name) {
        'a\$b' => (o as Pay$Pal).a$b,
        _ => noStaticMember,
      },
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
      supertypes: [Base],
      getMember: (o, name) => switch (name) {
        'ids' => (o as Sub).ids,
        _ => noStaticMember,
      },
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
      getMember: (o, name) => switch (name) {
        'max' => (o as Limits).max,
        _ => noStaticMember,
      },
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
      getMember: (o, name) => switch (name) {
        'labels' => (o as Labels).labels,
        _ => noStaticMember,
      },
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
      supertypes: [RetryBase],
      getMember: (o, name) => switch (name) {
        'retries' => (o as Retrying).retries,
        _ => noStaticMember,
      },
    ),
    Profile: StaticReflectedClass(
      'Profile',
      Profile,
      parameters: [
        StaticReflectedParameter(
          'ids',
          StaticReflectedType('col.HashSet<int>', _$typeOf<col.HashSet<int>>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => Profile(p[0]),
      annotations: [injectable],
      methods: [
        StaticReflectedFunction('shout', []),
        StaticReflectedFunction('revealed', []),
      ],
      supertypes: [Base],
      getMember: (o, name) => switch (name) {
        'name' => (o as Profile).name,
        'nickname' => (o as Profile).nickname,
        'greeting' => (o as Profile).greeting,
        'shout' => (o as Profile).shout,
        'revealed' => (o as Profile).revealed,
        'ids' => (o as Profile).ids,
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
