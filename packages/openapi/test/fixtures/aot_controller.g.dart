// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aot_controller.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final aotControllerReflection = ReflectionData(
  types: {
    ItemController: StaticReflectedClass(
      'ItemController',
      ItemController,
      parameters: [],
      create: (p, n) => ItemController(),
      annotations: [injectable, const Expose('/items')],
      methods: [
        StaticReflectedFunction(
          'read',
          [
            StaticReflectedParameter(
              'id',
              StaticReflectedType('int', _$typeOf<int>()),
              isRequired: true,
              isNamed: false,
              hasDefaultValue: false,
            ),
          ],
          annotations: [
            const Expose('/int:id'),
            const OpenApiOperation(
              summary: 'Read an item',
              responses: {200: OpenApiResponse('The item')},
            ),
          ],
        ),
      ],
      supertypes: [Controller],
      getMember: (o, name) => switch (name) {
        'read' => (o as ItemController).read,
        'app' => (o as ItemController).app,
        'injectSingleton' => (o as ItemController).injectSingleton,
        'middleware' => (o as ItemController).middleware,
        'routeMappings' => (o as ItemController).routeMappings,
        'mountPoint' => (o as ItemController).mountPoint,
        'expose' => (o as ItemController).expose,
        'configureServer' => (o as ItemController).configureServer,
        'applyRoutes' => (o as ItemController).applyRoutes,
        'routesMethod' => (o as ItemController).routesMethod,
        'configureRoutes' => (o as ItemController).configureRoutes,
        'findExpose' => (o as ItemController).findExpose,
        _ => noStaticMember,
      },
    ),
  },
);

Type _$typeOf<T>() => T;
