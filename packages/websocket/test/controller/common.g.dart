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
      getMember: (o, name) => switch (name) {
        'search' => (o as GameController).search,
        _ => null,
      },
    ),
  },
);

Type _$typeOf<T>() => T;
