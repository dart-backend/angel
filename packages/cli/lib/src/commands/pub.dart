import 'dart:io';

final RegExp _leadingSlashes = RegExp(r'^/+');

String resolvePub() {
  var exec = File(Platform.resolvedExecutable);
  var pubPath = exec.parent.uri.resolve('pub').path;
  if (Platform.isWindows)
    pubPath = pubPath.replaceAll(_leadingSlashes, '') + '.bat';
  pubPath = Uri.decodeFull(pubPath);
  return pubPath;
}
