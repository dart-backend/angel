import 'node.dart';

/// An object that can render a DOM tree into another representation, i.e. a `String`.
abstract class Renderer<T> {
  /// Renders a DOM tree into another representation.
  T render(Node rootNode);
}

/// Renders a DOM tree into a HTML string.
abstract class StringRenderer implements Renderer<String> {
  /// Initializes a new [StringRenderer].
  ///
  /// If [html5] is not `false` (default: `true`), then self-closing elements will be rendered with a slash before the last angle bracket, ex. `<br />`.
  /// If [pretty] is `true` (default), then [whitespace] (default: `'  '`) will be inserted between nodes.
  /// You can also provide a [doctype] (default: `html`).
  factory StringRenderer(
          {bool html5: true,
          bool pretty: true,
          String doctype: 'html',
          String whitespace: '  '}) =>
      pretty == true
          ? _PrettyStringRendererImpl(
              html5: html5 != false, doctype: doctype, whitespace: whitespace)
          : _StringRendererImpl(html5: html5 != false, doctype: doctype);
}

class _StringRendererImpl implements StringRenderer {
  final String? doctype;
  final bool? html5;

  _StringRendererImpl({this.html5, this.doctype});

  void _renderInto(Node node, StringBuffer buf) {
    if (node is TextNode) {
      buf.write(node.text);
    } else {
      buf.write('<${node.tagName}');

      node.attributes.forEach((k, v) {
        if (v == true) {
          buf.write(' $k');
        } else if (v == false || v == null) {
          // Ignore
        } else if (v is Iterable) {
          var val = v.join(' ').replaceAll('"', '\\"');
          buf.write(' $k="$val"');
        } else if (v is Map) {
          var val = v.keys
              .fold<String>('', (out, k) => out += '$k: ${v[k]};')
              .replaceAll('"', '\\"');
          buf.write(' $k="$val"');
        } else {
          var val = v.toString().replaceAll('"', '\\"');
          buf.write(' $k="$val"');
        }
      });

      if (node is SelfClosingNode) {
        buf.write((html5 != false) ? '>' : '/>');
      } else {
        buf.write('>');
        node.children.forEach((child) => _renderInto(child, buf));
        buf.write('</${node.tagName}>');
      }
    }
  }

  @override
  String render(Node rootNode) {
    var buf = StringBuffer();
    if (doctype?.isNotEmpty == true) buf.write('<!DOCTYPE $doctype>');
    _renderInto(rootNode, buf);
    return buf.toString();
  }
}

class _PrettyStringRendererImpl implements StringRenderer {
  final bool? html5;
  final String? doctype, whitespace;

  _PrettyStringRendererImpl({this.html5, this.whitespace, this.doctype});

  void _applyTabs(int tabs, StringBuffer buf) {
    for (int i = 0; i < tabs; i++) buf.write(whitespace ?? '  ');
  }

  void _renderInto(int tabs, Node node, StringBuffer buf) {
    if (tabs > 0) buf.writeln();
    _applyTabs(tabs, buf);

    if (node is TextNode) {
      buf.write(node.text);
    } else {
      buf.write('<${node.tagName}');

      node.attributes.forEach((k, v) {
        if (v == true) {
          buf.write(' $k');
        } else if (v == false || v == null) {
          // Ignore
        } else if (v is Iterable) {
          var val = v.join(' ').replaceAll('"', '\\"');
          buf.write(' $k="$val"');
        } else if (v is Map) {
          var val = v.keys
              .fold<String>('', (out, k) => out += '$k: ${v[k]};')
              .replaceAll('"', '\\"');
          buf.write(' $k="$val"');
        } else {
          var val = v.toString().replaceAll('"', '\\"');
          buf.write(' $k="$val"');
        }
      });

      if (node is SelfClosingNode) {
        buf.write((html5 != false) ? '>' : '/>');
      } else {
        buf.write('>');
        node.children.forEach((child) => _renderInto(tabs + 1, child, buf));
        buf.writeln();
        _applyTabs(tabs, buf);
        buf.write('</${node.tagName}>');
      }
    }
  }

  @override
  String render(Node rootNode) {
    var buf = StringBuffer();
    if (doctype?.isNotEmpty == true) buf.writeln('<!DOCTYPE $doctype>');
    _renderInto(0, rootNode, buf);
    return buf.toString();
  }
}
