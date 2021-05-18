import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:jael3/jael3.dart';
import 'package:angel3_symbol_table/angel3_symbol_table.dart';

/// Modifies a Jael document.
typedef Patcher = FutureOr<Document>? Function(Document? document,
    Directory currentDirectory, void Function(JaelError error)? onError);

/// Expands all `block[name]` tags within the template, replacing them with the correct content.
///
/// To apply additional patches to resolved documents, provide a set of [patch]
/// functions.
Future<Document?> resolve(Document document, Directory currentDirectory,
    {void Function(JaelError error)? onError, Iterable<Patcher>? patch}) async {
  onError ?? (e) => throw e;

  // Resolve all includes...
  var includesResolved =
      await resolveIncludes(document, currentDirectory, onError);

  var patched = await applyInheritance(
      includesResolved, currentDirectory, onError, patch);

  if (patch?.isNotEmpty != true) {
    return patched;
  }

  for (var p in patch!) {
    patched = await p(patched, currentDirectory, onError);
  }

  return patched;
}

/// Folds any `extend` declarations.
Future<Document?> applyInheritance(
    Document? document,
    Directory currentDirectory,
    void Function(JaelError error)? onError,
    Iterable<Patcher>? patch) async {
  if (document == null) {
    return null;
  }
  if (document.root.tagName.name != 'extend') {
    // This is not an inherited template, so just fill in the existing blocks.
    var root =
        replaceChildrenOfElement(document.root, {}, onError, true, false);
    return Document(document.doctype, root);
  }

  var element = document.root;
  var attr = element.attributes.firstWhereOrNull((a) => a.name == 'src');
  if (attr == null) {
    onError!(JaelError(JaelErrorSeverity.warning,
        'Missing "src" attribute in "extend" tag.', element.tagName.span));
    return null;
  } else if (attr.value is! StringLiteral) {
    onError!(JaelError(
        JaelErrorSeverity.warning,
        'The "src" attribute in an "extend" tag must be a string literal.',
        element.tagName.span));
    return null;
  } else {
    // In theory, there exists:
    // * A single root template with a number of blocks
    // * Some amount of <extend src="..."> templates.

    // To produce an accurate representation, we need to:
    // 1. Find the root template, and store a copy in a variable.
    // 2: For each <extend> template:
    //  a. Enumerate the block overrides it defines
    //  b. Replace matching blocks in the current document
    //  c. If there is no block, and this is the LAST <extend>, fill in the default block content.
    var hierarchy = await resolveHierarchy(document, currentDirectory, onError);
    var out = hierarchy?.root;

    if (out is! RegularElement) {
      return hierarchy!.rootDocument;
    }

    Element setOut(Element out, Map<String?, RegularElement> definedOverrides,
        bool anyTemplatesRemain) {
      var children = <ElementChild>[];

      // Replace matching blocks, etc.
      for (var c in out.children) {
        if (c is Element) {
          children.addAll(replaceBlocks(
              c, definedOverrides, onError, false, anyTemplatesRemain));
        } else {
          children.add(c);
        }
      }

      var root = hierarchy!.root as RegularElement;
      return RegularElement(root.lt, root.tagName, root.attributes, root.gt,
          children, root.lt2, root.slash, root.tagName2, root.gt2);
    }

    // Loop through all extends, filling in blocks.
    while (hierarchy!.extendsTemplates.isNotEmpty) {
      var tmpl = hierarchy.extendsTemplates.removeFirst();
      var definedOverrides = findBlockOverrides(tmpl, onError);
      //if (definedOverrides == null) break;
      out =
          setOut(out!, definedOverrides, hierarchy.extendsTemplates.isNotEmpty);
    }

    // Lastly, just default-fill any remaining blocks.
    var definedOverrides = findBlockOverrides(out!, onError);
    out = setOut(out, definedOverrides, false);

    // Return our processed document.
    return Document(document.doctype, out);
  }
}

Map<String, RegularElement> findBlockOverrides(
    Element tmpl, void Function(JaelError e)? onError) {
  var out = <String, RegularElement>{};

  for (var child in tmpl.children) {
    if (child is RegularElement && child.tagName.name == 'block') {
      var name = child.attributes
          .firstWhereOrNull((a) => a.name == 'name')
          ?.value
          ?.compute(SymbolTable()) as String?;
      if (name != null && name.trim().isNotEmpty == true) {
        out[name] = child;
      }
    }
  }

  return out;
}

/// Resolves the document hierarchy at a given node in the tree.
Future<DocumentHierarchy?> resolveHierarchy(Document document,
    Directory currentDirectory, void Function(JaelError e)? onError) async {
  var extendsTemplates = Queue<Element>();
  String? parent;

  Document? doc = document;
  while (doc != null && (parent = getParent(doc, onError)) != null) {
    try {
      extendsTemplates.addFirst(doc.root);
      var file = currentDirectory.childFile(parent!);
      var parsed = parseDocument(await file.readAsString(),
          sourceUrl: file.uri, onError: onError)!;

      doc = await resolveIncludes(parsed, currentDirectory, onError);
    } on FileSystemException catch (e) {
      onError!(
          JaelError(JaelErrorSeverity.error, e.message, document.root.span));
      return null;
    }
  }

  if (doc == null) {
    return null;
  }
  return DocumentHierarchy(doc, extendsTemplates);
}

class DocumentHierarchy {
  final Document rootDocument;
  final Queue<Element> extendsTemplates; // FIFO

  DocumentHierarchy(this.rootDocument, this.extendsTemplates);

  Element get root => rootDocument.root;
}

Iterable<ElementChild> replaceBlocks(
    Element element,
    Map<String?, RegularElement> definedOverrides,
    void Function(JaelError e)? onError,
    bool replaceWithDefault,
    bool anyTemplatesRemain) {
  if (element.tagName.name == 'block') {
    var nameAttr = element.attributes.firstWhereOrNull((a) => a.name == 'name');
    var name = nameAttr?.value?.compute(SymbolTable());

    if (name?.trim()?.isNotEmpty != true) {
      onError!(JaelError(
          JaelErrorSeverity.warning,
          'This <block> has no `name` attribute, and will be outputted as-is.',
          element.span));
      return [element];
    } else if (!definedOverrides.containsKey(name)) {
      if (element is RegularElement) {
        if (anyTemplatesRemain || !replaceWithDefault) {
          // If there are still templates remaining, this current block may eventually
          // be resolved. Keep it alive.

          // We can't get rid of the block itself, but it may have blocks as children...
          var inner = allChildrenOfRegularElement(element, definedOverrides,
              onError, replaceWithDefault, anyTemplatesRemain);

          return [
            RegularElement(
                element.lt,
                element.tagName,
                element.attributes,
                element.gt,
                inner,
                element.lt2,
                element.slash,
                element.tagName2,
                element.gt2)
          ];
        } else {
          // Otherwise, just return the default contents.
          return element.children;
        }
      } else {
        return [element];
      }
    } else {
      return allChildrenOfRegularElement(definedOverrides[name]!,
          definedOverrides, onError, replaceWithDefault, anyTemplatesRemain);
    }
  } else if (element is SelfClosingElement) {
    return [element];
  } else {
    return [
      replaceChildrenOfRegularElement(element as RegularElement,
          definedOverrides, onError, replaceWithDefault, anyTemplatesRemain)
    ];
  }
}

Element replaceChildrenOfElement(
    Element el,
    Map<String, RegularElement> definedOverrides,
    void Function(JaelError e)? onError,
    bool replaceWithDefault,
    bool anyTemplatesRemain) {
  if (el is RegularElement) {
    return replaceChildrenOfRegularElement(
        el, definedOverrides, onError, replaceWithDefault, anyTemplatesRemain);
  } else {
    return el;
  }
}

RegularElement replaceChildrenOfRegularElement(
    RegularElement el,
    Map<String?, RegularElement> definedOverrides,
    void Function(JaelError e)? onError,
    bool replaceWithDefault,
    bool anyTemplatesRemain) {
  var children = allChildrenOfRegularElement(
      el, definedOverrides, onError, replaceWithDefault, anyTemplatesRemain);
  return RegularElement(el.lt, el.tagName, el.attributes, el.gt, children,
      el.lt2, el.slash, el.tagName2, el.gt2);
}

List<ElementChild> allChildrenOfRegularElement(
    RegularElement el,
    Map<String?, RegularElement> definedOverrides,
    void Function(JaelError e)? onError,
    bool replaceWithDefault,
    bool anyTemplatesRemain) {
  var children = <ElementChild>[];

  for (var c in el.children) {
    if (c is Element) {
      children.addAll(replaceBlocks(c, definedOverrides, onError,
          replaceWithDefault, anyTemplatesRemain));
    } else {
      children.add(c);
    }
  }

  return children;
}

/// Finds the name of the parent template.
String? getParent(Document document, void Function(JaelError error)? onError) {
  var element = document.root;
  if (element.tagName.name != 'extend') return null;

  var attr = element.attributes.firstWhereOrNull((a) => a.name == 'src');
  if (attr == null) {
    onError!(JaelError(JaelErrorSeverity.warning,
        'Missing "src" attribute in "extend" tag.', element.tagName.span));
    return null;
  } else if (attr.value is! StringLiteral) {
    onError!(JaelError(
        JaelErrorSeverity.warning,
        'The "src" attribute in an "extend" tag must be a string literal.',
        element.tagName.span));
    return null;
  } else {
    return (attr.value as StringLiteral).value;
  }
}

/// Expands all `include[src]` tags within the template, and fills in the content of referenced files.
Future<Document?> resolveIncludes(Document? document,
    Directory currentDirectory, void Function(JaelError error)? onError) async {
  if (document == null) {
    return null;
  }
  var rootElement =
      await _expandIncludes(document.root, currentDirectory, onError);
  if (rootElement != null) {
    return Document(document.doctype, rootElement);
  } else {
    return null;
  }
}

Future<Element?> _expandIncludes(Element element, Directory currentDirectory,
    void Function(JaelError error)? onError) async {
  if (element.tagName.name != 'include') {
    if (element is SelfClosingElement) {
      return element;
    } else if (element is RegularElement) {
      var expanded = <ElementChild>[];

      for (var child in element.children) {
        if (child is Element) {
          var includeElement =
              await _expandIncludes(child, currentDirectory, onError);
          if (includeElement != null) {
            expanded.add(includeElement);
          }
        } else {
          expanded.add(child);
        }
      }

      return RegularElement(
          element.lt,
          element.tagName,
          element.attributes,
          element.gt,
          expanded,
          element.lt2,
          element.slash,
          element.tagName2,
          element.gt2);
    } else {
      throw UnsupportedError(
          'Unsupported element type: ${element.runtimeType}');
    }
  }

  var attr = element.attributes.firstWhereOrNull((a) => a.name == 'src');
  if (attr == null) {
    onError!(JaelError(JaelErrorSeverity.warning,
        'Missing "src" attribute in "include" tag.', element.tagName.span));
    return null;
  } else if (attr.value is! StringLiteral) {
    onError!(JaelError(
        JaelErrorSeverity.warning,
        'The "src" attribute in an "include" tag must be a string literal.',
        element.tagName.span));
    return null;
  } else {
    var src = (attr.value as StringLiteral).value;
    var file =
        currentDirectory.fileSystem.file(currentDirectory.uri.resolve(src));
    var contents = await file.readAsString();
    var doc = parseDocument(contents, sourceUrl: file.uri, onError: onError)!;
    var processed = await (resolve(
        doc, currentDirectory.fileSystem.directory(file.dirname),
        onError: onError));
    if (processed == null) {
      return null;
    }
    return processed.root;
  }
}
