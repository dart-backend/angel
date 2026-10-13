// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final appReflection = ReflectionData(
  types: {
    ItemController: StaticReflectedClass(
      'ItemController',
      ItemController,
      parameters: [],
      create: (p, n) => ItemController(),
      annotations: [injectable, const Expose('/items')],
      methods: [
        StaticReflectedFunction('getItem', [
          StaticReflectedParameter(
            'id',
            StaticReflectedType('int', _$typeOf<int>()),
            isRequired: true,
            isNamed: false,
            hasDefaultValue: false,
          ),
        ]),
        StaticReflectedFunction('putItem', [
          StaticReflectedParameter(
            'id',
            StaticReflectedType('int', _$typeOf<int>()),
            isRequired: true,
            isNamed: false,
            hasDefaultValue: false,
          ),
        ]),
        StaticReflectedFunction('deleteItem', [
          StaticReflectedParameter(
            'id',
            StaticReflectedType('int', _$typeOf<int>()),
            isRequired: true,
            isNamed: false,
            hasDefaultValue: false,
          ),
        ]),
        StaticReflectedFunction('posts', []),
        StaticReflectedFunction('headers', []),
        StaticReflectedFunction('getter', []),
        StaticReflectedFunction(
          'search',
          [
            StaticReflectedParameter(
              'q',
              StaticReflectedType('String', _$typeOf<String>()),
              isRequired: true,
              isNamed: false,
              hasDefaultValue: false,
              annotations: [const Query('q')],
            ),
          ],
          annotations: [const Expose('/search')],
        ),
        StaticReflectedFunction('hidden', [], annotations: [noExpose]),
      ],
      getMember: (o, name) => switch (name) {
        'getItem' => (o as ItemController).getItem,
        'putItem' => (o as ItemController).putItem,
        'deleteItem' => (o as ItemController).deleteItem,
        'posts' => (o as ItemController).posts,
        'headers' => (o as ItemController).headers,
        'getter' => (o as ItemController).getter,
        'search' => (o as ItemController).search,
        'hidden' => (o as ItemController).hidden,
        _ => null,
      },
    ),
    LimitsController: StaticReflectedClass(
      'LimitsController',
      LimitsController,
      parameters: [],
      create: (p, n) => LimitsController(),
      annotations: [injectable, const Expose('/limits')],
      methods: [
        StaticReflectedFunction(
          'max',
          [],
          annotations: [const Expose(LimitsController.maxPath)],
        ),
      ],
      getMember: (o, name) => switch (name) {
        'max' => (o as LimitsController).max,
        _ => null,
      },
    ),
    QueryService: StaticReflectedClass(
      'QueryService',
      QueryService,
      parameters: [],
      create: (p, n) => QueryService(),
      annotations: [
        injectable,
        const Middleware([interceptService]),
      ],
      methods: [
        StaticReflectedFunction(
          'read',
          [
            StaticReflectedParameter(
              'id',
              StaticReflectedType('dynamic', _$typeOf<dynamic>()),
              isRequired: true,
              isNamed: false,
              hasDefaultValue: false,
            ),
            StaticReflectedParameter(
              'params',
              StaticReflectedType('Map', _$typeOf<Map>()),
              isRequired: false,
              isNamed: false,
              hasDefaultValue: false,
            ),
          ],
          annotations: [
            const Middleware([interceptor]),
          ],
        ),
      ],
      getMember: (o, name) => switch (name) {
        'read' => (o as QueryService).read,
        _ => null,
      },
    ),
    CountedService: StaticReflectedClass(
      'CountedService',
      CountedService,
      parameters: [],
      create: (p, n) => CountedService(),
      annotations: [
        injectable,
        const Hooks(before: [countHook]),
      ],
      methods: [
        StaticReflectedFunction(
          'index',
          [
            StaticReflectedParameter(
              'params',
              StaticReflectedType(
                'Map<String, dynamic>',
                _$typeOf<Map<String, dynamic>>(),
              ),
              isRequired: false,
              isNamed: false,
              hasDefaultValue: false,
            ),
          ],
          annotations: [
            const Hooks(after: [countHook]),
          ],
        ),
      ],
      getMember: (o, name) => switch (name) {
        'index' => (o as CountedService).index,
        _ => null,
      },
    ),
  },
  functions: {
    annotatedHandler: StaticReflectedFunction(
      'annotatedHandler',
      [
        StaticReflectedParameter(
          'req',
          StaticReflectedType('RequestContext', _$typeOf<RequestContext>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'res',
          StaticReflectedType('ResponseContext', _$typeOf<ResponseContext>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
      ],
      annotations: [
        injectable,
        const Middleware([interceptor]),
      ],
    ),
    hello: StaticReflectedFunction(
      'hello',
      [
        StaticReflectedParameter(
          'name',
          StaticReflectedType('String', _$typeOf<String>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
      ],
      annotations: [injectable],
    ),
  },
);

Type _$typeOf<T>() => T;
