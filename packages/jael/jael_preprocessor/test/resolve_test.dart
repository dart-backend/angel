import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:jael3/jael3.dart' as jael;
import 'package:jael3_preprocessor/jael3_preprocessor.dart' as jael;
import 'package:test/test.dart';

void main() {
  late FileSystem fileSystem;
  late List<jael.JaelError> errors;

  setUp(() {
    fileSystem = MemoryFileSystem();
    errors = [];
  });

  void write(String path, String contents) => fileSystem.file(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  /// [path] resolved, with errors collected in [errors], or with [onError]
  /// left out if [collect] is false.
  Future<jael.Document?> resolve(String path, {bool collect = true}) {
    var file = fileSystem.file(path);
    var document = jael.parseDocument(
      file.readAsStringSync(),
      sourceUrl: file.uri,
      onError: (e) => throw e,
    )!;
    return jael.resolve(
      document,
      fileSystem.directory(file.dirname),
      onError: collect ? errors.add : null,
    );
  }

  String render(jael.Document document) {
    var buf = CodeBuffer();
    const jael.Renderer().render(document, buf, SymbolTable());
    return buf.toString();
  }

  test(
    'a block nested deeper that is not overridden gets its default',
    () async {
      write(
        'base.jl',
        '<html><body><block name="a">DEF_A</block><block name="b">DEF_B</block>'
            '</body></html>',
      );
      write(
        'child.jl',
        '<extend src="base.jl"><block name="a">OVR_A</block></extend>',
      );
      var html = render((await resolve('child.jl'))!);
      expect(html, contains('OVR_A'));
      expect(html, contains('DEF_B'));
      expect(html, isNot(contains('<block')));
    },
  );

  test(
    'a parent that cannot be read is reported, and resolves to null',
    () async {
      write(
        'child.jl',
        '<extend src="missing.jl"><block name="a">x</block></extend>',
      );
      expect(await resolve('child.jl'), isNull);
      expect(errors, isNotEmpty);
    },
  );

  test('without onError, an error is thrown as a JaelError', () async {
    write('child.jl', '<extend src="missing.jl"></extend>');
    await expectLater(
      resolve('child.jl', collect: false),
      throwsA(isA<jael.JaelError>()),
    );
  });

  test('without onError, a warning is not thrown', () async {
    write('nameless.jl', '<div><block>x</block></div>');
    expect(await resolve('nameless.jl', collect: false), isNotNull);
  });

  test(
    'a block within the default content of another gets its default',
    () async {
      write(
        'base.jl',
        '<html><block name="a"><div><block name="b">DEF_B</block></div></block>'
            '</html>',
      );
      write('child.jl', '<extend src="base.jl"></extend>');
      for (var path in ['child.jl', 'base.jl']) {
        var html = render((await resolve(path))!);
        expect(html, contains('DEF_B'));
        expect(html, isNot(contains('<block')));
      }
    },
  );

  test('an override with a block of its own name gets its default', () async {
    write('base.jl', '<html><block name="a">DEF</block></html>');
    write(
      'child.jl',
      '<extend src="base.jl"><block name="a">[<block name="a">IN</block>]'
          '</block></extend>',
    );
    var html = render((await resolve('child.jl'))!);
    expect(html, contains('[IN]'));
  });

  test(
    'a parent with syntax errors is reported, and resolves to null',
    () async {
      write('base.jl', '<html><block name="a">');
      write('child.jl', '<extend src="base.jl"></extend>');
      expect(await resolve('child.jl'), isNull);
      expect(errors, isNotEmpty);
    },
  );

  test('an include with syntax errors is reported', () async {
    write('bad.jl', '<span>');
    write('a.jl', '<div><include src="bad.jl" /></div>');
    await resolve('a.jl');
    expect(errors, isNotEmpty);
  });

  test(
    'a missing grandparent is reported at the template extending it',
    () async {
      write('base.jl', '<extend src="missing.jl"></extend>');
      write('child.jl', '<extend src="base.jl"></extend>');
      expect(await resolve('child.jl'), isNull);
      expect(errors.single.span.sourceUrl?.path, endsWith('base.jl'));
    },
  );

  test('a file that includes the file resolved is found at once', () async {
    write('a.jl', '<div>A<include src="b.jl" /></div>');
    write('b.jl', '<span><include src="a.jl" /></span>');
    var html = render((await resolve('a.jl'))!);
    expect(errors.single.message, contains('includes itself'));
    expect('A'.allMatches(html), hasLength(1));
  });

  test('a cycle through an include and an extend is reported', () async {
    write('a.jl', '<div><include src="b.jl" /></div>');
    write('b.jl', '<extend src="c.jl"></extend>');
    write('c.jl', '<div><include src="a.jl" /></div>');
    await resolve('a.jl').timeout(const Duration(seconds: 5));
    expect(errors.single.message, contains('includes itself'));
  });

  test('a template that extends itself is reported, not looped', () async {
    write('a.jl', '<extend src="b.jl"><block name="x">a</block></extend>');
    write('b.jl', '<extend src="a.jl"><block name="x">b</block></extend>');
    expect(await resolve('a.jl').timeout(const Duration(seconds: 5)), isNull);
    expect(errors.single.message, contains('extends itself'));
  });

  test('a file that includes itself is reported, not recursed', () async {
    write('a.jl', '<div><include src="b.jl" /></div>');
    write('b.jl', '<span><include src="a.jl" /></span>');
    await resolve('a.jl');
    expect(errors.single.message, contains('includes itself'));
  });

  test('an include that cannot be read is reported', () async {
    write('a.jl', '<div><include src="missing.jl" /></div>');
    await resolve('a.jl');
    expect(errors, hasLength(1));
  });

  test(
    'a parent, and its includes and parent, are read relative to it',
    () async {
      write('layouts/root.jl', '<html><block name="body">ROOT</block></html>');
      write('layouts/nav.jl', '<nav>NAV</nav>');
      write(
        'layouts/base.jl',
        '<extend src="root.jl"><block name="body"><include src="nav.jl" />'
            '<block name="content">BASE</block></block></extend>',
      );
      write(
        'pages/child.jl',
        '<extend src="../layouts/base.jl"><block name="content">CHILD</block>'
            '</extend>',
      );
      var html = render((await resolve('pages/child.jl'))!);
      expect(errors, isEmpty);
      expect(html, contains('NAV'));
      expect(html, contains('CHILD'));
    },
  );
}
