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
    fileSystem.file('b.jl').writeAsStringSync('<i><include src="a.jl"></i>');

    // c.jl
    fileSystem.file('c.jl').writeAsStringSync('<u><include src="b.jl"></u>');
  });

  test('includes are expanded', () async {
    var file = fileSystem.file('c.jl');
    var original = jael.parseDocument(await file.readAsString(),
        sourceUrl: file.uri, onError: (e) => throw e)!;
    var processed = await jael.resolveIncludes(original,
        fileSystem.directory(fileSystem.currentDirectory), (e) => throw e);
    var buf = CodeBuffer();
    var scope = SymbolTable();
    const jael.Renderer().render(processed!, buf, scope);
    print(buf);

    expect(
        buf.toString(),
        '''
<u>
  <i>
    <b>
      a.jl
    </b>
  </i>
</u>
'''
            .trim());
  });
}
