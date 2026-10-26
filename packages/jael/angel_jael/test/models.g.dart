// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// StaticReflectionGenerator
// **************************************************************************

/// How to construct, and reflect upon, the `@injectable` classes and functions of this library; pass it to [StaticReflector.combine].
final modelsReflection = ReflectionData(
  types: {
    Repo: StaticReflectedClass(
      'Repo',
      Repo,
      parameters: [
        StaticReflectedParameter(
          'name',
          StaticReflectedType('String', _$typeOf<String>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'stars',
          StaticReflectedType('int', _$typeOf<int>()),
          isRequired: true,
          isNamed: false,
          hasDefaultValue: false,
        ),
        StaticReflectedParameter(
          'id',
          StaticReflectedType('String', _$typeOf<String>()),
          isRequired: false,
          isNamed: true,
          hasDefaultValue: false,
        ),
      ],
      create: (p, n) =>
          Function.apply(Repo.new, p, _$named(n, const {'id': #id})),
      annotations: [injectable],
      supertypes: [Model],
      getMember: (o, name) => switch (name) {
        'name' => (o as Repo).name,
        'stars' => (o as Repo).stars,
        'popular' => (o as Repo).popular,
        'id' => (o as Repo).id,
        'createdAt' => (o as Repo).createdAt,
        'updatedAt' => (o as Repo).updatedAt,
        'idAsInt' => (o as Repo).idAsInt,
        'idAsString' => (o as Repo).idAsString,
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
