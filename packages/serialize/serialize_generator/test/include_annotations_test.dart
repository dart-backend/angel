import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

void main() {
  Future<List<String>> errorsFor(String includeAnnotations) async {
    var readerWriter = TestReaderWriter(rootPackage: 'a');
    await readerWriter.testing.loadIsolateSources();
    var errors = <String>[];
    await testBuilder(
      jsonModelBuilder(BuilderOptions.empty),
      {
        'a|lib/model.dart':
            '''
import 'package:angel3_serialize/angel3_serialize.dart';
part 'model.g.dart';
@Serializable(includeAnnotations: [$includeAnnotations])
abstract class _Model { String? get name; }
''',
      },
      rootPackage: 'a',
      readerWriter: readerWriter,
      onLog: (log) {
        if (log.level.value >= 1000) errors.add('${log.message} ${log.error}');
      },
    );
    return errors;
  }

  test('a constant instance of a class is accepted', () async {
    expect(await errorsFor("pragma('x')"), isEmpty);
  });

  test('a value that is not an annotation is rejected', () async {
    expect(
      (await errorsFor("'not an annotation'")).join(),
      contains('must be a constant instance of a class'),
    );
  });
}
