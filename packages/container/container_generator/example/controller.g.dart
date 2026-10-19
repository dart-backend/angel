// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'controller.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final controllerReflection = ReflectionData(
  types: {
    GreetController: StaticReflectedClass(
      'GreetController',
      GreetController,
      parameters: [],
      create: (p, n) => GreetController(),
      annotations: [injectable, const Expose('/greet')],
      methods: [
        StaticReflectedFunction('getHello', [
          StaticReflectedParameter(
            'name',
            StaticReflectedType('String', _$typeOf<String>()),
            isRequired: true,
            isNamed: false,
            hasDefaultValue: false,
          ),
        ]),
        StaticReflectedFunction(
          'shout',
          [
            StaticReflectedParameter(
              'text',
              StaticReflectedType('String', _$typeOf<String>()),
              isRequired: true,
              isNamed: false,
              hasDefaultValue: false,
              annotations: [const Query('text')],
            ),
          ],
          annotations: [const Expose('/shout')],
        ),
      ],
      getMember: (o, name) => switch (name) {
        'getHello' => (o as GreetController).getHello,
        'shout' => (o as GreetController).shout,
        'app' => (o as GreetController).app,
        'injectSingleton' => (o as GreetController).injectSingleton,
        'middleware' => (o as GreetController).middleware,
        'routeMappings' => (o as GreetController).routeMappings,
        'mountPoint' => (o as GreetController).mountPoint,
        'expose' => (o as GreetController).expose,
        'configureServer' => (o as GreetController).configureServer,
        'applyRoutes' => (o as GreetController).applyRoutes,
        'configureRoutes' => (o as GreetController).configureRoutes,
        'findExpose' => (o as GreetController).findExpose,
        _ => noStaticMember,
      },
    ),
  },
);

Type _$typeOf<T>() => T;
