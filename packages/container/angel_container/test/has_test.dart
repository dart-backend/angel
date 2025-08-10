import 'package:angel3_container/angel3_container.dart';
import 'package:test/test.dart';

void main() {
  late Container container;

  setUp(() {
    container = Container(const EmptyReflector())
      ..registerSingleton<Song>(Song(title: 'I Wish'))
      ..registerNamedSingleton('foo', 1)
      ..registerFactory<Artist>((container) {
        return Artist(name: 'Stevie Wonder', song: container.make<Song>());
      });
  });

  test('hasNamed', () {
    var child = container.createChild()..registerNamedSingleton('bar', 2);
    expect(child.hasNamed('foo'), true);
    expect(child.hasNamed('bar'), true);
    expect(child.hasNamed('baz'), false);
  });

  test('has on singleton', () {
    var result = container.has<Song>();
    expect(result, true);
  });

  test('has on factory', () {
    expect(container.has<Artist>(), true);
  });

  test('false if neither', () {
    expect(container.has<bool>(), false);
  });
}

class Artist {
  final String? name;
  final Song? song;

  Artist({this.name, this.song});
}

class Song {
  final String? title;

  Song({this.title});
}
