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
