import 'package:jael3/jael3.dart';
import 'package:logging/logging.dart';
import 'package:belatuk_symbol_table/belatuk_symbol_table.dart';
import 'object.dart';

class Analyzer extends Parser {
  final Logger logger;
  Analyzer(super.scanner, this.logger);

  //@override
  //final errors = <JaelError>[];

  SymbolTable<JaelObject>? _scope = SymbolTable<JaelObject>();
  var allDefinitions = <Variable<JaelObject>>[];

  SymbolTable<JaelObject>? get parentScope =>
      _scope!.isRoot ? _scope : _scope!.parent;

  SymbolTable<JaelObject>? get scope => _scope;

  bool ensureAttributeIsPresent(Element element, String name) {
    if (element.getAttribute(name)?.value == null) {
      addError(JaelError(JaelErrorSeverity.error,
          'Missing required attribute `$name`.', element.span));
      return false;
    }
    return true;
  }

  void addError(JaelError e) {
    errors.add(e);
    logger.severe(e.message, e.span.highlight());
  }

  bool ensureAttributeIsConstantString(Element element, String name) {
    var a = element.getAttribute(name);
    if (a?.value is! StringLiteral || a?.value == null) {
      var e = JaelError(
          JaelErrorSeverity.warning,
          '`$name` attribute should be a constant string literal.',
          a?.span ?? element.tagName.span);
      addError(e);
      return false;
    }

    return true;
  }

  @override
  Element? parseElement() {
    try {
      _scope = _scope!.createChild();
      var element = super.parseElement();
      if (element == null) return null;

      // Check if any custom element exists.
      _scope!
          .resolve(element.tagName.name)
          ?.value
          ?.usages
          .add(SymbolUsage(SymbolUsageType.read, element.span));

      // Validate attrs
      var forEach = element.getAttribute('for-each');
      if (forEach != null) {
        var asAttr = element.getAttribute('as');
        if (asAttr != null) {
          if (ensureAttributeIsConstantString(element, 'as')) {
            var asName = asAttr.string!.value;
            _scope!.create(asName,
                value: JaelVariable(asName, asAttr.span), constant: true);
          }
        }

        if (forEach.value != null) {
          addError(JaelError(JaelErrorSeverity.error,
              'Missing value for `for-each` directive.', forEach.span));
        }
      }

      var iff = element.getAttribute('if');
      if (iff != null) {
        if (iff.value != null) {
          addError(JaelError(JaelErrorSeverity.error,
              'Missing value for `iff` directive.', iff.span));
        }
      }

      // Validate the tag itself
      if (element is RegularElement) {
        if (element.tagName.name == 'block') {
          ensureAttributeIsConstantString(element, 'name');
          //logger.info('Found <block> at ${element.span.start.toolString}');
        } else if (element.tagName.name == 'case') {
          ensureAttributeIsPresent(element, 'value');
          //logger.info('Found <case> at ${element.span.start.toolString}');
        } else if (element.tagName.name == 'declare') {
          if (element.attributes.isEmpty) {
            addError(JaelError(
                JaelErrorSeverity.warning,
                '`declare` directive does not define any new symbols.',
                element.tagName.span));
          } else {
            for (var attr in element.attributes) {
              _scope!
                  .create(attr.name, value: JaelVariable(attr.name, attr.span));
            }
          }
        } else if (element.tagName.name == 'element') {
          if (ensureAttributeIsConstantString(element, 'name')) {
            var nameCtx = element.getAttribute('name')!.value as StringLiteral;
            var name = nameCtx.value;
            //logger.info(
            //    'Found custom element $name at ${element.span.start.toolString}');
            try {
              var symbol = parentScope!.create(name,
                  value: JaelCustomElement(name, element.tagName.span),
                  constant: true);
              allDefinitions.add(symbol);
            } on StateError catch (e) {
              addError(JaelError(
                  JaelErrorSeverity.error, e.message, element.tagName.span));
            }
          }
        } else if (element.tagName.name == 'extend') {
          ensureAttributeIsConstantString(element, 'src');
          //logger.info('Found <extend> at ${element.span.start.toolString}');
        }
      } else if (element is SelfClosingElement) {
        if (element.tagName.name == 'include') {
          //logger.info('Found <include> at ${element.span.start.toolString}');
          ensureAttributeIsConstantString(element, 'src');
        }
      }

      return element;
    } finally {
      _scope = _scope!.parent;
    }
  }

  @override
  Expression? parseExpression(int precedence) {
    var expr = super.parseExpression(precedence);
    if (expr == null) return null;

    if (expr is Identifier) {
      var ref = _scope!.resolve(expr.name);
      ref?.value?.usages.add(SymbolUsage(SymbolUsageType.read, expr.span));
    }

    return expr;
  }
}
