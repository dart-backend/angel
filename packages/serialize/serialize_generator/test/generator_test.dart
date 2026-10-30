import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
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

/// The errors of compiling the library of [source], with the code that both
/// the model builder and the serializer builder generate of it as its part,
/// so that a test fails on generated code that does not compile, not only on
/// a builder's error.
Future<List<String>> compileErrors(
  String source, {
  String imports = '',
  Map<String, String> others = const {},
}) async {
  var (modelErrors, model) = await generate(
    source,
    imports: imports,
    others: others,
  );
  var (serializerErrors, serializer) = await generate(
    source,
    imports: imports,
    others: others,
    builder: serializerBuilder(BuilderOptions.empty),
    extension: 'angel3_serialize_serializer',
  );
  var errors = [...modelErrors, ...serializerErrors];
  if (errors.isNotEmpty) return errors;
  return resolveSources(
    {
      'a|lib/model.dart':
          '''
import 'package:angel3_serialize/angel3_serialize.dart';
$imports
part 'model.g.dart';
$source
''',
      'a|lib/model.g.dart': "part of 'model.dart';\n$model\n$serializer",
      for (var MapEntry(:key, :value) in others.entries) 'a|lib/$key': value,
    },
    (resolver) async {
      var library = await resolver.libraryFor(AssetId('a', 'lib/model.dart'));
      var result = await library.session.getResolvedLibraryByElement(library);
      if (result is! ResolvedLibraryResult) return ['Not resolved: $result'];
      return [
        for (var unit in result.units)
          for (var diagnostic in unit.diagnostics)
            if (diagnostic.severity == Severity.error)
              '${unit.uri}: ${diagnostic.message}',
      ];
    },
    readAllSourcesFromFilesystem: true,
    rootPackage: 'a',
  );
}

void main() {
  test('compiles the types of a library imported with a prefix', () async {
    var errors = await compileErrors(
      '''
@Serializable(includeAnnotations: [t.Ann(t.Tag.a)])
abstract class _Model {
  List<t.Tag>? get tags;
  Map<String, t.Tag>? get byName;
  t.Tag? get tag;
  void Function(t.Tag)? get callback;
  (int, t.Tag)? get pair;
}
''',
      imports: "import 'tags.dart' as t;",
      others: {
        'tags.dart':
            'enum Tag { a }\n'
            'class Ann<T> { final T value; const Ann(this.value); }\n',
      },
    );
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('compiles models of other names and serializers', () async {
    // A model that another deserializes has fromMap, which is of map.
    var errors = await compileErrors('''
@serializable
abstract class _URL { String? get href; }
@Serializable(serializers: [Serializers.json])
abstract class _Link { String? get text; }
@serializable
abstract class _Page {
  _URL? get url;
  List<_URL>? get links;
  Set<void Function()?>? get handlers;
  (int, String)? get pair;
  dynamic get data;
}
''');
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('compileErrors finds an error of the library', () async {
    // So that the tests of it fail on code that does not compile.
    var errors = await compileErrors('''
@serializable
abstract class _Model { String? get name; }
const int broken = 'not an int';
''');
    expect(errors, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('rejects two models of the same generated class', () async {
    var (errors, _) = await generate('''
@serializable
abstract class _User_Info { String? get name; }
@serializable
abstract class _UserInfo { String? get name; }
''');
    expect(errors.join(), contains('both generate the class UserInfo'));
  });

  test('generates a model without an unnamed constructor', () async {
    // The generated class implements a model of abstract fields, so it does
    // not call its constructor.
    var errors = await compileErrors('''
@serializable
abstract class _Point {
  _Point.origin();
  int? get x;
}
''');
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('rejects a model it extends without an unnamed constructor', () async {
    var (errors, _) = await generate('''
@serializable
abstract class _Todo extends Model {
  _Todo.named();
  String? get text;
}
''', imports: "import 'package:angel3_model/angel3_model.dart';");
    expect(
      errors.join(),
      contains('The model class _Todo needs an unnamed constructor'),
    );
  });

  test('compiles enum fields with and without a default', () async {
    var errors = await compileErrors('''
enum Color { red, green }
@serializable
abstract class _Paint {
  Color get color;
  Color? get maybe;
  @DefaultsTo(Color.green)
  Color? get withDefault;
}
''');
    expect(errors, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 3)));

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

  test('names the serializer of a model as its class is declared', () async {
    var source = '''
@serializable
abstract class _URL { String? get href; }
@serializable
abstract class _Page { _URL? get url; List<_URL>? get links; }
''';
    var (errors, output) = await generate(
      source,
      builder: serializerBuilder(BuilderOptions.empty),
      extension: 'angel3_serialize_serializer',
    );
    expect(errors, isEmpty);
    expect(output, contains('class UrlSerializer'));
    expect(output, contains('UrlSerializer.toMap('));
    expect(output, contains('UrlSerializer.fromMap'));
    expect(output, isNot(contains('URLSerializer')));
    // As the model class itself, of copyWith and fromMap.
    expect(output, contains('return Url('));
    (errors, output) = await generate(source);
    expect(errors, isEmpty);
    expect(output, contains('class Url '));
    expect(output, contains('Url copyWith('));
    expect(output, isNot(contains('URL(')));
  });

  test('writes the types of a library imported with a prefix', () async {
    var (errors, output) = await generate(
      '''
@Serializable(includeAnnotations: [t.Ann<int>(1)])
abstract class _Model { List<t.Tag>? get tags; }
''',
      imports: "import 'tags.dart' as t;",
      others: {
        'tags.dart': 'enum Tag { a }\nclass Ann<T> { final T value; const Ann(this.value); }\n',
      },
    );
    expect(errors, isEmpty);
    expect(output, contains('ListEquality<t.Tag>'));
    expect(output, contains('@t.Ann<int>(1)'));
  });

  test('keeps the nullability of a type argument in a cast', () async {
    var (errors, output) = await generate(
      '''
@serializable
abstract class _Model { Set<void Function()?>? get handlers; }
''',
      builder: serializerBuilder(BuilderOptions.empty),
      extension: 'angel3_serialize_serializer',
    );
    expect(errors, isEmpty);
    expect(output, contains('as Set<void Function()?>?'));
  });

  test(
    'rejects a value of an extension type, as of its representation',
    () async {
      // The analyzer gives `Tag(1)` the type `int`, as which it would be
      // generated, so it is rejected, not generated as `@1`.
      var (errors, _) = await generate('''
extension type const Tag(int value) {}
@Serializable(includeAnnotations: [Tag(1)])
abstract class _Model { String? get name; }
''');
      expect(errors.join(), contains('must be a constant instance of a class'));
    },
  );

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
