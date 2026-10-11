import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_container_generator/angel3_container_generator.dart';
import 'package:test/test.dart';

import 'reflector_test.reflectable.dart';

void main() {
  initializeReflectable();

  var reflector = const GeneratedReflector();
  late Container container;

  setUp(() {
    container = Container(reflector);
    container.registerSingleton(Artist(name: 'Stevie Wonder'));
  });

  group('reflectClass', () {
    var mirror = reflector.reflectClass(Artist);

    test('name', () {
      expect(mirror.name, 'Artist');
    });
  });

  test('inject constructor parameters', () {
    var album = container.make<Album>();
    print(album.title);
    expect(album.title, 'flowers by stevie wonder');
  });

  test('getName returns the symbol name', () {
    expect(reflector.getName(#lowerName), 'lowerName');
  });

  test('declarations are methods, each with a function', () {
    var declarations = reflector.reflectClass(Artist).declarations;
    expect(declarations.map((d) => d.name), contains('lowerName'));
    expect(declarations.map((d) => d.name), isNot(contains('name')));
    for (var d in declarations) {
      expect(d.function, isNotNull, reason: d.name);
    }
  });

  test('reflects constructor parameter types', () {
    var constructor = reflector
        .reflectClass(Pokemon)
        .constructors
        .firstWhere((c) => c.name.isEmpty || c.name == 'Pokemon');
    var name = constructor.parameters.first;
    expect(name.name, 'name');
    expect(name.type.reflectedType, String);
  });

  group('getField', () {
    var blaziken = Pokemon('Blaziken', PokemonType.fire);

    test('returns values it cannot reflect', () {
      var field = reflector.reflectInstance(blaziken).getField('name');
      expect(field.reflectee, 'Blaziken');
    });

    test('returns method tear-offs', () {
      var field = reflector.reflectInstance(blaziken).getField('toString');
      expect((field.reflectee as Function)(), blaziken.toString());
    });
  });

  test('reports which parameters have a default value', () {
    var constructor = reflector.reflectClass(WithDefaults).constructors.single;
    expect(
      {for (var p in constructor.parameters) p.name: p.hasDefaultValue},
      {'artist': false, 'count': true},
    );
  });

  test('make keeps the default of an unregistered parameter', () {
    expect(container.make<WithDefaults>().count, 1);
  });

  // Skip as pkg:reflectable cannot reflect on closures at all (yet)
  //testReflector(reflector);
}

@contained
void returnVoidFromAFunction(int x) {}

void testReflector(Reflector reflector) {
  var blaziken = Pokemon('Blaziken', PokemonType.fire);
  late Container container;

  setUp(() {
    container = Container(reflector);
    container.registerSingleton(blaziken);
  });

  test('get field', () {
    var blazikenMirror = reflector.reflectInstance(blaziken)!;
    expect(blazikenMirror.getField('type').reflectee, blaziken.type);
  });

  group('reflectFunction', () {
    var mirror = reflector.reflectFunction(returnVoidFromAFunction);

    test('void return type returns dynamic', () {
      expect(mirror?.returnType, reflector.reflectType(dynamic));
    });

    test('counts parameters', () {
      expect(mirror?.parameters, hasLength(1));
    });

    test('counts types parameters', () {
      expect(mirror?.typeParameters, isEmpty);
    });

    test('correctly reflects parameter types', () {
      var p = mirror?.parameters[0];
      expect(p?.name, 'x');
      expect(p?.isRequired, true);
      expect(p?.isNamed, false);
      expect(p?.annotations, isEmpty);
      expect(p?.type, reflector.reflectType(int));
    });
  }, skip: 'pkg:reflectable cannot reflect on closures at all (yet)');

  test('make on singleton type returns singleton', () {
    expect(container.make(Pokemon), blaziken);
  });

  test('make with generic returns same as make with explicit type', () {
    expect(container.make<Pokemon>(), blaziken);
  });

  test('make on aliased singleton returns singleton', () {
    container.registerSingleton(blaziken, as: StateError);
    expect(container.make(StateError), blaziken);
  });

  test('constructor injects singleton', () {
    var lower = container.make<LowerPokemon>();
    expect(lower.lowercaseName, blaziken.name.toLowerCase());
  });

  test('newInstance works', () {
    var type = container.reflector.reflectType(Pokemon)!;
    var instance =
        type.newInstance('changeName', [blaziken, 'Charizard']).reflectee
            as Pokemon;
    print(instance);
    expect(instance.name, 'Charizard');
    expect(instance.type, PokemonType.fire);
  });

  test('isAssignableTo', () {
    var pokemonType = container.reflector.reflectType(Pokemon);
    var kantoPokemonType = container.reflector.reflectType(KantoPokemon)!;

    expect(kantoPokemonType.isAssignableTo(pokemonType), true);

    expect(
      kantoPokemonType.isAssignableTo(container.reflector.reflectType(String)),
      false,
    );
  });
}

@contained
class LowerPokemon {
  final Pokemon pokemon;

  LowerPokemon(this.pokemon);

  String get lowercaseName => pokemon.name.toLowerCase();
}

@contained
class Pokemon {
  final String name;
  final PokemonType type;

  Pokemon(this.name, this.type);

  factory Pokemon.changeName(Pokemon other, String name) {
    return Pokemon(name, other.type);
  }

  @override
  String toString() => 'NAME: $name, TYPE: $type';
}

@contained
class KantoPokemon extends Pokemon {
  KantoPokemon(super.name, super.type);
}

@contained
enum PokemonType { water, fire, grass, ice, poison, flying }

@contained
class Artist {
  final String name;

  Artist({required this.name});

  String get lowerName {
    return name.toLowerCase();
  }
}

@contained
class Album {
  final Artist artist;

  Album(this.artist);

  String get title => 'flowers by ${artist.lowerName}';
}

@contained
class AlbumLength {
  final Artist artist;
  final Album album;

  AlbumLength(this.artist, this.album);

  int get totalLength => artist.name.length + album.title.length;
}

@contained
class WithDefaults {
  final Artist artist;
  final int count;

  WithDefaults(this.artist, {this.count = 1});
}
