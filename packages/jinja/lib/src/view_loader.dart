import 'dart:io';

import 'package:jinja/jinja.dart';
import 'package:path/path.dart' as p;

/// Whether [e] is for a path that does not exist, also because a directory of
/// it is a file.
bool _isNotFound(FileSystemException e) {
  if (e is PathNotFoundException) return true;
  var code = e.osError?.errorCode;
  // ENOENT and ENOTDIR on Linux and macOS, ERROR_FILE_NOT_FOUND and
  // ERROR_PATH_NOT_FOUND on Windows.
  return code == 2 || code == 3 || code == 20;
}

/// Loads the templates in a views directory, and only those: a path that
/// resolves outside it (`../secret`, an absolute path, a symbolic link out of
/// it), or without one of [extensions], is not found.
///
/// The templates a view names with string literals in `extends`, `include`,
/// `import` and `from` tags are read without blocking by [preload] before it
/// is rendered. Others, such as those named by variables, are read when the
/// render finds them.
class ViewLoader extends Loader {
  /// The normalized absolute path of the views directory.
  final String root;

  final Set<String> extensions;

  /// Whether symbolic links within the views directory are followed. Links
  /// out of it are never followed.
  final bool followLinks;

  /// The templates named by tags, with the tag delimiters of the environment.
  final RegExp _references;

  /// The sources read, by path; `null` for one that is not found.
  final Map<String, String?> _sources = {};

  ViewLoader(
    String path, {
    required this.extensions,
    required this.followLinks,
    required String blockStart,
  }) : root = p.normalize(p.absolute(path)),
       _references = RegExp(
         '${RegExp.escape(blockStart)}[-+]?\\s*'
         r'''(?:extends|include|import|from)\s+(["'])(.+?)\1''',
       );

  @override
  String getSource(String path) {
    var source = _sources.containsKey(path)
        ? _sources[path]
        : _sources[path] = _readSync(path);
    if (source == null) throw TemplateNotFound(path: path);
    return source;
  }

  @override
  Template load(
    Environment environment,
    String path, {
    Map<String, Object?>? globals,
  }) {
    return environment.fromString(
      getSource(path),
      path: path,
      globals: globals,
    );
  }

  /// Reads the template [path], and those it names, if they are not read.
  Future<void> preload(String path) async {
    if (_sources.containsKey(path)) return;
    var source = _sources[path] = await _read(path);
    if (source == null) return;
    for (var match in _references.allMatches(source)) {
      await preload(match[2]!);
    }
  }

  /// The path of the file of the template [path] inside [root], before links
  /// are resolved, or `null` if there is none.
  String? _filePath(String path) {
    var extension = p.extension(path);
    if (!extensions.contains(
      extension.startsWith('.') ? extension.substring(1) : extension,
    )) {
      return null;
    }
    var filePath = p.normalize(p.join(root, path));
    return p.isWithin(root, filePath) ? filePath : null;
  }

  /// Whether [resolvedFilePath], the file at [filePath] with links resolved,
  /// stays inside [resolvedRoot], and follows no link unless [followLinks].
  bool _isAllowed(String filePath, String resolvedRoot, String resolvedFile) {
    if (!p.isWithin(resolvedRoot, resolvedFile)) return false;
    return followLinks ||
        p.equals(
          resolvedFile,
          p.join(resolvedRoot, p.relative(filePath, from: root)),
        );
  }

  Future<String?> _read(String path) async {
    var filePath = _filePath(path);
    if (filePath == null) return null;
    String resolvedRoot, resolvedFile;
    try {
      [resolvedRoot, resolvedFile] = await Future.wait([
        Directory(root).resolveSymbolicLinks(),
        File(filePath).resolveSymbolicLinks(),
      ]);
    } on FileSystemException catch (e) {
      // A template (or views directory) that does not exist is not found.
      // Other errors, such as a lack of permission, are passed on.
      if (_isNotFound(e)) return null;
      rethrow;
    }
    if (!_isAllowed(filePath, resolvedRoot, resolvedFile) ||
        !await FileSystemEntity.isFile(resolvedFile)) {
      return null;
    }
    return File(resolvedFile).readAsString();
  }

  String? _readSync(String path) {
    var filePath = _filePath(path);
    if (filePath == null) return null;
    String resolvedRoot, resolvedFile;
    try {
      resolvedRoot = Directory(root).resolveSymbolicLinksSync();
      resolvedFile = File(filePath).resolveSymbolicLinksSync();
    } on FileSystemException catch (e) {
      if (_isNotFound(e)) return null;
      rethrow;
    }
    if (!_isAllowed(filePath, resolvedRoot, resolvedFile) ||
        !FileSystemEntity.isFileSync(resolvedFile)) {
      return null;
    }
    return File(resolvedFile).readAsStringSync();
  }
}
