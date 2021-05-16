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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'a',
        _apply([
          p,
          props
        ], {
          'href': href,
          'rel': rel,
          'target': target,
          'id': id,
          'class': className,
          'style': style,
        }),
        [...c, ...children]);

Node abbr(
        {String? title,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'addr',
        _apply([p, props],
            {'title': title, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node address(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'address',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node area(
        {String? alt,
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
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'area',
        _apply([
          p,
          props
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

Node article(
        {className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('article', _apply([p, props], {'class': className, 'style': style}),
        [...c, ...children]);

Node aside(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'aside',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node audio(
        {bool? autoplay,
        bool? controls,
        bool? loop,
        bool? muted,
        String? preload,
        String? src,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'audio',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node b(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('b', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node base(
        {String? href,
        String? target,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'base',
        _apply([
          p,
          props
        ], {
          'href': href,
          'target': target,
          'id': id,
          'class': className,
          'style': style
        }));

Node bdi(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('bdi', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node bdo(
        {String? dir,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'bdo',
        _apply([p, props],
            {'dir': dir, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node blockquote(
        {String? cite,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'blockquote',
        _apply([p, props],
            {'cite': cite, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node body(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'body',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node br() => SelfClosingNode('br');

Node button(
        {bool? autofocus,
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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'button',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node canvas(
        {num? height,
        num? width,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'canvas',
        _apply([
          p,
          props
        ], {
          'height': height,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node cite(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'cite',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node caption(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'caption',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node code(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'code',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node col(
        {num? span,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'col',
        _apply([p, props],
            {'span': span, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node colgroup(
        {num? span,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'colgroup',
        _apply([p, props],
            {'span': span, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node datalist(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'datalist',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node dd(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('dd', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node del(
        {String? cite,
        String? datetime,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'del',
        _apply([
          p,
          props
        ], {
          'cite': cite,
          'datetime': datetime,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node details(
        {bool? open,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'details',
        _apply([p, props],
            {'open': open, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node dfn(
        {String? title,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'dfn',
        _apply([p, props],
            {'title': title, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node dialog(
        {bool? open,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'dialog',
        _apply([p, props],
            {'open': open, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node div(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('div', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node dl(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('dl', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node dt(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('dt', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node em(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('em', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node embed(
        {num? height,
        String? src,
        String? type,
        num? width,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'embed',
        _apply([
          p,
          props
        ], {
          'height': height,
          'src': src,
          'type': type,
          'width': width,
          'id': id,
          'class': className,
          'style': style
        }));

Node fieldset(
        {bool? disabled,
        String? form,
        String? name,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'fieldset',
        _apply([
          p,
          props
        ], {
          'disabled': disabled,
          'form': form,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node figcaption(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'figcaption',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node figure(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'figure',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node footer(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'footer',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node form(
        {String? accept,
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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'form',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node h1(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('h1', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node h2(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('h2', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);
Node h3(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('h3', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node h4(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('h4', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node h5(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('h5', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node h6(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('h6', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node head(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'head',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node header(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'header',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node hr() => SelfClosingNode('hr');

Node html(
        {String? manifest,
        String? xmlns,
        String? lang,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'html',
        _apply([
          p,
          props
        ], {
          'manifest': manifest,
          'xmlns': xmlns,
          'lang': lang,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node i(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('i', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node iframe(
        {num? height,
        String? name,
        sandbox,
        String? src,
        String? srcdoc,
        num? width,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'iframe',
        _apply([
          p,
          props
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

Node img(
        {String? alt,
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
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'img',
        _apply([
          p,
          props
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

Node input(
        {String? accept,
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
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'input',
        _apply([
          p,
          props
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

Node ins(
        {String? cite,
        String? datetime,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'ins',
        _apply([
          p,
          props
        ], {
          'cite': cite,
          'datetime': datetime,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node kbd(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('kbd', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node keygen(
        {bool? autofocus,
        String? challenge,
        bool? disabled,
        String? from,
        String? keytype,
        String? name,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'keygen',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node label(
        {String? for_,
        String? form,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'label',
        _apply([
          p,
          props
        ], {
          'for': for_,
          'form': form,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node legend(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'legend',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node li(
        {num? value,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'li',
        _apply([p, props],
            {'value': value, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node link(
        {String? crossorigin,
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
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'link',
        _apply([
          p,
          props
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

Node main(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'main',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node map(
        {String? name,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'map',
        _apply([p, props],
            {'name': name, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node mark(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'mark',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node menu(
        {String? label,
        String? type,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'menu',
        _apply([
          p,
          props
        ], {
          'label': label,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node menuitem(
        {bool? checked,
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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'menuitem',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node meta(
        {String? charset,
        String? content,
        String? httpEquiv,
        String? name,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'meta',
        _apply([
          p,
          props
        ], {
          'charset': charset,
          'content': content,
          'http-equiv': httpEquiv,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }));

Node nav(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('nav', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node noscript(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'noscript',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node object(
        {String? data,
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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'object',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node ol(
        {bool? reversed,
        num? start,
        String? type,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'ol',
        _apply([
          p,
          props
        ], {
          'reversed': reversed,
          'start': start,
          'type': type,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node optgroup(
        {bool? disabled,
        String? label,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'optgroup',
        _apply([
          p,
          props
        ], {
          'disabled': disabled,
          'label': label,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node option(
        {bool? disabled,
        String? label,
        bool? selected,
        String? value,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'option',
        _apply([
          p,
          props
        ], {
          'disabled': disabled,
          'label': label,
          'selected': selected,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node output(
        {String? for_,
        String? form,
        String? name,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'output',
        _apply([
          p,
          props
        ], {
          'for': for_,
          'form': form,
          'name': name,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node p(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('p', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node param(
        {String? name,
        value,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'param',
        _apply([
          p,
          props
        ], {
          'name': name,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }));

Node picture(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'picture',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node pre(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('pre', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node progress(
        {num? max,
        num? value,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'progress',
        _apply([
          p,
          props
        ], {
          'max': max,
          'value': value,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node q(
        {String? cite,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'q',
        _apply([p, props],
            {'cite': cite, 'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node rp(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('rp', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node rt(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('rt', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node ruby(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'ruby',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node s(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('s', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node samp(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'samp',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node script(
        {bool? async,
        String? charset,
        bool? defer,
        String? src,
        String? type,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'script',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node section(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'section',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node select(
        {bool? autofocus,
        bool? disabled,
        String? form,
        bool? multiple,
        bool? required,
        num? size,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'select',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node small(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'small',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node source(
        {String? src,
        String? srcset,
        String? media,
        sizes,
        String? type,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'source',
        _apply([
          p,
          props
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

Node span(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'span',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node strong(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'strong',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node style(
        {String? media,
        bool? scoped,
        String? type,
        String? id,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'style',
        _apply([p, props],
            {'media': media, 'scoped': scoped, 'type': type, 'id': id}),
        [...c, ...children]);

Node sub(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('sub', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node summary(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'summary',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node sup(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('sup', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node table(
        {bool? sortable,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'table',
        _apply([
          p,
          props
        ], {
          'sortable': sortable,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node tbody(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'tbody',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node td(
        {num? colspan,
        headers,
        num? rowspan,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'td',
        _apply([
          p,
          props
        ], {
          'colspan': colspan,
          'headers': headers,
          'rowspan': rowspan,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node textarea(
        {bool? autofocus,
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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'textarea',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node tfoot(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'tfoot',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node th(
        {String? abbr,
        num? colspan,
        headers,
        num? rowspan,
        String? scope,
        sorted,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'th',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node thead(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'thead',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node time(
        {String? datetime,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'time',
        _apply([
          p,
          props
        ], {
          'datetime': datetime,
          'id': id,
          'class': className,
          'style': style
        }),
        [...c, ...children]);

Node title(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'title',
        _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node tr(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('tr', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node track(
        {bool? default_,
        String? kind,
        String? label,
        String? src,
        String? srclang,
        String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {}}) =>
    SelfClosingNode(
        'track',
        _apply([
          p,
          props
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

Node u(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('u', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node ul(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('ul', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node var_(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('var', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);

Node video(
        {bool? autoplay,
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
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h(
        'video',
        _apply([
          p,
          props
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
        [...c, ...children]);

Node wbr(
        {String? id,
        className,
        style,
        Map<String, dynamic> p = const {},
        @deprecated Map<String, dynamic> props = const {},
        Iterable<Node> c = const [],
        @deprecated Iterable<Node> children = const []}) =>
    h('wbr', _apply([p, props], {'id': id, 'class': className, 'style': style}),
        [...c, ...children]);
