// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'common.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final commonReflection = ReflectionData(
  types: {
    GameController: StaticReflectedClass(
      'GameController',
      GameController,
      parameters: [
        StaticReflectedParameter(
          'ws',
          StaticReflectedType('AngelWebSocket', _$typeOf<AngelWebSocket>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => GameController(p[0]),
      annotations: [injectable, const Expose('/game')],
      methods: [
        StaticReflectedFunction(
          'search',
          [
            StaticReflectedParameter(
              'socket',
              StaticReflectedType(
                'WebSocketContext',
                _$typeOf<WebSocketContext>(),
              ),
              isRequired: true,
              isNamed: false,
              hasDefaultValue: false,
            ),
          ],
          annotations: [const ExposeWs('search')],
        ),
      ],
      supertypes: [WebSocketController, Controller],
      getMember: (o, name) => switch (name) {
        'search' => (o as GameController).search,
        'ws' => (o as GameController).ws,
        'broadcast' => (o as GameController).broadcast,
        'exposeWs' => (o as GameController).exposeWs,
        'configureWs' => (o as GameController).configureWs,
        'onConnect' => (o as GameController).onConnect,
        'onDisconnect' => (o as GameController).onDisconnect,
        'onAction' => (o as GameController).onAction,
        'onData' => (o as GameController).onData,
        'configureServer' => (o as GameController).configureServer,
        'routesMethod' => (o as GameController).routesMethod,
        'app' => (o as GameController).app,
        'injectSingleton' => (o as GameController).injectSingleton,
        'middleware' => (o as GameController).middleware,
        'routeMappings' => (o as GameController).routeMappings,
        'mountPoint' => (o as GameController).mountPoint,
        'expose' => (o as GameController).expose,
        'applyRoutes' => (o as GameController).applyRoutes,
        'configureRoutes' => (o as GameController).configureRoutes,
        'findExpose' => (o as GameController).findExpose,
        _ => noStaticMember,
      },
    ),
    SubGameController: StaticReflectedClass(
      'SubGameController',
      SubGameController,
      parameters: [
        StaticReflectedParameter(
          'ws',
          StaticReflectedType('AngelWebSocket', _$typeOf<AngelWebSocket>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) => SubGameController(p[0]),
      annotations: [injectable, const Expose('/sub')],
      supertypes: [GameController, WebSocketController, Controller],
      getMember: (o, name) => switch (name) {
        'search' => (o as SubGameController).search,
        'ws' => (o as SubGameController).ws,
        'broadcast' => (o as SubGameController).broadcast,
        'exposeWs' => (o as SubGameController).exposeWs,
        'configureWs' => (o as SubGameController).configureWs,
        'onConnect' => (o as SubGameController).onConnect,
        'onDisconnect' => (o as SubGameController).onDisconnect,
        'onAction' => (o as SubGameController).onAction,
        'onData' => (o as SubGameController).onData,
        'configureServer' => (o as SubGameController).configureServer,
        'routesMethod' => (o as SubGameController).routesMethod,
        'app' => (o as SubGameController).app,
        'injectSingleton' => (o as SubGameController).injectSingleton,
        'middleware' => (o as SubGameController).middleware,
        'routeMappings' => (o as SubGameController).routeMappings,
        'mountPoint' => (o as SubGameController).mountPoint,
        'expose' => (o as SubGameController).expose,
        'applyRoutes' => (o as SubGameController).applyRoutes,
        'configureRoutes' => (o as SubGameController).configureRoutes,
        'findExpose' => (o as SubGameController).findExpose,
        _ => noStaticMember,
      },
    ),
  },
);

Type _$typeOf<T>() => T;
