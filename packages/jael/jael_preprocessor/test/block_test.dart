import 'package:belatuk_code_buffer/belatuk_code_buffer.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:jael3/jael3.dart' as jael;
import 'package:jael3_preprocessor/jael3_preprocessor.dart' as jael;
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'package:test/test.dart';

void main() {
  late FileSystem fileSystem;

  setUp(() {
    fileSystem = MemoryFileSystem();

    // a.jl
    fileSystem.file('a.jl').writeAsStringSync('<b>a.jl</b>');

    // b.jl
    fileSystem
        .file('b.jl')
        .writeAsStringSync(
          '<i><include src="a.jl" /><block name="greeting"><p>Hello</p></block></i>',
        );

    // c.jl
    // NOTE: This SHOULD NOT produce "yes", because the only children expanded within an <extend>
    // are <block>s.
    fileSystem
        .file('c.jl')
        .writeAsStringSync(
          '<extend src="b.jl"><block name="greeting">Goodbye</block>Yes</extend>',
        );

    // d.jl
    // This should not output "Yes", either.
    // It should actually produce the same as c.jl, since it doesn't define any unique blocks.
    fileSystem
        .file('d.jl')
        .writeAsStringSync(
          '<extend src="c.jl"><block name="greeting">Saluton!</block>Yes</extend>',
        );

    // e.jl
    fileSystem
        .file('e.jl')
        .writeAsStringSync(
          '<extend src="c.jl"><block name="greeting">Angel <b><block name="name">default</block></b></block></extend>',
        );

    // fox.jl
    fileSystem
        .file('fox.jl')
        .writeAsStringSync(
          '<div><block name="dance">The name is <block name="name">default-name</block></block></div>',
        );

    // trot.jl
    fileSystem
        .file('trot.jl')
        .writeAsStringSync(
          '<extend src="fox.jl"><block name="name">CONGA <i><block name="exclaim">YEAH</block></i></block></extend>',
        );

    // foxtrot.jl
    fileSystem
        .file('foxtrot.jl')
        .writeAsStringSync(
          '<extend src="trot.jl"><block name="exclaim">framework</block></extend>',
        );
  });

  test('blocks are replaced or kept', () async {
    var file = fileSystem.file('c.jl');
    var original = jael.parseDocument(
      await file.readAsString(),
      sourceUrl: file.uri,
      onError: (e) => throw e,
    )!;
    var processed = await (jael.resolve(
      original,
      fileSystem.directory(fileSystem.currentDirectory),
      onError: (e) => throw e,
    ));
    var buf = CodeBuffer();
    var scope = SymbolTable();
    const jael.Renderer().render(processed!, buf, scope);
    print(buf);

    expect(
      buf.toString(),
      '''
<i>
  <b>
    a.jl
  </b>
  Goodbye
</i>
    '''
          .trim(),
    );
  });

  test('block defaults are emitted', () async {
    var file = fileSystem.file('b.jl');
    var original = jael.parseDocument(
      await file.readAsString(),
      sourceUrl: file.uri,
      onError: (e) => throw e,
    )!;
    var processed = await (jael.resolve(
      original,
      fileSystem.directory(fileSystem.currentDirectory),
      onError: (e) => throw e,
    ));
    var buf = CodeBuffer();
    var scope = SymbolTable();
    const jael.Renderer().render(processed!, buf, scope);
    print(buf);

    expect(
      buf.toString(),
      '''
<i>
  <b>
    a.jl
  </b>
  <p>
    Hello
  </p>
</i>
    '''
          .trim(),
    );
  });

  test(
    'block resolution only redefines blocks at one level at a time',
    () async {
      var file = fileSystem.file('d.jl');
      var original = jael.parseDocument(
        await file.readAsString(),
        sourceUrl: file.uri,
        onError: (e) => throw e,
      )!;
      var processed = await (jael.resolve(
        original,
        fileSystem.directory(fileSystem.currentDirectory),
        onError: (e) => throw e,
      ));
      var buf = CodeBuffer();
      var scope = SymbolTable();
      const jael.Renderer().render(processed!, buf, scope);
      print(buf);

      expect(
        buf.toString(),
        '''
<i>
  <b>
    a.jl
  </b>
  Goodbye
</i>
    '''
            .trim(),
      );
    },
  );

  test('blocks within blocks', () async {
    var file = fileSystem.file('foxtrot.jl');
    var original = jael.parseDocument(
      await file.readAsString(),
      sourceUrl: file.uri,
      onError: (e) => throw e,
    )!;
    var processed = await (jael.resolve(
      original,
      fileSystem.directory(fileSystem.currentDirectory),
      onError: (e) => throw e,
    ));
    var buf = CodeBuffer();
    var scope = SymbolTable();
    const jael.Renderer().render(processed!, buf, scope);
    print(buf);

    expect(
      buf.toString(),
      '''
<div>
  The name is CONGA 
  <i>
    framework
  </i>
</div>
    '''
          .trim(),
    );
  });
}
