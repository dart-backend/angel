import 'dart:async';
import 'dart:isolate';
import 'dart:mirrors';

Future<String> absoluteSourcePath(Type type) async {
  var mirror = reflectType(type);

  if (mirror.location == null) {
    throw ArgumentError('Invalid location');
  }

  var uri = mirror.location!.sourceUri;

  if (uri.scheme == 'package') {
    var packageUrl = await Isolate.resolvePackageUri(uri);
    if (packageUrl != null) {
      uri = packageUrl;
    }
  }

  return '${uri.toFilePath()}#${MirrorSystem.getName(mirror.simpleName)}';
}
