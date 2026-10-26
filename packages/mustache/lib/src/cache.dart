import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:mustache_template/mustache_template.dart' as viewer;

import 'mustache_context.dart';

/// The names in `{{> name}}` partial tags, with the default delimiters.
final RegExp _partialTag = RegExp(r'{{\s*>\s*([^}]+?)\s*}}');

/// Thrown by a [_Partials] resolver for a partial that is not loaded yet, so
/// that it is loaded without blocking, and the render tried again.
class _UnloadedPartial {
  final String name;

  _UnloadedPartial(this.name);
}

/// The parsed partials of a render, loaded as they are found.
class _Partials {
  final MustacheContext context;
  final Map<String, viewer.Template> _templates = {};

  _Partials(this.context);

  viewer.Template resolve(String name) =>
      _templates[name] ?? (throw _UnloadedPartial(name));

  /// Loads the partial [name], and those it names, if they are not loaded. A
  /// partial that does not exist renders as nothing, as Mustache specifies.
  Future<void> load(String name) async {
    if (_templates.containsKey(name)) return;
    var file = await context.resolvePartial(name);
    var source = file == null ? '' : await file.readAsString();
    _templates[name] = viewer.Template(source, name: name);
    await loadAll(source);
  }

  /// Loads the partials that [source] names with the default delimiters.
  /// Others are loaded as the render finds them.
  Future<void> loadAll(String source) async {
    for (var match in _partialTag.allMatches(source)) {
      await load(match[1]!);
    }
  }
}

class MustacheViewCache {
  /// The context for which views and partials are
  /// served from.
  final MustacheContext context;

  /// The parsed views and partials, kept in production.
  final Map<String, viewer.Template> _views = {};
  late final _Partials _partials = _Partials(context);

  MustacheViewCache(this.context);

  /// Renders the view [viewName] with [data].
  ///
  /// A view that does not exist inside the views directory throws a 404
  /// [AngelHttpException].
  Future<String> render(String viewName, Map? data, Angel app) async {
    var production = app.environment.isProduction;
    var partials = production ? _partials : _Partials(context);
    var view = production ? _views[viewName] : null;
    if (view == null) {
      var viewFile = await context.resolveView(viewName);
      if (viewFile == null) throw AngelHttpException.notFound();
      view = viewer.Template(
        await viewFile.readAsString(),
        name: viewName,
        partialResolver: partials.resolve,
      );
      await partials.loadAll(view.source);
      if (production) _views[viewName] = view;
    }

    while (true) {
      try {
        return view.renderString(data ?? {});
      } on _UnloadedPartial catch (e) {
        await partials.load(e.name);
      }
    }
  }
}
