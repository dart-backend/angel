import 'dart:io' show PathNotFoundException;

import 'package:file/file.dart';

/// Whether [e] is for a path that does not exist, also because a directory of
/// it is a file.
bool _isNotFound(FileSystemException e) {
  if (e is PathNotFoundException) return true;
  var code = e.osError?.errorCode;
  return code == ErrorCodes.ENOENT || code == ErrorCodes.ENOTDIR;
}

class MustacheContext {
  final Directory viewDirectory;

  final Directory partialDirectory;

  final String extension;

  MustacheContext(this.viewDirectory, this.partialDirectory, this.extension);

  /// The file of the view [viewName], or `null` if there is none inside
  /// [viewDirectory].
  Future<File?> resolveView(String viewName) =>
      _resolve(viewDirectory, viewName);

  /// The file of the partial [partialName], or `null` if there is none inside
  /// [partialDirectory].
  Future<File?> resolvePartial(String partialName) =>
      _resolve(partialDirectory, partialName);

  /// The file [name] in [directory], or `null` if it does not exist, is not a
  /// file, or resolves outside [directory] (`../secret`, an absolute path, a
  /// symbolic link out of it).
  Future<File?> _resolve(Directory directory, String name) async {
    var fileSystem = directory.fileSystem;
    var path = fileSystem.path;
    var root = path.normalize(directory.absolute.path);
    var filePath = path.normalize(path.join(root, '$name$extension'));
    if (!path.isWithin(root, filePath)) return null;

    // Also stay inside the directory through symbolic links, and read the
    // file that was checked. The directory is resolved on every lookup, as it
    // may be a link that a deployment points elsewhere.
    String resolvedRoot, resolvedFilePath;
    try {
      [resolvedRoot, resolvedFilePath] = await Future.wait([
        directory.resolveSymbolicLinks(),
        fileSystem.file(filePath).resolveSymbolicLinks(),
      ]);
    } on FileSystemException catch (e) {
      // A file (or directory) that does not exist is not found. Other errors,
      // such as a lack of permission or a loop of links, are passed on.
      if (_isNotFound(e)) return null;
      rethrow;
    }
    if (!path.isWithin(resolvedRoot, resolvedFilePath) ||
        !await fileSystem.isFile(resolvedFilePath)) {
      return null;
    }
    return fileSystem.file(resolvedFilePath);
  }
}
