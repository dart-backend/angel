import 'package:angel3_framework/angel3_framework.dart';
import 'package:jinja/jinja.dart';

import 'src/view_loader.dart';

/// Configures an Angel server to use Jinja2 to render templates.
///
/// By default, templates are loaded from the directory [path], with one of
/// the extensions [ext]. A view name that resolves outside it (e.g.
/// `../secret`), also through a symbolic link, or to no template, throws a 404
/// [AngelHttpException]. Pass your own [createLoader] callback to override
/// this.
///
/// In production, templates are kept parsed; otherwise, they are read again on
/// every render.
///
/// Values are not HTML-escaped: write `{{ name | e }}` for any value that is
/// not trusted HTML, such as one from the request.
///
/// An undefined variable renders as [defaultValue]. All options other than
/// [createLoader] are passed to either the loader or [Environment].
AngelConfigurer jinja({
  Set<String> ext = const {'html'},
  String path = 'lib/src/templates',
  bool followLinks = true,
  String blockStart = '{%',
  String blockEnd = '%}',
  String varOpen = '{{',
  String varClose = '}}',
  String commentStart = '{#',
  String commentEnd = '#}',
  Object? defaultValue,
  Map<String, Function> filters = const <String, Function>{},
  Map<String, Function> tests = const <String, Function>{},
  Loader Function()? createLoader,
}) {
  return (app) {
    var production = app.environment.isProduction;

    Environment createEnvironment(Loader loader) => Environment(
      loader: loader,
      autoReload: !production,
      blockStart: blockStart,
      blockEnd: blockEnd,
      variableStart: varOpen,
      variableEnd: varClose,
      commentStart: commentStart,
      commentEnd: commentEnd,
      undefined: (name, [path]) => defaultValue,
      filters: filters,
      tests: tests,
    );

    ViewLoader createViewLoader() => ViewLoader(
      path,
      extensions: ext,
      followLinks: followLinks,
      blockStart: blockStart,
    );

    // Outside production, the default loader and its environment are made
    // for each render, so that templates are read again.
    var loader = createLoader?.call() ?? createViewLoader();
    var env = createEnvironment(loader);

    app.viewGenerator = (name, [values]) async {
      var renderEnv = env;
      if (createLoader == null) {
        var viewLoader = production ? loader : createViewLoader();
        if (!production) renderEnv = createEnvironment(viewLoader);
        await (viewLoader as ViewLoader).preload(name);
      }
      try {
        return renderEnv.getTemplate(name).render(values);
      } on TemplateNotFound catch (e) {
        if (e.path == name) throw AngelHttpException.notFound();
        rethrow;
      }
    };
  };
}
