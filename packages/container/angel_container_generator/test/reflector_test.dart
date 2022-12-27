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

  testReflector(reflector);
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

  /*
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
  */

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

    var a = container.reflector.reflectType(String);

    expect(
        kantoPokemonType
            .isAssignableTo(container.reflector.reflectType(String)),
        false);
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
  KantoPokemon(String name, PokemonType type) : super(name, type);
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
