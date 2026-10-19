import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

/// The errors, and the generated code, of [builder] (by default
/// [jsonModelBuilder], whose output is of [extension]) of [source], a library
/// of the package `a`, with the other libraries [others], by their paths,
/// and the directives [imports] before its `part`.
Future<(List<String>, String)> generate(
  String source, {
  Builder? builder,
  String extension = 'angel3_serialize',
  Map<String, String> others = const {},
  String imports = '',
}) async {
  var readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();
  var errors = <String>[];
  await testBuilder(
    builder ?? jsonModelBuilder(BuilderOptions.empty),
    {
      'a|lib/model.dart':
          '''
import 'package:angel3_serialize/angel3_serialize.dart';
$imports
part 'model.g.dart';
$source
''',
      for (var MapEntry(:key, :value) in others.entries) 'a|lib/$key': value,
    },
    rootPackage: 'a',
    readerWriter: readerWriter,
    onLog: (log) {
      if (log.level.value >= 1000) errors.add('${log.message} ${log.error}');
    },
  );
  // A hidden output.
  var output = AssetId(
    'a',
    '.dart_tool/build/generated/a/lib/model.$extension.g.part',
  );
  return (
    errors,
    readerWriter.testing.exists(output)
        ? readerWriter.testing.readString(output)
        : '',
  );
}

void main() {
  test('reads a Serializers value given by another constant', () async {
    var (errors, output) = await generate('''
const js = Serializers.json;
@Serializable(serializers: [js])
abstract class _Model { String? get name; }
''');
    expect(errors, isEmpty);
    expect(output, contains('class Model'));
  });

  test('includes an enum value as an annotation', () async {
    var (errors, output) = await generate('''
enum Tag { a }
const tagged = Tag.a;
@Serializable(includeAnnotations: [Tag.a, tagged])
abstract class _Model { String? get name; }
''');
    expect(errors, isEmpty);
    // `tagged` too, as the value it is.
    expect('@Tag.a'.allMatches(output), hasLength(2));
    expect(output, isNot(contains('Tag.Tag.a')));
  });

  test('compares and hashes collections of any element type', () async {
    var (errors, output) = await generate('''
@serializable
abstract class _Model {
  List<int?>? get counts;
  List<void Function()>? get callbacks;
  Map<String, int?>? get scores;
}
''');
    expect(errors, isEmpty);
    expect(output, contains('ListEquality<int?>'));
    expect(output, contains('ListEquality<void Function()>'));
    expect(output, contains('MapEquality<String, int?>'));
    // Hashed by their lengths, which equal ones have, not by their contents,
    // which would recurse forever in a cycle of models.
    expect(output, contains('counts?.length'));
    expect(output, contains('scores?.length'));
    expect(output, isNot(contains('.hash(')));
  });

  test('includes a constant of a library imported with a prefix', () async {
    var (errors, output) = await generate(
      '''
@Serializable(includeAnnotations: [t.Tag.a, t.Ann()])
abstract class _Model { String? get name; }
''',
      imports: "import 'tags.dart' as t;",
      others: {
        'tags.dart': '''
enum Tag { a }
class Ann { const Ann(); }
''',
      },
    );
    expect(errors, isEmpty);
    expect(output, contains('@t.Tag.a'));
    expect(output, contains('@t.Ann()'));
  });

  test('generates no serializer of a model of typescript only', () async {
    // Its encoder and decoder would call a toMap and a fromMap it has not.
    var (errors, output) = await generate(
      '''
@Serializable(serializers: [Serializers.typescript])
abstract class _Model { String? get name; }
''',
      builder: serializerBuilder(BuilderOptions.empty),
      extension: 'angel3_serialize_serializer',
    );
    expect(errors, isEmpty);
    expect(output, isNot(contains('ModelSerializer')));
    expect(output, contains('ModelFields'));
  });

  test('hashes only a List or a Map by its length', () async {
    var (errors, output) = await generate('''
@serializable
abstract class _Model {
  void Function()? get callback;
  (int, int) get pair;
  dynamic get data;
  List<int> get counts;
}
''');
    expect(errors, isEmpty);
    expect(output, contains('callback,'));
    expect(output, contains('pair,'));
    expect(output, contains('data,'));
    expect(output, contains('counts.length'));
    for (var name in ['callback', 'pair', 'data']) {
      expect(output, isNot(contains('$name?.length')), reason: name);
      expect(output, isNot(contains('$name.length')), reason: name);
    }
  });

  test('refers to another model by the name of its class', () async {
    var (errors, output) = await generate(
      '''
@serializable
abstract class _EntityType { String? get name; }
@serializable
abstract class _Holder {
  _EntityType? get type;
  List<_EntityType>? get types;
  Map<String, _EntityType>? get byName;
  void Function()? get callback;
}
''',
      builder: serializerBuilder(BuilderOptions.empty),
      extension: 'angel3_serialize_serializer',
    );
    expect(errors, isEmpty);
    expect(output, contains('class EntityTypeSerializer'));
    // Of the class, `EntityType`, not `Type` of its name stripped again.
    expect(output, isNot(contains(RegExp(r'(?<!Entity)TypeSerializer\.'))));
    expect(
      'EntityTypeSerializer.toMap('.allMatches(output).length,
      greaterThanOrEqualTo(3),
    );
    expect(output, contains('EntityTypeSerializer.fromMap'));
  });

  test('generates no codec of a model of json only', () async {
    // Its decoder would call a fromMap, which is of map only.
    var (errors, output) = await generate(
      '''
@Serializable(serializers: [Serializers.json])
abstract class _Model { String? get name; }
''',
      builder: serializerBuilder(BuilderOptions.empty),
      extension: 'angel3_serialize_serializer',
    );
    expect(errors, isEmpty);
    expect(output, contains('abstract class ModelSerializer'));
    expect(output, contains('static Map<String, dynamic> toMap('));
    expect(output, isNot(contains('ModelDecoder')));
    expect(output, isNot(contains('fromMap(')));
  });

  test('prefixes a constant by the import it is visible by', () async {
    var (errors, output) = await generate(
      '''
class Ann { const Ann(); }
@Serializable(includeAnnotations: [u.Tag.a, x.Ann()])
abstract class _Model { String? get name; }
''',
      // `t` does not show Tag, and the library has an Ann of its own.
      imports: """
import 'tags.dart' as t show Other;
import 'tags.dart' as u;
import 'other.dart' as x;
""",
      others: {
        'tags.dart': 'enum Tag { a }\nclass Other {}\n',
        'other.dart': 'class Ann { const Ann(); }\n',
      },
    );
    expect(errors, isEmpty);
    expect(output, contains('@u.Tag.a'));
    expect(output, contains('@x.Ann()'));
  });

  group('getGeneratedModelClassName', () {
    test('strips a prefix, and then a suffix', () {
      for (var (clazz, name) in [
        ('_User', 'User'),
        ('UserEntity', 'User'),
        ('EntityUser', 'User'),
        ('_UserEntity', 'User'),
        ('_UserIdentityEntity', 'UserIdentity'),
      ]) {
        expect(getGeneratedModelClassName(clazz), name, reason: clazz);
      }
    });

    test('keeps a name that only ends with the letters of a suffix', () {
      for (var clazz in ['UserIdentity', 'Identity', 'Entity', 'entityUser']) {
        expect(getGeneratedModelClassName(clazz), clazz, reason: clazz);
      }
      expect(getGeneratedModelClassName('_UserIdentity'), 'UserIdentity');
    });
  });
}
