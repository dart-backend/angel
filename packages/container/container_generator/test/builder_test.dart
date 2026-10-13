import 'package:angel3_container_generator/angel3_container_generator.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

void main() {
  /// Runs the builder on `lib/input.dart` with [source] (and [others]),
  /// returning the error messages it logged and whether it produced an output.
  Future<(List<String>, bool)> build(
    String source, [
    Map<String, String> others = const {},
  ]) async {
    var readerWriter = TestReaderWriter(rootPackage: 'a');
    await readerWriter.testing.loadIsolateSources();
    var errors = <String>[];
    var result = await testBuilder(
      staticReflectionBuilder(BuilderOptions.empty),
      {'a|lib/input.dart': source, ...others},
      generateFor: {'a|lib/input.dart'},
      rootPackage: 'a',
      readerWriter: readerWriter,
      onLog: (log) {
        if (log.level.value >= 1000) {
          errors.add('${log.message} ${log.error ?? ''}');
        }
      },
    );
    var output = result.outputs.any((id) => id.path.endsWith('.g.part'));
    return (errors, output);
  }

  const header = '''
import 'package:angel3_container/angel3_container.dart';
part 'input.g.dart';
''';

  test('a library with an @injectable class gets output', () async {
    var (errors, output) = await build('$header@injectable class A {}');
    expect(errors, isEmpty);
    expect(output, isTrue);
  });

  test('a library without @injectable classes gets no output', () async {
    var (errors, output) = await build('${header}class A {}');
    expect(errors, isEmpty);
    expect(output, isFalse);
  });

  test('a generic class is rejected', () async {
    var (errors, _) = await build('$header@injectable class Box<T> {}');
    expect(errors.join(), contains('does not support generic classes'));
  });

  test('a private class is rejected', () async {
    var (errors, _) = await build('$header@injectable class _Hidden {}');
    expect(errors.join(), contains('does not support private classes'));
  });

  test('the annotation on a variable is rejected', () async {
    var (errors, _) = await build('$header@injectable var x = 1;');
    expect(
      errors.join(),
      contains('can only be applied to classes and top-level functions'),
    );
  });

  test('a generic function is rejected', () async {
    var (errors, _) = await build('$header@injectable void f<T>() {}');
    expect(errors.join(), contains('does not support generic functions'));
  });

  test('a top-level function gets output', () async {
    var (errors, output) = await build('$header@injectable void f(int x) {}');
    expect(errors, isEmpty);
    expect(output, isTrue);
  });

  test('a type that this library does not import is rejected', () async {
    var (errors, _) = await build(
      '''
import 'base.dart';
$header
@injectable class Sub extends Base { Sub(super.ids); }
''',
      {
        'a|lib/base.dart': '''
import 'dart:collection';
class Base { final HashSet<int> ids; Base(this.ids); }
''',
      },
    );
    expect(errors.join(), contains('HashSet, in the type of this parameter'));
  });

  test('the variable is named after the file', () {
    expect(reflectionVariableName('lib/services.dart'), 'servicesReflection');
    expect(
      reflectionVariableName('lib/src/user_service.dart'),
      'userServiceReflection',
    );
    expect(
      reflectionVariableName('lib/2fa_codes.dart'),
      r'$2faCodesReflection',
    );
    expect(reflectionVariableName('lib/_.dart'), 'reflection');
  });
}
