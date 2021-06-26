import 'dart:async';
import 'dart:collection';
import 'package:file/file.dart';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_mustache/src/mustache_context.dart';

class MustacheViewCache {
  /// The context for which views and partials are
  /// served from.
  MustacheContext? context;

  HashMap<String, String> viewCache = HashMap();
  HashMap<String, String> partialCache = HashMap();

  MustacheViewCache([this.context]);

  Future<String?> getView(String viewName, Angel app) async {
    if (app.environment.isProduction) {
      if (viewCache.containsKey(viewName)) {
        return viewCache[viewName];
      }
    }

    var viewFile = context?.resolveView(viewName);
    if (viewFile == null) {
      throw FileSystemException('View "$viewName" was not found.', 'null');
    }

    if (viewFile.existsSync()) {
      var viewTemplate = await viewFile.readAsString();
      if (app.environment.isProduction) {
        viewCache[viewName] = viewTemplate;
      }
      return viewTemplate;
    } else {
      throw FileSystemException(
          'View "$viewName" was not found.', viewFile.path);
    }
  }

  String? getPartialSync(String partialName, Angel app) {
    if (app.environment.isProduction) {
      if (partialCache.containsKey(partialName)) {
        return partialCache[partialName];
      }
    }

    var partialFile = context!.resolvePartial(partialName);

    if (partialFile.existsSync()) {
      var partialTemplate = partialFile.readAsStringSync();
      if (app.environment.isProduction) {
        partialCache[partialName] = partialTemplate;
      }
      return partialTemplate;
    } else {
      throw FileSystemException(
          'View "$partialName" was not found.', partialFile.path);
    }
  }
}
