import 'dart:io';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:args/command_runner.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:io/ansi.dart';
import 'package:prompts/prompts.dart' as prompts;
import 'package:recase/recase.dart';
import '../util.dart';
import 'pub.dart';

class RenameCommand extends Command {
  @override
  String get name => 'rename';

  @override
  String get description => 'Renames the current project (To be available).';

  @override
  String get invocation => '$name <new name>';

  @override
  run() async {
    String newName;

    if (argResults.rest.isNotEmpty)
      newName = argResults.rest.first;
    else {
      newName = prompts.get('Rename project to');
    }

    newName = ReCase(newName).snakeCase;

    var choice = prompts.getBool('Rename the project to `$newName`?');

    // TODO: To be available once the issue is fixed
    if (choice) {
      print('Rename the project is currently not available');
      /*
      print('Renaming project to `$newName`...');
      var pubspecFile =
          File.fromUri(Directory.current.uri.resolve('pubspec.yaml'));

      if (!await pubspecFile.exists()) {
        throw Exception('No pubspec.yaml found in current directory.');
      } else {
        var pubspec = await loadPubspec();
        var oldName = pubspec.name;
        await renamePubspec(Directory.current, oldName, newName);
        await renameDartFiles(Directory.current, oldName, newName);
        print('Now running `pub get`...');
        var pubPath = resolvePub();
        print('Pub path: $pubPath');
        var pub = await Process.start(pubPath, ['get']);
        stdout.addStream(pub.stdout);
        stderr.addStream(pub.stderr);
        await pub.exitCode;
      }
      */
    }
  }
}

renamePubspec(Directory dir, String oldName, String newName) async {
//  var pubspec = await loadPubspec(dir);
  print(cyan.wrap('Renaming your project to `$newName.`'));

  var pubspecFile = File.fromUri(dir.uri.resolve('pubspec.yaml'));

  if (await pubspecFile.exists()) {
    var contents = await pubspecFile.readAsString(), oldContents = contents;
    contents =
        contents.replaceAll(RegExp('name:\\s*$oldName'), 'name: $newName');

    if (contents != oldContents) {
      await pubspecFile.writeAsString(contents);
    }
  }

//  print(cyan
//      .wrap('Note that this does not actually modify your `pubspec.yaml`.'));
// TODO: https://github.com/dart-lang/pubspec_parse/issues/17
//  var newPubspec =  Pubspec.fromJson(pubspec.toJson()..['name'] = newName);
//  await newPubspec.save(dir);
}

renameDartFiles(Directory dir, String oldName, String newName) async {
  if (!await dir.exists()) return;

  // Try to replace MongoDB URL
  var configGlob = Glob('config/**/*.yaml');

  try {
    await for (var yamlFile in configGlob.list(root: dir.absolute.path)) {
      if (yamlFile is File) {
        print(
            'Replacing occurrences of "$oldName" with "$newName" in file "${yamlFile.absolute.path}"...');
        if (yamlFile is File) {
          var contents = (yamlFile as File).readAsStringSync();
          contents = contents.replaceAll(oldName, newName);
          (yamlFile as File).writeAsStringSync(contents);
        }
      }
    }
  } catch (_) {}

  var entry = File.fromUri(dir.uri.resolve('lib/$oldName.dart'));

  if (await entry.exists()) {
    await entry.rename(dir.uri.resolve('lib/$newName.dart').toFilePath());
    print('Renaming library file `${entry.absolute.path}`...');
  }

  var fmt = DartFormatter();
  await for (FileSystemEntity file in dir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      var contents = await file.readAsString();

      // TODO: Issue to be fixed: parseCompilationUnit uses Hubbub library which uses discontinued Google front_end library
      // front_end package. Temporarily commeted out
      //var ast = parseCompilationUnit(contents);
      var visitor = RenamingVisitor(oldName, newName);
      //  ..visitCompilationUnit(ast);

      if (visitor.replace.isNotEmpty) {
        visitor.replace.forEach((range, replacement) {
          if (range.first is int) {
            contents = contents.replaceRange(
                range.first as int, range.last as int, replacement);
          } else if (range.first is String) {
            contents = contents.replaceAll(range.first as String, replacement);
          }
        });

        await file.writeAsString(fmt.format(contents));
        print('Updated file `${file.absolute.path}`.');
      }
    }
  }
}

class RenamingVisitor extends RecursiveAstVisitor {
  final String oldName, newName;
  final Map<List, String> replace = {};

  RenamingVisitor(this.oldName, this.newName) {
    replace[['{{$oldName}}']] = newName;
  }

  String updateUri(String uri) {
    if (uri == 'package:$oldName/$oldName.dart') {
      return 'package:$newName/$newName.dart';
    } else if (uri.startsWith('package:$oldName/')) {
      return 'package:$newName/' + uri.replaceFirst('package:$oldName/', '');
    } else
      return uri;
  }

  @override
  visitExportDirective(ExportDirective ctx) {
    var uri = ctx.uri.stringValue, updated = updateUri(uri);
    if (uri != updated) replace[[uri]] = updated;
  }

  @override
  visitImportDirective(ImportDirective ctx) {
    var uri = ctx.uri.stringValue, updated = updateUri(uri);
    if (uri != updated) replace[[uri]] = updated;
  }

  @override
  visitLibraryDirective(LibraryDirective ctx) {
    var name = ctx.name.name;

    if (name.startsWith(oldName)) {
      replace[[ctx.offset, ctx.end]] =
          'library ' + name.replaceFirst(oldName, newName) + ';';
    }
  }

  @override
  visitPartOfDirective(PartOfDirective ctx) {
    if (ctx.libraryName != null) {
      var name = ctx.libraryName.name;

      if (name.startsWith(oldName)) {
        replace[[ctx.offset, ctx.end]] =
            'part of ' + name.replaceFirst(oldName, newName) + ';';
      }
    }
  }
}
