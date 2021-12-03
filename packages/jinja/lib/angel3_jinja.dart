import 'package:angel3_framework/angel3_framework.dart';
import 'package:jinja/jinja.dart';

/// Configures an Angel server to use Jinja2 to render templates.
///
/// By default, templates are loaded from the filesystem;
/// pass your own [createLoader] callback to override this.
///
/// All options other than [createLoader] are passed to either [FileSystemLoader]
/// or [Environment].
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
  defaultValue,
  //bool autoReload = true,
  Map<String, Function> filters = const <String, Function>{},
  Map<String, Function> tests = const <String, Function>{},
  Loader Function()? createLoader,
}) {
  return (app) {
    createLoader ??= () {
      return FileSystemLoader(
        extensions: ext,
        path: path,
        followLinks: followLinks,
      );
    };
    var env = Environment(
      loader: createLoader!(),
      blockStart: blockStart,
      blockEnd: blockEnd,
      variableStart: varOpen,
      variableEnd: varClose,
      commentStart: commentStart,
      commentEnd: commentEnd,
      //defaultValue: defaultValue,
      //autoReload: autoReload,
      filters: filters,
      tests: tests,
    );

    app.viewGenerator = (path, [values]) {
      return env.getTemplate(path).render.renderMap(values) as String;
    };
  };
}
