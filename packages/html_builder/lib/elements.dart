/// Helper functions to build common HTML5 elements.
library angel3_html_builder.elements;

import 'angel3_html_builder.dart';
export 'angel3_html_builder.dart';

Map<String, dynamic> _apply(Iterable<Map<String, dynamic>> props,
    [Map<String, dynamic>? attrs]) {
  var map = {};
  attrs?.forEach((k, attr) {
    if (attr is String && attr.isNotEmpty == true) {
      map[k] = attr;
    } else if (attr is Iterable && attr.isNotEmpty == true) {
      map[k] = attr.toList();
    } else if (attr != null) {
      map[k] = attr;
    }
  });

  for (var p in props) {
    map.addAll(p);
  }

  return map.cast<String, dynamic>();
}

Node text(String text) => TextNode(text);

Node a(
        {String? href,
        String? rel,
        String? target,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        Iterable<Node> c = const []}) =>
    h(
        'a',
        _apply([
          p,
        ], {
          'href': href,
          'rel': rel,
          'target': target,
          'id': id,
          'class': className,
          'style': style,
        }),
        [...c]);

Node abbr(
        {String? title,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        Iterable<Node> c = const []}) =>
    h(
        'addr',
        _apply([p],
            {'title': title, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node address({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('address', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node area({
  String? alt,
  Iterable<num>? coordinates,
  String? download,
  String? href,
  String? hreflang,
  String? media,
  String? nohref,
  String? rel,
  String? shape,
  String? target,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'area',
        _apply([
          p
        ], {
          'alt': alt,
          'coordinates': coordinates,
          'download': download,
          'href': href,
          'hreflang': hreflang,
          'media': media,
          'nohref': nohref,
          'rel': rel,
          'shape': shape,
          'target': target,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }));

Node article({
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('article', _apply([p], {'class': className, 'style': style}), [...c]);

Node aside({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('aside', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node audio({
  bool? autoplay,
  bool? controls,
  bool? loop,
  bool? muted,
  String? preload,
  String? src,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'audio',
        _apply([
          p
        ], {
          'autoplay': autoplay,
          'controls': controls,
          'loop': loop,
          'muted': muted,
          'preload': preload,
          'src': src,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node b({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('b', _apply([p], {'id': id, 'class': className, 'style': style}), [...c]);

Node base({
  String? href,
  String? target,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'base',
        _apply([
          p
        ], {
          'href': href,
          'target': target,
          'id': id,
          'class': className,
          'style': style
        }));

Node bdi({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('bdi', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node bdo({
  String? dir,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'bdo',
        _apply([p], {'dir': dir, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node blockquote({
  String? cite,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'blockquote',
        _apply(
            [p], {'cite': cite, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node body({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('body', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node br() => SelfClosingNode('br');

Node button({
  bool? autofocus,
  bool? disabled,
  form,
  String? formaction,
  String? formenctype,
  String? formmethod,
  bool? formnovalidate,
  String? formtarget,
  String? name,
  String? type,
  String? value,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'button',
        _apply([
          p
        ], {
          'autofocus': autofocus,
          'disabled': disabled,
          'form': form,
          'formaction': formaction,
          'formenctype': formenctype,
          'formmethod': formmethod,
          'formnovalidate': formnovalidate,
          'formtarget': formtarget,
          'name': name,
          'type': type,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node canvas({
  num? height,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'canvas',
        _apply([
          p
        ], {
          'height': height,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node cite({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('cite', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node caption({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('caption', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node code({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('code', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node col({
  num? span,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'col',
        _apply(
            [p], {'span': span, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node colgroup({
  num? span,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'colgroup',
        _apply(
            [p], {'span': span, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node datalist({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('datalist', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node dd({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('dd', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node del({
  String? cite,
  String? datetime,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'del',
        _apply([
          p
        ], {
          'cite': cite,
          'datetime': datetime,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node details({
  bool? open,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'details',
        _apply(
            [p], {'open': open, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node dfn({
  String? title,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'dfn',
        _apply([p],
            {'title': title, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node dialog({
  bool? open,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'dialog',
        _apply(
            [p], {'open': open, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node div({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('div', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node dl({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('dl', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node dt({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('dt', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node em({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('em', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node embed({
  num? height,
  String? src,
  String? type,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'embed',
        _apply([
          p
        ], {
          'height': height,
          'src': src,
          'type': type,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }));

Node fieldset({
  bool? disabled,
  String? form,
  String? name,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'fieldset',
        _apply([
          p
        ], {
          'disabled': disabled,
          'form': form,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node figcaption({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('figcaption', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node figure({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('figure', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node footer({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('footer', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node form({
  String? accept,
  String? acceptCharset,
  String? action,
  bool? autocomplete,
  String? enctype,
  String? method,
  String? name,
  bool? novalidate,
  String? target,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'form',
        _apply([
          p
        ], {
          'accept': accept,
          'accept-charset': acceptCharset,
          'action': action,
          'autocomplete':
              autocomplete != null ? (autocomplete ? 'on' : 'off') : null,
          'enctype': enctype,
          'method': method,
          'name': name,
          'novalidate': novalidate,
          'target': target,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node h1({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('h1', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node h2({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('h2', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);
Node h3({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('h3', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node h4({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('h4', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node h5({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('h5', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node h6({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('h6', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node head({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('head', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node header({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('header', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node hr() => SelfClosingNode('hr');

Node html({
  String? manifest,
  String? xmlns,
  String? lang,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'html',
        _apply([
          p
        ], {
          'manifest': manifest,
          'xmlns': xmlns,
          'lang': lang,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node i({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('i', _apply([p], {'id': id, 'class': className, 'style': style}), [...c]);

Node iframe({
  num? height,
  String? name,
  sandbox,
  String? src,
  String? srcdoc,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'iframe',
        _apply([
          p
        ], {
          'height': height,
          'name': name,
          'sandbox': sandbox,
          'src': src,
          'srcdoc': srcdoc,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }));

Node img({
  String? alt,
  String? crossorigin,
  num? height,
  String? ismap,
  String? longdesc,
  sizes,
  String? src,
  String? srcset,
  String? usemap,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'img',
        _apply([
          p
        ], {
          'alt': alt,
          'crossorigin': crossorigin,
          'height': height,
          'ismap': ismap,
          'longdesc': longdesc,
          'sizes': sizes,
          'src': src,
          'srcset': srcset,
          'usemap': usemap,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }));

Node input({
  String? accept,
  String? alt,
  bool? autocomplete,
  bool? autofocus,
  bool? checked,
  String? dirname,
  bool? disabled,
  String? form,
  String? formaction,
  String? formenctype,
  String? method,
  String? formnovalidate,
  String? formtarget,
  num? height,
  String? list,
  max,
  num? maxlength,
  min,
  bool? multiple,
  String? name,
  String? pattern,
  String? placeholder,
  bool? readonly,
  bool? required,
  num? size,
  String? src,
  num? step,
  String? type,
  String? value,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'input',
        _apply([
          p
        ], {
          'accept': accept,
          'alt': alt,
          'autocomplete':
              autocomplete == null ? null : (autocomplete ? 'on' : 'off'),
          'autofocus': autofocus,
          'checked': checked,
          'dirname': dirname,
          'disabled': disabled,
          'form': form,
          'formaction': formaction,
          'formenctype': formenctype,
          'method': method,
          'formnovalidate': formnovalidate,
          'formtarget': formtarget,
          'height': height,
          'list': list,
          'max': max,
          'maxlength': maxlength,
          'min': min,
          'multiple': multiple,
          'name': name,
          'pattern': pattern,
          'placeholder': placeholder,
          'readonly': readonly,
          'required': required,
          'size': size,
          'src': src,
          'step': step,
          'type': type,
          'value': value,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }));

Node ins({
  String? cite,
  String? datetime,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'ins',
        _apply([
          p
        ], {
          'cite': cite,
          'datetime': datetime,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node kbd({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('kbd', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node keygen({
  bool? autofocus,
  String? challenge,
  bool? disabled,
  String? from,
  String? keytype,
  String? name,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'keygen',
        _apply([
          p
        ], {
          'autofocus': autofocus,
          'challenge': challenge,
          'disabled': disabled,
          'from': from,
          'keytype': keytype,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node label({
  String? for_,
  String? form,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'label',
        _apply([
          p
        ], {
          'for': for_,
          'form': form,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node legend({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('legend', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node li({
  num? value,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'li',
        _apply([p],
            {'value': value, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node link({
  String? crossorigin,
  String? href,
  String? hreflang,
  String? media,
  String? rel,
  sizes,
  String? target,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'link',
        _apply([
          p
        ], {
          'crossorigin': crossorigin,
          'href': href,
          'hreflang': hreflang,
          'media': media,
          'rel': rel,
          'sizes': sizes,
          'target': target,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }));

Node main({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('main', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node map({
  String? name,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'map',
        _apply(
            [p], {'name': name, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node mark({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('mark', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node menu({
  String? label,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'menu',
        _apply([
          p
        ], {
          'label': label,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node menuitem({
  bool? checked,
  command,
  bool? default_,
  bool? disabled,
  String? icon,
  String? label,
  String? radiogroup,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'menuitem',
        _apply([
          p
        ], {
          'checked': checked,
          'command': command,
          'default': default_,
          'disabled': disabled,
          'icon': icon,
          'label': label,
          'radiogroup': radiogroup,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node meta({
  String? charset,
  String? content,
  String? httpEquiv,
  String? name,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'meta',
        _apply([
          p
        ], {
          'charset': charset,
          'content': content,
          'http-equiv': httpEquiv,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }));

Node nav({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('nav', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node noscript({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('noscript', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node object({
  String? data,
  String? form,
  num? height,
  String? name,
  String? type,
  String? usemap,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'object',
        _apply([
          p
        ], {
          'data': data,
          'form': form,
          'height': height,
          'name': name,
          'type': type,
          'usemap': usemap,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node ol({
  bool? reversed,
  num? start,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'ol',
        _apply([
          p
        ], {
          'reversed': reversed,
          'start': start,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node optgroup({
  bool? disabled,
  String? label,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'optgroup',
        _apply([
          p
        ], {
          'disabled': disabled,
          'label': label,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node option({
  bool? disabled,
  String? label,
  bool? selected,
  String? value,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'option',
        _apply([
          p
        ], {
          'disabled': disabled,
          'label': label,
          'selected': selected,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node output({
  String? for_,
  String? form,
  String? name,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'output',
        _apply([
          p
        ], {
          'for': for_,
          'form': form,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node p({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('p', _apply([p], {'id': id, 'class': className, 'style': style}), [...c]);

Node param({
  String? name,
  value,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'param',
        _apply([
          p
        ], {
          'name': name,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }));

Node picture({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('picture', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node pre({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('pre', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node progress({
  num? max,
  num? value,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'progress',
        _apply([
          p
        ], {
          'max': max,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node q({
  String? cite,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'q',
        _apply(
            [p], {'cite': cite, 'id': id, 'class': className, 'style': style}),
        [...c]);

Node rp({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('rp', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node rt({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('rt', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node ruby({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('ruby', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node s({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('s', _apply([p], {'id': id, 'class': className, 'style': style}), [...c]);

Node samp({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('samp', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node script({
  bool? async,
  String? charset,
  bool? defer,
  String? src,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'script',
        _apply([
          p
        ], {
          'async': async,
          'charset': charset,
          'defer': defer,
          'src': src,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node section({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('section', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node select({
  bool? autofocus,
  bool? disabled,
  String? form,
  bool? multiple,
  bool? required,
  num? size,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'select',
        _apply([
          p
        ], {
          'autofocus': autofocus,
          'disabled': disabled,
          'form': form,
          'multiple': multiple,
          'required': required,
          'size': size,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node small({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('small', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node source({
  String? src,
  String? srcset,
  String? media,
  sizes,
  String? type,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'source',
        _apply([
          p
        ], {
          'src': src,
          'srcset': srcset,
          'media': media,
          'sizes': sizes,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }));

Node span({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('span', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node strong({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('strong', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node style({
  String? media,
  bool? scoped,
  String? type,
  String? id,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'style',
        _apply([p], {'media': media, 'scoped': scoped, 'type': type, 'id': id}),
        [...c]);

Node sub({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('sub', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node summary({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('summary', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node sup({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('sup', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node table({
  bool? sortable,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'table',
        _apply([
          p
        ], {
          'sortable': sortable,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node tbody({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('tbody', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node td({
  num? colspan,
  headers,
  num? rowspan,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'td',
        _apply([
          p
        ], {
          'colspan': colspan,
          'headers': headers,
          'rowspan': rowspan,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node textarea({
  bool? autofocus,
  num? cols,
  String? dirname,
  bool? disabled,
  String? form,
  num? maxlength,
  String? name,
  String? placeholder,
  bool? readonly,
  bool? required,
  num? rows,
  String? wrap,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'textarea',
        _apply([
          p
        ], {
          'autofocus': autofocus,
          'cols': cols,
          'dirname': dirname,
          'disabled': disabled,
          'form': form,
          'maxlength': maxlength,
          'name': name,
          'placeholder': placeholder,
          'readonly': readonly,
          'required': required,
          'rows': rows,
          'wrap': wrap,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node tfoot({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('tfoot', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node th({
  String? abbr,
  num? colspan,
  headers,
  num? rowspan,
  String? scope,
  sorted,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'th',
        _apply([
          p
        ], {
          'abbr': abbr,
          'colspan': colspan,
          'headers': headers,
          'rowspan': rowspan,
          'scope': scope,
          'sorted': sorted,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node thead({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('thead', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node time({
  String? datetime,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'time',
        _apply([
          p
        ], {
          'datetime': datetime,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node title({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('title', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node tr({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('tr', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node track({
  bool? default_,
  String? kind,
  String? label,
  String? src,
  String? srclang,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
}) =>
    SelfClosingNode(
        'track',
        _apply([
          p
        ], {
          'default': default_,
          'kind': kind,
          'label': label,
          'src': src,
          'srclang': srclang,
          'id': id,
          'class': className,
          'style': style
        }));

Node u({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('u', _apply([p], {'id': id, 'class': className, 'style': style}), [...c]);

Node ul({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('ul', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node var_({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('var', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);

Node video({
  bool? autoplay,
  bool? controls,
  num? height,
  bool? loop,
  bool? muted,
  String? poster,
  String? preload,
  String? src,
  num? width,
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h(
        'video',
        _apply([
          p
        ], {
          'autoplay': autoplay,
          'controls': controls,
          'height': height,
          'loop': loop,
          'muted': muted,
          'poster': poster,
          'preload': preload,
          'src': src,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c]);

Node wbr({
  String? id,
  className,
  style,
  Map<String, dynamic> p = const {},
  Iterable<Node> c = const [],
}) =>
    h('wbr', _apply([p], {'id': id, 'class': className, 'style': style}),
        [...c]);
