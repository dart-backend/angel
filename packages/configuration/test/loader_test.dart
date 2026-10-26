import 'package:angel3_configuration/angel3_configuration.dart';
import 'package:file/memory.dart';
import 'package:test/test.dart';

void main() {
  late MemoryFileSystem fileSystem;
  late List<String> warnings;

  setUp(() {
    fileSystem = MemoryFileSystem();
    fileSystem.directory('config').createSync();
    warnings = [];
  });

  void write(String name, String contents) =>
      fileSystem.file('config/$name').writeAsStringSync(contents);

  Future<Map> load() => loadStandaloneConfiguration(
    fileSystem,
    directoryPath: 'config',
    overrideEnvironmentName: 'development',
    onWarning: warnings.add,
  );

  test('null values are loaded', () async {
    write('default.yaml', 'empty:\ntilde: ~\nlist: [a, null]\nmap: {a: }\n');
    expect(await load(), {
      'empty': null,
      'tilde': null,
      'list': ['a', null],
      'map': {'a': null},
    });
    expect(warnings, isEmpty);
  });

  test('a file that includes itself is loaded once', () async {
    write('default.yaml', '_include: ["./default.yaml"]\na: 1\n');
    expect(await load(), {'a': 1});
    expect(warnings, [contains('includes itself')]);
  });

  test('files that include each other are loaded once each', () async {
    write('default.yaml', '_include: ["./other.yaml"]\na: 1\n');
    write('other.yaml', '_include: ["./default.yaml"]\nb: 2\n');
    expect(await load(), {'a': 1, 'b': 2});
    expect(warnings, [contains('includes itself')]);
  });

  test('a file may be included more than once', () async {
    write('default.yaml', '_include: ["./shared.yaml"]\na: 1\n');
    write('development.yaml', '_include: ["./shared.yaml"]\nb: 2\n');
    write('shared.yaml', 'shared: true\n');
    expect(await load(), {'a': 1, 'b': 2, 'shared': true});
    expect(warnings, isEmpty);
  });

  test('.env is read from the file system given', () async {
    write('.env', 'ANGEL3_CONFIGURATION_TEST_VALUE=from-memory\n');
    write('default.yaml', 'value: \$ANGEL3_CONFIGURATION_TEST_VALUE\n');
    expect(await load(), {'value': 'from-memory'});
    expect(warnings, isEmpty);
  });

  test('an undefined variable is null, after a warning', () async {
    write('default.yaml', 'value: \$ANGEL3_CONFIGURATION_TEST_UNDEFINED\n');
    expect(await load(), {'value': null});
    expect(warnings, [contains('ANGEL3_CONFIGURATION_TEST_UNDEFINED')]);
  });

  test('an undefined variable throws without onWarning', () async {
    write('default.yaml', 'value: \$ANGEL3_CONFIGURATION_TEST_UNDEFINED\n');
    expect(
      loadStandaloneConfiguration(fileSystem, directoryPath: 'config'),
      throwsStateError,
    );
  });
}
