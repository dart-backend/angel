class ApplyWorkspaceEditParams {
  ApplyWorkspaceEditParams._(this.edit, this.label);

  factory ApplyWorkspaceEditParams(
      void Function(ApplyWorkspaceEditParams$Builder) init) {
    final b = ApplyWorkspaceEditParams$Builder._();
    init(b);
    return ApplyWorkspaceEditParams._(b.edit, b.label);
  }

  factory ApplyWorkspaceEditParams.fromJson(Map params) =>
      ApplyWorkspaceEditParams._(
          params.containsKey('edit') && params['edit'] != null
              ? WorkspaceEdit.fromJson((params['edit'] as Map))
              : null,
          params.containsKey('label') && params['label'] != null
              ? (params['label'] as String)
              : null);

  final WorkspaceEdit edit;

  final String label;

  Map toJson() => {'edit': edit?.toJson(), 'label': label};
  @override
  int get hashCode {
    var hash = 711903695;
    hash = _hashCombine(hash, _deepHashCode(edit));
    hash = _hashCombine(hash, _deepHashCode(label));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is ApplyWorkspaceEditParams &&
      edit == other.edit &&
      label == other.label;
}

class ApplyWorkspaceEditParams$Builder {
  ApplyWorkspaceEditParams$Builder._();

  WorkspaceEdit edit;

  String label;
}

class ClientCapabilities {
  ClientCapabilities._(this.textDocument, this.workspace);

  factory ClientCapabilities(void Function(ClientCapabilities$Builder) init) {
    final b = ClientCapabilities$Builder._();
    init(b);
    return ClientCapabilities._(b.textDocument, b.workspace);
  }

  factory ClientCapabilities.fromJson(Map params) => ClientCapabilities._(
      params.containsKey('textDocument') && params['textDocument'] != null
          ? TextDocumentClientCapabilities.fromJson(
              (params['textDocument'] as Map))
          : null,
      params.containsKey('workspace') && params['workspace'] != null
          ? WorkspaceClientCapabilities.fromJson((params['workspace'] as Map))
          : null);

  final TextDocumentClientCapabilities textDocument;

  final WorkspaceClientCapabilities workspace;

  Map toJson() => {
        'textDocument': textDocument?.toJson(),
        'workspace': workspace?.toJson()
      };
  @override
  int get hashCode {
    var hash = 410602613;
    hash = _hashCombine(hash, _deepHashCode(textDocument));
    hash = _hashCombine(hash, _deepHashCode(workspace));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is ClientCapabilities &&
      textDocument == other.textDocument &&
      workspace == other.workspace;
}

class ClientCapabilities$Builder {
  ClientCapabilities$Builder._();

  TextDocumentClientCapabilities textDocument;

  WorkspaceClientCapabilities workspace;
}

class CodeAction {
  CodeAction._(
      this.command, this.diagnostics, this.edit, this.kind, this.title);

  factory CodeAction(void Function(CodeAction$Builder) init) {
    final b = CodeAction$Builder._();
    init(b);
    return CodeAction._(b.command, b.diagnostics, b.edit, b.kind, b.title);
  }

  factory CodeAction.fromJson(Map params) => CodeAction._(
      params.containsKey('command') && params['command'] != null
          ? Command.fromJson((params['command'] as Map))
          : null,
      params.containsKey('diagnostics') && params['diagnostics'] != null
          ? (params['diagnostics'] as List)
              .map((v) => Diagnostic.fromJson((v as Map)))
              .toList()
          : null,
      params.containsKey('edit') && params['edit'] != null
          ? WorkspaceEdit.fromJson((params['edit'] as Map))
          : null,
      params.containsKey('kind') && params['kind'] != null
          ? (params['kind'] as String)
          : null,
      params.containsKey('title') && params['title'] != null
          ? (params['title'] as String)
          : null);

  final Command command;

  final List<Diagnostic> diagnostics;

  final WorkspaceEdit edit;

  final String kind;

  final String title;

  Map toJson() => {
        'command': command?.toJson(),
        'diagnostics': diagnostics?.map((v) => v?.toJson())?.toList(),
        'edit': edit?.toJson(),
        'kind': kind,
        'title': title
      };
  @override
  int get hashCode {
    var hash = 817881006;
    hash = _hashCombine(hash, _deepHashCode(command));
    hash = _hashCombine(hash, _deepHashCode(diagnostics));
    hash = _hashCombine(hash, _deepHashCode(edit));
    hash = _hashCombine(hash, _deepHashCode(kind));
    hash = _hashCombine(hash, _deepHashCode(title));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeAction &&
      command == other.command &&
      _deepEquals(diagnostics, other.diagnostics) &&
      edit == other.edit &&
      kind == other.kind &&
      title == other.title;
}

class CodeAction$Builder {
  CodeAction$Builder._();

  Command command;

  List<Diagnostic> diagnostics;

  WorkspaceEdit edit;

  String kind;

  String title;
}

class CodeActionCapabilities {
  CodeActionCapabilities._(
      this.codeActionLiteralSupport, this.dynamicRegistration);

  factory CodeActionCapabilities(
      void Function(CodeActionCapabilities$Builder) init) {
    final b = CodeActionCapabilities$Builder._();
    init(b);
    return CodeActionCapabilities._(
        b.codeActionLiteralSupport, b.dynamicRegistration);
  }

  factory CodeActionCapabilities.fromJson(Map params) =>
      CodeActionCapabilities._(
          params.containsKey('codeActionLiteralSupport') &&
                  params['codeActionLiteralSupport'] != null
              ? CodeActionLiteralSupport.fromJson(
                  (params['codeActionLiteralSupport'] as Map))
              : null,
          params.containsKey('dynamicRegistration') &&
                  params['dynamicRegistration'] != null
              ? (params['dynamicRegistration'] as bool)
              : null);

  final CodeActionLiteralSupport codeActionLiteralSupport;

  final bool dynamicRegistration;

  Map toJson() => {
        'codeActionLiteralSupport': codeActionLiteralSupport?.toJson(),
        'dynamicRegistration': dynamicRegistration
      };
  @override
  int get hashCode {
    var hash = 857718763;
    hash = _hashCombine(hash, _deepHashCode(codeActionLiteralSupport));
    hash = _hashCombine(hash, _deepHashCode(dynamicRegistration));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeActionCapabilities &&
      codeActionLiteralSupport == other.codeActionLiteralSupport &&
      dynamicRegistration == other.dynamicRegistration;
}

class CodeActionCapabilities$Builder {
  CodeActionCapabilities$Builder._();

  CodeActionLiteralSupport codeActionLiteralSupport;

  bool dynamicRegistration;
}

class CodeActionContext {
  CodeActionContext._(this.diagnostics);

  factory CodeActionContext(void Function(CodeActionContext$Builder) init) {
    final b = CodeActionContext$Builder._();
    init(b);
    return CodeActionContext._(b.diagnostics);
  }

  factory CodeActionContext.fromJson(Map params) => CodeActionContext._(
      params.containsKey('diagnostics') && params['diagnostics'] != null
          ? (params['diagnostics'] as List)
              .map((v) => Diagnostic.fromJson((v as Map)))
              .toList()
          : null);

  final List<Diagnostic> diagnostics;

  Map toJson() =>
      {'diagnostics': diagnostics?.map((v) => v?.toJson())?.toList()};
  @override
  int get hashCode {
    var hash = 698635161;
    hash = _hashCombine(hash, _deepHashCode(diagnostics));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeActionContext && _deepEquals(diagnostics, other.diagnostics);
}

class CodeActionContext$Builder {
  CodeActionContext$Builder._();

  List<Diagnostic> diagnostics;
}

class CodeActionKinds {
  CodeActionKinds._(this.valueSet);

  factory CodeActionKinds(void Function(CodeActionKinds$Builder) init) {
    final b = CodeActionKinds$Builder._();
    init(b);
    return CodeActionKinds._(b.valueSet);
  }

  factory CodeActionKinds.fromJson(Map params) => CodeActionKinds._(
      params.containsKey('valueSet') && params['valueSet'] != null
          ? (params['valueSet'] as List).cast<String>()
          : null);

  final List<String> valueSet;

  Map toJson() => {'valueSet': valueSet};
  @override
  int get hashCode {
    var hash = 274472753;
    hash = _hashCombine(hash, _deepHashCode(valueSet));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeActionKinds && _deepEquals(valueSet, other.valueSet);
}

class CodeActionKinds$Builder {
  CodeActionKinds$Builder._();

  List<String> valueSet;
}

class CodeActionLiteralSupport {
  CodeActionLiteralSupport._(this.codeActionKind);

  factory CodeActionLiteralSupport(
      void Function(CodeActionLiteralSupport$Builder) init) {
    final b = CodeActionLiteralSupport$Builder._();
    init(b);
    return CodeActionLiteralSupport._(b.codeActionKind);
  }

  factory CodeActionLiteralSupport.fromJson(Map params) =>
      CodeActionLiteralSupport._(params.containsKey('codeActionKind') &&
              params['codeActionKind'] != null
          ? CodeActionKinds.fromJson((params['codeActionKind'] as Map))
          : null);

  final CodeActionKinds codeActionKind;

  Map toJson() => {'codeActionKind': codeActionKind?.toJson()};
  @override
  int get hashCode {
    var hash = 9179648;
    hash = _hashCombine(hash, _deepHashCode(codeActionKind));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeActionLiteralSupport &&
      codeActionKind == other.codeActionKind;
}

class CodeActionLiteralSupport$Builder {
  CodeActionLiteralSupport$Builder._();

  CodeActionKinds codeActionKind;
}

class CodeLensOptions {
  CodeLensOptions._(this.resolveProvider);

  factory CodeLensOptions(void Function(CodeLensOptions$Builder) init) {
    final b = CodeLensOptions$Builder._();
    init(b);
    return CodeLensOptions._(b.resolveProvider);
  }

  factory CodeLensOptions.fromJson(Map params) => CodeLensOptions._(
      params.containsKey('resolveProvider') && params['resolveProvider'] != null
          ? (params['resolveProvider'] as bool)
          : null);

  final bool resolveProvider;

  Map toJson() => {'resolveProvider': resolveProvider};
  @override
  int get hashCode {
    var hash = 875601242;
    hash = _hashCombine(hash, _deepHashCode(resolveProvider));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CodeLensOptions && resolveProvider == other.resolveProvider;
}

class CodeLensOptions$Builder {
  CodeLensOptions$Builder._();

  bool resolveProvider;
}

class Command {
  Command._(this.arguments, this.command, this.title);

  factory Command(void Function(Command$Builder) init) {
    final b = Command$Builder._();
    init(b);
    return Command._(b.arguments, b.command, b.title);
  }

  factory Command.fromJson(Map params) => Command._(
      params.containsKey('arguments') && params['arguments'] != null
          ? (params['arguments'] as List).cast<dynamic>()
          : null,
      params.containsKey('command') && params['command'] != null
          ? (params['command'] as String)
          : null,
      params.containsKey('title') && params['title'] != null
          ? (params['title'] as String)
          : null);

  final List<dynamic> arguments;

  final String command;

  final String title;

  Map toJson() => {'arguments': arguments, 'command': command, 'title': title};
  @override
  int get hashCode {
    var hash = 306969625;
    hash = _hashCombine(hash, _deepHashCode(arguments));
    hash = _hashCombine(hash, _deepHashCode(command));
    hash = _hashCombine(hash, _deepHashCode(title));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Command &&
      _deepEquals(arguments, other.arguments) &&
      command == other.command &&
      title == other.title;
}

class Command$Builder {
  Command$Builder._();

  List<dynamic> arguments;

  String command;

  String title;
}

class CompletionCapabilities {
  CompletionCapabilities._(this.completionItem, this.dynamicRegistration);

  factory CompletionCapabilities(
      void Function(CompletionCapabilities$Builder) init) {
    final b = CompletionCapabilities$Builder._();
    init(b);
    return CompletionCapabilities._(b.completionItem, b.dynamicRegistration);
  }

  factory CompletionCapabilities.fromJson(Map params) =>
      CompletionCapabilities._(
          params.containsKey('completionItem') &&
                  params['completionItem'] != null
              ? CompletionItemCapabilities.fromJson(
                  (params['completionItem'] as Map))
              : null,
          params.containsKey('dynamicRegistration') &&
                  params['dynamicRegistration'] != null
              ? (params['dynamicRegistration'] as bool)
              : null);

  final CompletionItemCapabilities completionItem;

  final bool dynamicRegistration;

  Map toJson() => {
        'completionItem': completionItem?.toJson(),
        'dynamicRegistration': dynamicRegistration
      };
  @override
  int get hashCode {
    var hash = 490073846;
    hash = _hashCombine(hash, _deepHashCode(completionItem));
    hash = _hashCombine(hash, _deepHashCode(dynamicRegistration));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CompletionCapabilities &&
      completionItem == other.completionItem &&
      dynamicRegistration == other.dynamicRegistration;
}

class CompletionCapabilities$Builder {
  CompletionCapabilities$Builder._();

  CompletionItemCapabilities completionItem;

  bool dynamicRegistration;
}

class CompletionItem {
  CompletionItem._(
      this.additionalTextEdits,
      this.command,
      this.data,
      this.detail,
      this.documentation,
      this.filterText,
      this.insertText,
      this.insertTextFormat,
      this.kind,
      this.label,
      this.sortText,
      this.textEdit);

  factory CompletionItem(void Function(CompletionItem$Builder) init) {
    final b = CompletionItem$Builder._();
    init(b);
    return CompletionItem._(
        b.additionalTextEdits,
        b.command,
        b.data,
        b.detail,
        b.documentation,
        b.filterText,
        b.insertText,
        b.insertTextFormat,
        b.kind,
        b.label,
        b.sortText,
        b.textEdit);
  }

  factory CompletionItem.fromJson(Map params) => CompletionItem._(
      params.containsKey('additionalTextEdits') &&
              params['additionalTextEdits'] != null
          ? (params['additionalTextEdits'] as List)
              .map((v) => TextEdit.fromJson((v as Map)))
              .toList()
          : null,
      params.containsKey('command') && params['command'] != null
          ? Command.fromJson((params['command'] as Map))
          : null,
      params.containsKey('data') && params['data'] != null
          ? (params['data'] as dynamic)
          : null,
      params.containsKey('detail') && params['detail'] != null
          ? (params['detail'] as String)
          : null,
      params.containsKey('documentation') && params['documentation'] != null
          ? (params['documentation'] as String)
          : null,
      params.containsKey('filterText') && params['filterText'] != null
          ? (params['filterText'] as String)
          : null,
      params.containsKey('insertText') && params['insertText'] != null
          ? (params['insertText'] as String)
          : null,
      params.containsKey('insertTextFormat') &&
              params['insertTextFormat'] != null
          ? InsertTextFormat.fromJson((params['insertTextFormat'] as int))
          : null,
      params.containsKey('kind') && params['kind'] != null
          ? CompletionItemKind.fromJson((params['kind'] as int))
          : null,
      params.containsKey('label') && params['label'] != null
          ? (params['label'] as String)
          : null,
      params.containsKey('sortText') && params['sortText'] != null
          ? (params['sortText'] as String)
          : null,
      params.containsKey('textEdit') && params['textEdit'] != null
          ? TextEdit.fromJson((params['textEdit'] as Map))
          : null);

  final List<TextEdit> additionalTextEdits;

  final Command command;

  final dynamic data;

  final String detail;

  final String documentation;

  final String filterText;

  final String insertText;

  final InsertTextFormat insertTextFormat;

  final CompletionItemKind kind;

  final String label;

  final String sortText;

  final TextEdit textEdit;

  Map toJson() => {
        'additionalTextEdits':
            additionalTextEdits?.map((v) => v?.toJson())?.toList(),
        'command': command?.toJson(),
        'data': data,
        'detail': detail,
        'documentation': documentation,
        'filterText': filterText,
        'insertText': insertText,
        'insertTextFormat': insertTextFormat?.toJson(),
        'kind': kind?.toJson(),
        'label': label,
        'sortText': sortText,
        'textEdit': textEdit?.toJson()
      };
  @override
  int get hashCode {
    var hash = 546046223;
    hash = _hashCombine(hash, _deepHashCode(additionalTextEdits));
    hash = _hashCombine(hash, _deepHashCode(command));
    hash = _hashCombine(hash, _deepHashCode(data));
    hash = _hashCombine(hash, _deepHashCode(detail));
    hash = _hashCombine(hash, _deepHashCode(documentation));
    hash = _hashCombine(hash, _deepHashCode(filterText));
    hash = _hashCombine(hash, _deepHashCode(insertText));
    hash = _hashCombine(hash, _deepHashCode(insertTextFormat));
    hash = _hashCombine(hash, _deepHashCode(kind));
    hash = _hashCombine(hash, _deepHashCode(label));
    hash = _hashCombine(hash, _deepHashCode(sortText));
    hash = _hashCombine(hash, _deepHashCode(textEdit));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CompletionItem &&
      _deepEquals(additionalTextEdits, other.additionalTextEdits) &&
      command == other.command &&
      data == other.data &&
      detail == other.detail &&
      documentation == other.documentation &&
      filterText == other.filterText &&
      insertText == other.insertText &&
      insertTextFormat == other.insertTextFormat &&
      kind == other.kind &&
      label == other.label &&
      sortText == other.sortText &&
      textEdit == other.textEdit;
}

class CompletionItem$Builder {
  CompletionItem$Builder._();

  List<TextEdit> additionalTextEdits;

  Command command;

  dynamic data;

  String detail;

  String documentation;

  String filterText;

  String insertText;

  InsertTextFormat insertTextFormat;

  CompletionItemKind kind;

  String label;

  String sortText;

  TextEdit textEdit;
}

class CompletionItemCapabilities {
  CompletionItemCapabilities._(this.snippetSupport);

  factory CompletionItemCapabilities(
      void Function(CompletionItemCapabilities$Builder) init) {
    final b = CompletionItemCapabilities$Builder._();
    init(b);
    return CompletionItemCapabilities._(b.snippetSupport);
  }

  factory CompletionItemCapabilities.fromJson(Map params) =>
      CompletionItemCapabilities._(params.containsKey('snippetSupport') &&
              params['snippetSupport'] != null
          ? (params['snippetSupport'] as bool)
          : null);

  final bool snippetSupport;

  Map toJson() => {'snippetSupport': snippetSupport};
  @override
  int get hashCode {
    var hash = 402194464;
    hash = _hashCombine(hash, _deepHashCode(snippetSupport));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CompletionItemCapabilities &&
      snippetSupport == other.snippetSupport;
}

class CompletionItemCapabilities$Builder {
  CompletionItemCapabilities$Builder._();

  bool snippetSupport;
}

class CompletionItemKind {
  factory CompletionItemKind.fromJson(int value) {
    const values = {
      7: CompletionItemKind.classKind,
      16: CompletionItemKind.color,
      4: CompletionItemKind.constructor,
      13: CompletionItemKind.enumKind,
      5: CompletionItemKind.field,
      17: CompletionItemKind.file,
      3: CompletionItemKind.function,
      8: CompletionItemKind.interface,
      14: CompletionItemKind.keyword,
      2: CompletionItemKind.method,
      9: CompletionItemKind.module,
      10: CompletionItemKind.property,
      18: CompletionItemKind.reference,
      15: CompletionItemKind.snippet,
      1: CompletionItemKind.text,
      11: CompletionItemKind.unit,
      12: CompletionItemKind.value,
      6: CompletionItemKind.variable
    };
    return values[value];
  }

  const CompletionItemKind._(this._value);

  static const classKind = CompletionItemKind._(7);

  static const color = CompletionItemKind._(16);

  static const constructor = CompletionItemKind._(4);

  static const enumKind = CompletionItemKind._(13);

  static const field = CompletionItemKind._(5);

  static const file = CompletionItemKind._(17);

  static const function = CompletionItemKind._(3);

  static const interface = CompletionItemKind._(8);

  static const keyword = CompletionItemKind._(14);

  static const method = CompletionItemKind._(2);

  static const module = CompletionItemKind._(9);

  static const property = CompletionItemKind._(10);

  static const reference = CompletionItemKind._(18);

  static const snippet = CompletionItemKind._(15);

  static const text = CompletionItemKind._(1);

  static const unit = CompletionItemKind._(11);

  static const value = CompletionItemKind._(12);

  static const variable = CompletionItemKind._(6);

  final int _value;

  int toJson() => _value;
}

class CompletionList {
  CompletionList._(this.isIncomplete, this.items);

  factory CompletionList(void Function(CompletionList$Builder) init) {
    final b = CompletionList$Builder._();
    init(b);
    return CompletionList._(b.isIncomplete, b.items);
  }

  factory CompletionList.fromJson(Map params) => CompletionList._(
      params.containsKey('isIncomplete') && params['isIncomplete'] != null
          ? (params['isIncomplete'] as bool)
          : null,
      params.containsKey('items') && params['items'] != null
          ? (params['items'] as List)
              .map((v) => CompletionItem.fromJson((v as Map)))
              .toList()
          : null);

  final bool isIncomplete;

  final List<CompletionItem> items;

  Map toJson() => {
        'isIncomplete': isIncomplete,
        'items': items?.map((v) => v?.toJson())?.toList()
      };
  @override
  int get hashCode {
    var hash = 475661732;
    hash = _hashCombine(hash, _deepHashCode(isIncomplete));
    hash = _hashCombine(hash, _deepHashCode(items));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CompletionList &&
      isIncomplete == other.isIncomplete &&
      _deepEquals(items, other.items);
}

class CompletionList$Builder {
  CompletionList$Builder._();

  bool isIncomplete;

  List<CompletionItem> items;
}

class CompletionOptions {
  CompletionOptions._(this.resolveProvider, this.triggerCharacters);

  factory CompletionOptions(void Function(CompletionOptions$Builder) init) {
    final b = CompletionOptions$Builder._();
    init(b);
    return CompletionOptions._(b.resolveProvider, b.triggerCharacters);
  }

  factory CompletionOptions.fromJson(Map params) => CompletionOptions._(
      params.containsKey('resolveProvider') && params['resolveProvider'] != null
          ? (params['resolveProvider'] as bool)
          : null,
      params.containsKey('triggerCharacters') &&
              params['triggerCharacters'] != null
          ? (params['triggerCharacters'] as List).cast<String>()
          : null);

  final bool resolveProvider;

  final List<String> triggerCharacters;

  Map toJson() => {
        'resolveProvider': resolveProvider,
        'triggerCharacters': triggerCharacters
      };
  @override
  int get hashCode {
    var hash = 251829316;
    hash = _hashCombine(hash, _deepHashCode(resolveProvider));
    hash = _hashCombine(hash, _deepHashCode(triggerCharacters));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is CompletionOptions &&
      resolveProvider == other.resolveProvider &&
      _deepEquals(triggerCharacters, other.triggerCharacters);
}

class CompletionOptions$Builder {
  CompletionOptions$Builder._();

  bool resolveProvider;

  List<String> triggerCharacters;
}

class Diagnostic {
  Diagnostic._(this.code, this.message, this.range, this.severity, this.source);

  factory Diagnostic(void Function(Diagnostic$Builder) init) {
    final b = Diagnostic$Builder._();
    init(b);
    return Diagnostic._(b.code, b.message, b.range, b.severity, b.source);
  }

  factory Diagnostic.fromJson(Map params) => Diagnostic._(
      params.containsKey('code') && params['code'] != null
          ? (params['code'] as dynamic)
          : null,
      params.containsKey('message') && params['message'] != null
          ? (params['message'] as String)
          : null,
      params.containsKey('range') && params['range'] != null
          ? Range.fromJson((params['range'] as Map))
          : null,
      params.containsKey('severity') && params['severity'] != null
          ? (params['severity'] as int)
          : null,
      params.containsKey('source') && params['source'] != null
          ? (params['source'] as String)
          : null);

  final dynamic code;

  final String message;

  final Range range;

  final int severity;

  final String source;

  Map toJson() => {
        'code': code,
        'message': message,
        'range': range?.toJson(),
        'severity': severity,
        'source': source
      };
  @override
  int get hashCode {
    var hash = 304962763;
    hash = _hashCombine(hash, _deepHashCode(code));
    hash = _hashCombine(hash, _deepHashCode(message));
    hash = _hashCombine(hash, _deepHashCode(range));
    hash = _hashCombine(hash, _deepHashCode(severity));
    hash = _hashCombine(hash, _deepHashCode(source));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Diagnostic &&
      code == other.code &&
      message == other.message &&
      range == other.range &&
      severity == other.severity &&
      source == other.source;
}

class Diagnostic$Builder {
  Diagnostic$Builder._();

  dynamic code;

  String message;

  Range range;

  int severity;

  String source;
}

class Diagnostics {
  Diagnostics._(this.diagnostics, this.uri);

  factory Diagnostics(void Function(Diagnostics$Builder) init) {
    final b = Diagnostics$Builder._();
    init(b);
    return Diagnostics._(b.diagnostics, b.uri);
  }

  factory Diagnostics.fromJson(Map params) => Diagnostics._(
      params.containsKey('diagnostics') && params['diagnostics'] != null
          ? (params['diagnostics'] as List)
              .map((v) => Diagnostic.fromJson((v as Map)))
              .toList()
          : null,
      params.containsKey('uri') && params['uri'] != null
          ? (params['uri'] as String)
          : null);

  final List<Diagnostic> diagnostics;

  final String uri;

  Map toJson() => {
        'diagnostics': diagnostics?.map((v) => v?.toJson())?.toList(),
        'uri': uri
      };
  @override
  int get hashCode {
    var hash = 133599092;
    hash = _hashCombine(hash, _deepHashCode(diagnostics));
    hash = _hashCombine(hash, _deepHashCode(uri));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Diagnostics &&
      _deepEquals(diagnostics, other.diagnostics) &&
      uri == other.uri;
}

class Diagnostics$Builder {
  Diagnostics$Builder._();

  List<Diagnostic> diagnostics;

  String uri;
}

class DocumentHighlight {
  DocumentHighlight._(this.kind, this.range);

  factory DocumentHighlight(void Function(DocumentHighlight$Builder) init) {
    final b = DocumentHighlight$Builder._();
    init(b);
    return DocumentHighlight._(b.kind, b.range);
  }

  factory DocumentHighlight.fromJson(Map params) => DocumentHighlight._(
      params.containsKey('kind') && params['kind'] != null
          ? DocumentHighlightKind.fromJson((params['kind'] as int))
          : null,
      params.containsKey('range') && params['range'] != null
          ? Range.fromJson((params['range'] as Map))
          : null);

  final DocumentHighlightKind kind;

  final Range range;

  Map toJson() => {'kind': kind?.toJson(), 'range': range?.toJson()};
  @override
  int get hashCode {
    var hash = 33231655;
    hash = _hashCombine(hash, _deepHashCode(kind));
    hash = _hashCombine(hash, _deepHashCode(range));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentHighlight && kind == other.kind && range == other.range;
}

class DocumentHighlight$Builder {
  DocumentHighlight$Builder._();

  DocumentHighlightKind kind;

  Range range;
}

class DocumentHighlightKind {
  factory DocumentHighlightKind.fromJson(int value) {
    const values = {
      2: DocumentHighlightKind.read,
      1: DocumentHighlightKind.text,
      3: DocumentHighlightKind.write
    };
    return values[value];
  }

  const DocumentHighlightKind._(this._value);

  static const read = DocumentHighlightKind._(2);

  static const text = DocumentHighlightKind._(1);

  static const write = DocumentHighlightKind._(3);

  final int _value;

  int toJson() => _value;
}

class DocumentLinkOptions {
  DocumentLinkOptions._(this.resolveProvider);

  factory DocumentLinkOptions(void Function(DocumentLinkOptions$Builder) init) {
    final b = DocumentLinkOptions$Builder._();
    init(b);
    return DocumentLinkOptions._(b.resolveProvider);
  }

  factory DocumentLinkOptions.fromJson(Map params) => DocumentLinkOptions._(
      params.containsKey('resolveProvider') && params['resolveProvider'] != null
          ? (params['resolveProvider'] as bool)
          : null);

  final bool resolveProvider;

  Map toJson() => {'resolveProvider': resolveProvider};
  @override
  int get hashCode {
    var hash = 370049515;
    hash = _hashCombine(hash, _deepHashCode(resolveProvider));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentLinkOptions && resolveProvider == other.resolveProvider;
}

class DocumentLinkOptions$Builder {
  DocumentLinkOptions$Builder._();

  bool resolveProvider;
}

class DocumentOnTypeFormattingOptions {
  DocumentOnTypeFormattingOptions._(
      this.firstTriggerCharacter, this.moreTriggerCharacter);

  factory DocumentOnTypeFormattingOptions(
      void Function(DocumentOnTypeFormattingOptions$Builder) init) {
    final b = DocumentOnTypeFormattingOptions$Builder._();
    init(b);
    return DocumentOnTypeFormattingOptions._(
        b.firstTriggerCharacter, b.moreTriggerCharacter);
  }

  factory DocumentOnTypeFormattingOptions.fromJson(Map params) =>
      DocumentOnTypeFormattingOptions._(
          params.containsKey('firstTriggerCharacter') &&
                  params['firstTriggerCharacter'] != null
              ? (params['firstTriggerCharacter'] as String)
              : null,
          params.containsKey('moreTriggerCharacter') &&
                  params['moreTriggerCharacter'] != null
              ? (params['moreTriggerCharacter'] as List).cast<String>()
              : null);

  final String firstTriggerCharacter;

  final List<String> moreTriggerCharacter;

  Map toJson() => {
        'firstTriggerCharacter': firstTriggerCharacter,
        'moreTriggerCharacter': moreTriggerCharacter
      };
  @override
  int get hashCode {
    var hash = 519038003;
    hash = _hashCombine(hash, _deepHashCode(firstTriggerCharacter));
    hash = _hashCombine(hash, _deepHashCode(moreTriggerCharacter));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is DocumentOnTypeFormattingOptions &&
      firstTriggerCharacter == other.firstTriggerCharacter &&
      _deepEquals(moreTriggerCharacter, other.moreTriggerCharacter);
}

class DocumentOnTypeFormattingOptions$Builder {
  DocumentOnTypeFormattingOptions$Builder._();

  String firstTriggerCharacter;

  List<String> moreTriggerCharacter;
}

class DynamicRegistrationCapability {
  DynamicRegistrationCapability._(this.dynamicRegistration);

  factory DynamicRegistrationCapability(
      void Function(DynamicRegistrationCapability$Builder) init) {
    final b = DynamicRegistrationCapability$Builder._();
    init(b);
    return DynamicRegistrationCapability._(b.dynamicRegistration);
  }

  factory DynamicRegistrationCapability.fromJson(Map params) =>
      DynamicRegistrationCapability._(
          params.containsKey('dynamicRegistration') &&
                  params['dynamicRegistration'] != null
              ? (params['dynamicRegistration'] as bool)
              : null);

  final bool dynamicRegistration;

  Map toJson() => {'dynamicRegistration': dynamicRegistration};
  @override
  int get hashCode {
    var hash = 400193199;
    hash = _hashCombine(hash, _deepHashCode(dynamicRegistration));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is DynamicRegistrationCapability &&
      dynamicRegistration == other.dynamicRegistration;
}

class DynamicRegistrationCapability$Builder {
  DynamicRegistrationCapability$Builder._();

  bool dynamicRegistration;
}

class ExecuteCommandOptions {
  ExecuteCommandOptions._(this.commands);

  factory ExecuteCommandOptions(
      void Function(ExecuteCommandOptions$Builder) init) {
    final b = ExecuteCommandOptions$Builder._();
    init(b);
    return ExecuteCommandOptions._(b.commands);
  }

  factory ExecuteCommandOptions.fromJson(Map params) => ExecuteCommandOptions._(
      params.containsKey('commands') && params['commands'] != null
          ? (params['commands'] as List).cast<String>()
          : null);

  final List<String> commands;

  Map toJson() => {'commands': commands};
  @override
  int get hashCode {
    var hash = 136451660;
    hash = _hashCombine(hash, _deepHashCode(commands));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is ExecuteCommandOptions && _deepEquals(commands, other.commands);
}

class ExecuteCommandOptions$Builder {
  ExecuteCommandOptions$Builder._();

  List<String> commands;
}

class Hover {
  Hover._(this.contents, this.range);

  factory Hover(void Function(Hover$Builder) init) {
    final b = Hover$Builder._();
    init(b);
    return Hover._(b.contents, b.range);
  }

  factory Hover.fromJson(Map params) => Hover._(
      params.containsKey('contents') && params['contents'] != null
          ? (params['contents'] as String)
          : null,
      params.containsKey('range') && params['range'] != null
          ? Range.fromJson((params['range'] as Map))
          : null);

  final String contents;

  final Range range;

  Map toJson() => {'contents': contents, 'range': range?.toJson()};
  @override
  int get hashCode {
    var hash = 624710494;
    hash = _hashCombine(hash, _deepHashCode(contents));
    hash = _hashCombine(hash, _deepHashCode(range));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Hover && contents == other.contents && range == other.range;
}

class Hover$Builder {
  Hover$Builder._();

  String contents;

  Range range;
}

class HoverCapabilities {
  HoverCapabilities._(this.contentFormat, this.dynamicRegistration);

  factory HoverCapabilities(void Function(HoverCapabilities$Builder) init) {
    final b = HoverCapabilities$Builder._();
    init(b);
    return HoverCapabilities._(b.contentFormat, b.dynamicRegistration);
  }

  factory HoverCapabilities.fromJson(Map params) => HoverCapabilities._(
      params.containsKey('contentFormat') && params['contentFormat'] != null
          ? (params['contentFormat'] as List).cast<String>()
          : null,
      params.containsKey('dynamicRegistration') &&
              params['dynamicRegistration'] != null
          ? (params['dynamicRegistration'] as bool)
          : null);

  final List<String> contentFormat;

  final bool dynamicRegistration;

  Map toJson() => {
        'contentFormat': contentFormat,
        'dynamicRegistration': dynamicRegistration
      };
  @override
  int get hashCode {
    var hash = 400081440;
    hash = _hashCombine(hash, _deepHashCode(contentFormat));
    hash = _hashCombine(hash, _deepHashCode(dynamicRegistration));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is HoverCapabilities &&
      _deepEquals(contentFormat, other.contentFormat) &&
      dynamicRegistration == other.dynamicRegistration;
}

class HoverCapabilities$Builder {
  HoverCapabilities$Builder._();

  List<String> contentFormat;

  bool dynamicRegistration;
}

class HoverMarkup {
  HoverMarkup._(this.contents, this.range);

  factory HoverMarkup(void Function(HoverMarkup$Builder) init) {
    final b = HoverMarkup$Builder._();
    init(b);
    return HoverMarkup._(b.contents, b.range);
  }

  factory HoverMarkup.fromJson(Map params) => HoverMarkup._(
      params.containsKey('contents') && params['contents'] != null
          ? MarkupContent.fromJson((params['contents'] as Map))
          : null,
      params.containsKey('range') && params['range'] != null
          ? Range.fromJson((params['range'] as Map))
          : null);

  final MarkupContent contents;

  final Range range;

  Map toJson() => {'contents': contents?.toJson(), 'range': range?.toJson()};
  @override
  int get hashCode {
    var hash = 207034670;
    hash = _hashCombine(hash, _deepHashCode(contents));
    hash = _hashCombine(hash, _deepHashCode(range));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is HoverMarkup &&
      contents == other.contents &&
      range == other.range;
}

class HoverMarkup$Builder {
  HoverMarkup$Builder._();

  MarkupContent contents;

  Range range;
}

class InsertTextFormat {
  factory InsertTextFormat.fromJson(int value) {
    const values = {1: InsertTextFormat.plainText, 2: InsertTextFormat.snippet};
    return values[value];
  }

  const InsertTextFormat._(this._value);

  static const plainText = InsertTextFormat._(1);

  static const snippet = InsertTextFormat._(2);

  final int _value;

  int toJson() => _value;
}

class Location {
  Location._(this.range, this.uri);

  factory Location(void Function(Location$Builder) init) {
    final b = Location$Builder._();
    init(b);
    return Location._(b.range, b.uri);
  }

  factory Location.fromJson(Map params) => Location._(
      params.containsKey('range') && params['range'] != null
          ? Range.fromJson((params['range'] as Map))
          : null,
      params.containsKey('uri') && params['uri'] != null
          ? (params['uri'] as String)
          : null);

  final Range range;

  final String uri;

  Map toJson() => {'range': range?.toJson(), 'uri': uri};
  @override
  int get hashCode {
    var hash = 1015387949;
    hash = _hashCombine(hash, _deepHashCode(range));
    hash = _hashCombine(hash, _deepHashCode(uri));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Location && range == other.range && uri == other.uri;
}

class Location$Builder {
  Location$Builder._();

  Range range;

  String uri;
}

class MarkupContent {
  MarkupContent._(this.kind, this.value);

  factory MarkupContent(void Function(MarkupContent$Builder) init) {
    final b = MarkupContent$Builder._();
    init(b);
    return MarkupContent._(b.kind, b.value);
  }

  factory MarkupContent.fromJson(Map params) => MarkupContent._(
      params.containsKey('kind') && params['kind'] != null
          ? MarkupContentKind.fromJson((params['kind'] as String))
          : null,
      params.containsKey('value') && params['value'] != null
          ? (params['value'] as String)
          : null);

  final MarkupContentKind kind;

  final String value;

  Map toJson() => {'kind': kind?.toJson(), 'value': value};
  @override
  int get hashCode {
    var hash = 161892004;
    hash = _hashCombine(hash, _deepHashCode(kind));
    hash = _hashCombine(hash, _deepHashCode(value));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is MarkupContent && kind == other.kind && value == other.value;
}

class MarkupContent$Builder {
  MarkupContent$Builder._();

  MarkupContentKind kind;

  String value;
}

class MarkupContentKind {
  factory MarkupContentKind.fromJson(String value) {
    const values = {
      'markdown': MarkupContentKind.markdown,
      'plaintext': MarkupContentKind.plaintext
    };
    return values[value];
  }

  const MarkupContentKind._(this._value);

  static const markdown = MarkupContentKind._('markdown');

  static const plaintext = MarkupContentKind._('plaintext');

  final String _value;

  String toJson() => _value;
}

class MessageType {
  factory MessageType.fromJson(int value) {
    const values = {
      1: MessageType.error,
      3: MessageType.info,
      4: MessageType.log,
      2: MessageType.warning
    };
    return values[value];
  }

  const MessageType._(this._value);

  static const error = MessageType._(1);

  static const info = MessageType._(3);

  static const log = MessageType._(4);

  static const warning = MessageType._(2);

  final int _value;

  int toJson() => _value;
}

class Position {
  Position._(this.character, this.line);

  factory Position(void Function(Position$Builder) init) {
    final b = Position$Builder._();
    init(b);
    return Position._(b.character, b.line);
  }

  factory Position.fromJson(Map params) => Position._(
      params.containsKey('character') && params['character'] != null
          ? (params['character'] as int)
          : null,
      params.containsKey('line') && params['line'] != null
          ? (params['line'] as int)
          : null);

  final int character;

  final int line;

  Map toJson() => {'character': character, 'line': line};
  @override
  int get hashCode {
    var hash = 210930065;
    hash = _hashCombine(hash, _deepHashCode(character));
    hash = _hashCombine(hash, _deepHashCode(line));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Position && character == other.character && line == other.line;
}

class Position$Builder {
  Position$Builder._();

  int character;

  int line;
}

class Range {
  Range._(this.end, this.start);

  factory Range(void Function(Range$Builder) init) {
    final b = Range$Builder._();
    init(b);
    return Range._(b.end, b.start);
  }

  factory Range.fromJson(Map params) => Range._(
      params.containsKey('end') && params['end'] != null
          ? Position.fromJson((params['end'] as Map))
          : null,
      params.containsKey('start') && params['start'] != null
          ? Position.fromJson((params['start'] as Map))
          : null);

  final Position end;

  final Position start;

  Map toJson() => {'end': end?.toJson(), 'start': start?.toJson()};
  @override
  int get hashCode {
    var hash = 682876634;
    hash = _hashCombine(hash, _deepHashCode(end));
    hash = _hashCombine(hash, _deepHashCode(start));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is Range && end == other.end && start == other.start;
}

class Range$Builder {
  Range$Builder._();

  Position end;

  Position start;
}

class ReferenceContext {
  ReferenceContext._(this.includeDeclaration);

  factory ReferenceContext(void Function(ReferenceContext$Builder) init) {
    final b = ReferenceContext$Builder._();
    init(b);
    return ReferenceContext._(b.includeDeclaration);
  }

  factory ReferenceContext.fromJson(Map params) =>
      ReferenceContext._(params.containsKey('includeDeclaration') &&
              params['includeDeclaration'] != null
          ? (params['includeDeclaration'] as bool)
          : null);

  final bool includeDeclaration;

  Map toJson() => {'includeDeclaration': includeDeclaration};
  @override
  int get hashCode {
    var hash = 82198676;
    hash = _hashCombine(hash, _deepHashCode(includeDeclaration));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is ReferenceContext &&
      includeDeclaration == other.includeDeclaration;
}

class ReferenceContext$Builder {
  ReferenceContext$Builder._();

  bool includeDeclaration;
}

class SaveOptions {
  SaveOptions._(this.includeText);

  factory SaveOptions(void Function(SaveOptions$Builder) init) {
    final b = SaveOptions$Builder._();
    init(b);
    return SaveOptions._(b.includeText);
  }

  factory SaveOptions.fromJson(Map params) => SaveOptions._(
      params.containsKey('includeText') && params['includeText'] != null
          ? (params['includeText'] as bool)
          : null);

  final bool includeText;

  Map toJson() => {'includeText': includeText};
  @override
  int get hashCode {
    var hash = 11958891;
    hash = _hashCombine(hash, _deepHashCode(includeText));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is SaveOptions && includeText == other.includeText;
}

class SaveOptions$Builder {
  SaveOptions$Builder._();

  bool includeText;
}

class ServerCapabilities {
  ServerCapabilities._(
      this.codeActionProvider,
      this.codeLensProvider,
      this.completionProvider,
      this.definitionProvider,
      this.documentFormattingProvider,
      this.documentHighlightProvider,
      this.documentLinkProvider,
      this.documentOnTypeFormattingProvider,
      this.documentRangeFormattingProvider,
      this.documentSymbolProvider,
      this.executeCommandProvider,
      this.hoverProvider,
      this.implementationProvider,
      this.referencesProvider,
      this.renameProvider,
      this.signatureHelpProvider,
      this.textDocumentSync,
      this.workspaceSymbolProvider);

  factory ServerCapabilities(void Function(ServerCapabilities$Builder) init) {
    final b = ServerCapabilities$Builder._();
    init(b);
    return ServerCapabilities._(
        b.codeActionProvider,
        b.codeLensProvider,
        b.completionProvider,
        b.definitionProvider,
        b.documentFormattingProvider,
        b.documentHighlightProvider,
        b.documentLinkProvider,
        b.documentOnTypeFormattingProvider,
        b.documentRangeFormattingProvider,
        b.documentSymbolProvider,
        b.executeCommandProvider,
        b.hoverProvider,
        b.implementationProvider,
        b.referencesProvider,
        b.renameProvider,
        b.signatureHelpProvider,
        b.textDocumentSync,
        b.workspaceSymbolProvider);
  }

  factory ServerCapabilities.fromJson(Map params) => ServerCapabilities._(
      params.containsKey('codeActionProvider') && params['codeActionProvider'] != null
          ? (params['codeActionProvider'] as bool)
          : null,
      params.containsKey('codeLensProvider') && params['codeLensProvider'] != null
          ? CodeLensOptions.fromJson((params['codeLensProvider'] as Map))
          : null,
      params.containsKey('completionProvider') && params['completionProvider'] != null
          ? CompletionOptions.fromJson((params['completionProvider'] as Map))
          : null,
      params.containsKey('definitionProvider') && params['definitionProvider'] != null
          ? (params['definitionProvider'] as bool)
          : null,
      params.containsKey('documentFormattingProvider') && params['documentFormattingProvider'] != null
          ? (params['documentFormattingProvider'] as bool)
          : null,
      params.containsKey('documentHighlightProvider') && params['documentHighlightProvider'] != null
          ? (params['documentHighlightProvider'] as bool)
          : null,
      params.containsKey('documentLinkProvider') && params['documentLinkProvider'] != null
          ? DocumentLinkOptions.fromJson(
              (params['documentLinkProvider'] as Map))
          : null,
      params.containsKey('documentOnTypeFormattingProvider') && params['documentOnTypeFormattingProvider'] != null
          ? DocumentOnTypeFormattingOptions.fromJson(
              (params['documentOnTypeFormattingProvider'] as Map))
          : null,
      params.containsKey('documentRangeFormattingProvider') && params['documentRangeFormattingProvider'] != null
          ? (params['documentRangeFormattingProvider'] as bool)
          : null,
      params.containsKey('documentSymbolProvider') && params['documentSymbolProvider'] != null
          ? (params['documentSymbolProvider'] as bool)
          : null,
      params.containsKey('executeCommandProvider') && params['executeCommandProvider'] != null
          ? ExecuteCommandOptions.fromJson((params['executeCommandProvider'] as Map))
          : null,
      params.containsKey('hoverProvider') && params['hoverProvider'] != null ? (params['hoverProvider'] as bool) : null,
      params.containsKey('implementationProvider') && params['implementationProvider'] != null ? (params['implementationProvider'] as bool) : null,
      params.containsKey('referencesProvider') && params['referencesProvider'] != null ? (params['referencesProvider'] as bool) : null,
      params.containsKey('renameProvider') && params['renameProvider'] != null ? (params['renameProvider'] as bool) : null,
      params.containsKey('signatureHelpProvider') && params['signatureHelpProvider'] != null ? SignatureHelpOptions.fromJson((params['signatureHelpProvider'] as Map)) : null,
      params.containsKey('textDocumentSync') && params['textDocumentSync'] != null ? TextDocumentSyncOptions.fromJson((params['textDocumentSync'] as Map)) : null,
      params.containsKey('workspaceSymbolProvider') && params['workspaceSymbolProvider'] != null ? (params['workspaceSymbolProvider'] as bool) : null);

  final bool codeActionProvider;

  final CodeLensOptions codeLensProvider;

  final CompletionOptions completionProvider;

  final bool definitionProvider;

  final bool documentFormattingProvider;

  final bool documentHighlightProvider;

  final DocumentLinkOptions documentLinkProvider;

  final DocumentOnTypeFormattingOptions documentOnTypeFormattingProvider;

  final bool documentRangeFormattingProvider;

  final bool documentSymbolProvider;

  final ExecuteCommandOptions executeCommandProvider;

  final bool hoverProvider;

  final bool implementationProvider;

  final bool referencesProvider;

  final bool renameProvider;

  final SignatureHelpOptions signatureHelpProvider;

  final TextDocumentSyncOptions textDocumentSync;

  final bool workspaceSymbolProvider;

  Map toJson() => {
        'codeActionProvider': codeActionProvider,
        'codeLensProvider': codeLensProvider?.toJson(),
        'completionProvider': completionProvider?.toJson(),
        'definitionProvider': definitionProvider,
        'documentFormattingProvider': documentFormattingProvider,
        'documentHighlightProvider': documentHighlightProvider,
        'documentLinkProvider': documentLinkProvider?.toJson(),
        'documentOnTypeFormattingProvider':
            documentOnTypeFormattingProvider?.toJson(),
        'documentRangeFormattingProvider': documentRangeFormattingProvider,
        'documentSymbolProvider': documentSymbolProvider,
        'executeCommandProvider': executeCommandProvider?.toJson(),
        'hoverProvider': hoverProvider,
        'implementationProvider': implementationProvider,
        'referencesProvider': referencesProvider,
        'renameProvider': renameProvider,
        'signatureHelpProvider': signatureHelpProvider?.toJson(),
        'textDocumentSync': textDocumentSync?.toJson(),
        'workspaceSymbolProvider': workspaceSymbolProvider
      };
  @override
  int get hashCode {
    var hash = 659932873;
    hash = _hashCombine(hash, _deepHashCode(codeActionProvider));
    hash = _hashCombine(hash, _deepHashCode(codeLensProvider));
    hash = _hashCombine(hash, _deepHashCode(completionProvider));
    hash = _hashCombine(hash, _deepHashCode(definitionProvider));
    hash = _hashCombine(hash, _deepHashCode(documentFormattingProvider));
    hash = _hashCombine(hash, _deepHashCode(documentHighlightProvider));
    hash = _hashCombine(hash, _deepHashCode(documentLinkProvider));
    hash = _hashCombine(hash, _deepHashCode(documentOnTypeFormattingProvider));
    hash = _hashCombine(hash, _deepHashCode(documentRangeFormattingProvider));
    hash = _hashCombine(hash, _deepHashCode(documentSymbolProvider));
    hash = _hashCombine(hash, _deepHashCode(executeCommandProvider));
    hash = _hashCombine(hash, _deepHashCode(hoverProvider));
    hash = _hashCombine(hash, _deepHashCode(implementationProvider));
    hash = _hashCombine(hash, _deepHashCode(referencesProvider));
    hash = _hashCombine(hash, _deepHashCode(renameProvider));
    hash = _hashCombine(hash, _deepHashCode(signatureHelpProvider));
    hash = _hashCombine(hash, _deepHashCode(textDocumentSync));
    hash = _hashCombine(hash, _deepHashCode(workspaceSymbolProvider));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is ServerCapabilities &&
      codeActionProvider == other.codeActionProvider &&
      codeLensProvider == other.codeLensProvider &&
      completionProvider == other.completionProvider &&
      definitionProvider == other.definitionProvider &&
      documentFormattingProvider == other.documentFormattingProvider &&
      documentHighlightProvider == other.documentHighlightProvider &&
      documentLinkProvider == other.documentLinkProvider &&
      documentOnTypeFormattingProvider ==
          other.documentOnTypeFormattingProvider &&
      documentRangeFormattingProvider ==
          other.documentRangeFormattingProvider &&
      documentSymbolProvider == other.documentSymbolProvider &&
      executeCommandProvider == other.executeCommandProvider &&
      hoverProvider == other.hoverProvider &&
      implementationProvider == other.implementationProvider &&
      referencesProvider == other.referencesProvider &&
      renameProvider == other.renameProvider &&
      signatureHelpProvider == other.signatureHelpProvider &&
      textDocumentSync == other.textDocumentSync &&
      workspaceSymbolProvider == other.workspaceSymbolProvider;
}

class ServerCapabilities$Builder {
  ServerCapabilities$Builder._();

  bool codeActionProvider;

  CodeLensOptions codeLensProvider;

  CompletionOptions completionProvider;

  bool definitionProvider;

  bool documentFormattingProvider;

  bool documentHighlightProvider;

  DocumentLinkOptions documentLinkProvider;

  DocumentOnTypeFormattingOptions documentOnTypeFormattingProvider;

  bool documentRangeFormattingProvider;

  bool documentSymbolProvider;

  ExecuteCommandOptions executeCommandProvider;

  bool hoverProvider;

  bool implementationProvider;

  bool referencesProvider;

  bool renameProvider;

  SignatureHelpOptions signatureHelpProvider;

  TextDocumentSyncOptions textDocumentSync;

  bool workspaceSymbolProvider;
}

class ShowMessageParams {
  ShowMessageParams._(this.message, this.type);

  factory ShowMessageParams(void Function(ShowMessageParams$Builder) init) {
    final b = ShowMessageParams$Builder._();
    init(b);
    return ShowMessageParams._(b.message, b.type);
  }

  factory ShowMessageParams.fromJson(Map params) => ShowMessageParams._(
      params.containsKey('message') && params['message'] != null
          ? (params['message'] as String)
          : null,
      params.containsKey('type') && params['type'] != null
          ? MessageType.fromJson((params['type'] as int))
          : null);

  final String message;

  final MessageType type;

  Map toJson() => {'message': message, 'type': type?.toJson()};
  @override
  int get hashCode {
    var hash = 684261254;
    hash = _hashCombine(hash, _deepHashCode(message));
    hash = _hashCombine(hash, _deepHashCode(type));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is ShowMessageParams &&
      message == other.message &&
      type == other.type;
}

class ShowMessageParams$Builder {
  ShowMessageParams$Builder._();

  String message;

  MessageType type;
}

class SignatureHelpOptions {
  SignatureHelpOptions._(this.triggerCharacters);

  factory SignatureHelpOptions(
      void Function(SignatureHelpOptions$Builder) init) {
    final b = SignatureHelpOptions$Builder._();
    init(b);
    return SignatureHelpOptions._(b.triggerCharacters);
  }

  factory SignatureHelpOptions.fromJson(Map params) =>
      SignatureHelpOptions._(params.containsKey('triggerCharacters') &&
              params['triggerCharacters'] != null
          ? (params['triggerCharacters'] as List).cast<String>()
          : null);

  final List<String> triggerCharacters;

  Map toJson() => {'triggerCharacters': triggerCharacters};
  @override
  int get hashCode {
    var hash = 979113728;
    hash = _hashCombine(hash, _deepHashCode(triggerCharacters));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is SignatureHelpOptions &&
      _deepEquals(triggerCharacters, other.triggerCharacters);
}

class SignatureHelpOptions$Builder {
  SignatureHelpOptions$Builder._();

  List<String> triggerCharacters;
}

class SymbolInformation {
  SymbolInformation._(this.containerName, this.kind, this.location, this.name);

  factory SymbolInformation(void Function(SymbolInformation$Builder) init) {
    final b = SymbolInformation$Builder._();
    init(b);
    return SymbolInformation._(b.containerName, b.kind, b.location, b.name);
  }

  factory SymbolInformation.fromJson(Map params) => SymbolInformation._(
      params.containsKey('containerName') && params['containerName'] != null
          ? (params['containerName'] as String)
          : null,
      params.containsKey('kind') && params['kind'] != null
          ? SymbolKind.fromJson((params['kind'] as int))
          : null,
      params.containsKey('location') && params['location'] != null
          ? Location.fromJson((params['location'] as Map))
          : null,
      params.containsKey('name') && params['name'] != null
          ? (params['name'] as String)
          : null);

  final String containerName;

  final SymbolKind kind;

  final Location location;

  final String name;

  Map toJson() => {
        'containerName': containerName,
        'kind': kind?.toJson(),
        'location': location?.toJson(),
        'name': name
      };
  @override
  int get hashCode {
    var hash = 260018179;
    hash = _hashCombine(hash, _deepHashCode(containerName));
    hash = _hashCombine(hash, _deepHashCode(kind));
    hash = _hashCombine(hash, _deepHashCode(location));
    hash = _hashCombine(hash, _deepHashCode(name));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is SymbolInformation &&
      containerName == other.containerName &&
      kind == other.kind &&
      location == other.location &&
      name == other.name;
}

class SymbolInformation$Builder {
  SymbolInformation$Builder._();

  String containerName;

  SymbolKind kind;

  Location location;

  String name;
}

class SymbolKind {
  factory SymbolKind.fromJson(int value) {
    const values = {
      18: SymbolKind.array,
      17: SymbolKind.boolean,
      5: SymbolKind.classSymbol,
      14: SymbolKind.constant,
      9: SymbolKind.constructor,
      22: SymbolKind.enumMember,
      10: SymbolKind.enumSymbol,
      24: SymbolKind.event,
      8: SymbolKind.field,
      1: SymbolKind.file,
      12: SymbolKind.function,
      11: SymbolKind.interface,
      20: SymbolKind.key,
      6: SymbolKind.method,
      2: SymbolKind.module,
      3: SymbolKind.namespace,
      21: SymbolKind.nullSymbol,
      16: SymbolKind.number,
      19: SymbolKind.object,
      25: SymbolKind.operator,
      4: SymbolKind.package,
      7: SymbolKind.property,
      15: SymbolKind.string,
      23: SymbolKind.struct,
      26: SymbolKind.typeParameter,
      13: SymbolKind.variable
    };
    return values[value];
  }

  const SymbolKind._(this._value);

  static const array = SymbolKind._(18);

  static const boolean = SymbolKind._(17);

  static const classSymbol = SymbolKind._(5);

  static const constant = SymbolKind._(14);

  static const constructor = SymbolKind._(9);

  static const enumMember = SymbolKind._(22);

  static const enumSymbol = SymbolKind._(10);

  static const event = SymbolKind._(24);

  static const field = SymbolKind._(8);

  static const file = SymbolKind._(1);

  static const function = SymbolKind._(12);

  static const interface = SymbolKind._(11);

  static const key = SymbolKind._(20);

  static const method = SymbolKind._(6);

  static const module = SymbolKind._(2);

  static const namespace = SymbolKind._(3);

  static const nullSymbol = SymbolKind._(21);

  static const number = SymbolKind._(16);

  static const object = SymbolKind._(19);

  static const operator = SymbolKind._(25);

  static const package = SymbolKind._(4);

  static const property = SymbolKind._(7);

  static const string = SymbolKind._(15);

  static const struct = SymbolKind._(23);

  static const typeParameter = SymbolKind._(26);

  static const variable = SymbolKind._(13);

  final int _value;

  int toJson() => _value;
}

class SynchronizationCapabilities {
  SynchronizationCapabilities._(this.didSave, this.dynamicRegistration,
      this.willSave, this.willSaveWaitUntil);

  factory SynchronizationCapabilities(
      void Function(SynchronizationCapabilities$Builder) init) {
    final b = SynchronizationCapabilities$Builder._();
    init(b);
    return SynchronizationCapabilities._(
        b.didSave, b.dynamicRegistration, b.willSave, b.willSaveWaitUntil);
  }

  factory SynchronizationCapabilities.fromJson(
          Map params) =>
      SynchronizationCapabilities._(
          params.containsKey('didSave') && params['didSave'] != null
              ? (params['didSave'] as bool)
              : null,
          params.containsKey('dynamicRegistration') &&
                  params['dynamicRegistration'] != null
              ? (params['dynamicRegistration'] as bool)
              : null,
          params.containsKey('willSave') && params['willSave'] != null
              ? (params['willSave'] as bool)
              : null,
          params.containsKey('willSaveWaitUntil') &&
                  params['willSaveWaitUntil'] != null
              ? (params['willSaveWaitUntil'] as bool)
              : null);

  final bool didSave;

  final bool dynamicRegistration;

  final bool willSave;

  final bool willSaveWaitUntil;

  Map toJson() => {
        'didSave': didSave,
        'dynamicRegistration': dynamicRegistration,
        'willSave': willSave,
        'willSaveWaitUntil': willSaveWaitUntil
      };
  @override
  int get hashCode {
    var hash = 1050620504;
    hash = _hashCombine(hash, _deepHashCode(didSave));
    hash = _hashCombine(hash, _deepHashCode(dynamicRegistration));
    hash = _hashCombine(hash, _deepHashCode(willSave));
    hash = _hashCombine(hash, _deepHashCode(willSaveWaitUntil));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is SynchronizationCapabilities &&
      didSave == other.didSave &&
      dynamicRegistration == other.dynamicRegistration &&
      willSave == other.willSave &&
      willSaveWaitUntil == other.willSaveWaitUntil;
}

class SynchronizationCapabilities$Builder {
  SynchronizationCapabilities$Builder._();

  bool didSave;

  bool dynamicRegistration;

  bool willSave;

  bool willSaveWaitUntil;
}

class TextDocumentClientCapabilities {
  TextDocumentClientCapabilities._(
      this.codeAction,
      this.codeLens,
      this.completion,
      this.definition,
      this.documentHighlight,
      this.documentLink,
      this.documentSymbol,
      this.formatting,
      this.hover,
      this.onTypeFormatting,
      this.references,
      this.rename,
      this.synchronization);

  factory TextDocumentClientCapabilities(
      void Function(TextDocumentClientCapabilities$Builder) init) {
    final b = TextDocumentClientCapabilities$Builder._();
    init(b);
    return TextDocumentClientCapabilities._(
        b.codeAction,
        b.codeLens,
        b.completion,
        b.definition,
        b.documentHighlight,
        b.documentLink,
        b.documentSymbol,
        b.formatting,
        b.hover,
        b.onTypeFormatting,
        b.references,
        b.rename,
        b.synchronization);
  }

  factory TextDocumentClientCapabilities.fromJson(Map params) => TextDocumentClientCapabilities._(
      params.containsKey('codeAction') && params['codeAction'] != null
          ? CodeActionCapabilities.fromJson((params['codeAction'] as Map))
          : null,
      params.containsKey('codeLens') && params['codeLens'] != null
          ? DynamicRegistrationCapability.fromJson((params['codeLens'] as Map))
          : null,
      params.containsKey('completion') && params['completion'] != null
          ? CompletionCapabilities.fromJson((params['completion'] as Map))
          : null,
      params.containsKey('definition') && params['definition'] != null
          ? DynamicRegistrationCapability.fromJson(
              (params['definition'] as Map))
          : null,
      params.containsKey('documentHighlight') &&
              params['documentHighlight'] != null
          ? DynamicRegistrationCapability.fromJson(
              (params['documentHighlight'] as Map))
          : null,
      params.containsKey('documentLink') && params['documentLink'] != null
          ? DynamicRegistrationCapability.fromJson(
              (params['documentLink'] as Map))
          : null,
      params.containsKey('documentSymbol') && params['documentSymbol'] != null
          ? DynamicRegistrationCapability.fromJson(
              (params['documentSymbol'] as Map))
          : null,
      params.containsKey('formatting') && params['formatting'] != null
          ? DynamicRegistrationCapability.fromJson(
              (params['formatting'] as Map))
          : null,
      params.containsKey('hover') && params['hover'] != null
          ? HoverCapabilities.fromJson((params['hover'] as Map))
          : null,
      params.containsKey('onTypeFormatting') && params['onTypeFormatting'] != null
          ? DynamicRegistrationCapability.fromJson(
              (params['onTypeFormatting'] as Map))
          : null,
      params.containsKey('references') && params['references'] != null
          ? DynamicRegistrationCapability.fromJson((params['references'] as Map))
          : null,
      params.containsKey('rename') && params['rename'] != null ? DynamicRegistrationCapability.fromJson((params['rename'] as Map)) : null,
      params.containsKey('synchronization') && params['synchronization'] != null ? SynchronizationCapabilities.fromJson((params['synchronization'] as Map)) : null);

  final CodeActionCapabilities codeAction;

  final DynamicRegistrationCapability codeLens;

  final CompletionCapabilities completion;

  final DynamicRegistrationCapability definition;

  final DynamicRegistrationCapability documentHighlight;

  final DynamicRegistrationCapability documentLink;

  final DynamicRegistrationCapability documentSymbol;

  final DynamicRegistrationCapability formatting;

  final HoverCapabilities hover;

  final DynamicRegistrationCapability onTypeFormatting;

  final DynamicRegistrationCapability references;

  final DynamicRegistrationCapability rename;

  final SynchronizationCapabilities synchronization;

  Map toJson() => {
        'codeAction': codeAction?.toJson(),
        'codeLens': codeLens?.toJson(),
        'completion': completion?.toJson(),
        'definition': definition?.toJson(),
        'documentHighlight': documentHighlight?.toJson(),
        'documentLink': documentLink?.toJson(),
        'documentSymbol': documentSymbol?.toJson(),
        'formatting': formatting?.toJson(),
        'hover': hover?.toJson(),
        'onTypeFormatting': onTypeFormatting?.toJson(),
        'references': references?.toJson(),
        'rename': rename?.toJson(),
        'synchronization': synchronization?.toJson()
      };
  @override
  int get hashCode {
    var hash = 242077660;
    hash = _hashCombine(hash, _deepHashCode(codeAction));
    hash = _hashCombine(hash, _deepHashCode(codeLens));
    hash = _hashCombine(hash, _deepHashCode(completion));
    hash = _hashCombine(hash, _deepHashCode(definition));
    hash = _hashCombine(hash, _deepHashCode(documentHighlight));
    hash = _hashCombine(hash, _deepHashCode(documentLink));
    hash = _hashCombine(hash, _deepHashCode(documentSymbol));
    hash = _hashCombine(hash, _deepHashCode(formatting));
    hash = _hashCombine(hash, _deepHashCode(hover));
    hash = _hashCombine(hash, _deepHashCode(onTypeFormatting));
    hash = _hashCombine(hash, _deepHashCode(references));
    hash = _hashCombine(hash, _deepHashCode(rename));
    hash = _hashCombine(hash, _deepHashCode(synchronization));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is TextDocumentClientCapabilities &&
      codeAction == other.codeAction &&
      codeLens == other.codeLens &&
      completion == other.completion &&
      definition == other.definition &&
      documentHighlight == other.documentHighlight &&
      documentLink == other.documentLink &&
      documentSymbol == other.documentSymbol &&
      formatting == other.formatting &&
      hover == other.hover &&
      onTypeFormatting == other.onTypeFormatting &&
      references == other.references &&
      rename == other.rename &&
      synchronization == other.synchronization;
}

class TextDocumentClientCapabilities$Builder {
  TextDocumentClientCapabilities$Builder._();

  CodeActionCapabilities codeAction;

  DynamicRegistrationCapability codeLens;

  CompletionCapabilities completion;

  DynamicRegistrationCapability definition;

  DynamicRegistrationCapability documentHighlight;

  DynamicRegistrationCapability documentLink;

  DynamicRegistrationCapability documentSymbol;

  DynamicRegistrationCapability formatting;

  HoverCapabilities hover;

  DynamicRegistrationCapability onTypeFormatting;

  DynamicRegistrationCapability references;

  DynamicRegistrationCapability rename;

  SynchronizationCapabilities synchronization;
}

class TextDocumentContentChangeEvent {
  TextDocumentContentChangeEvent._(this.range, this.rangeLength, this.text);

  factory TextDocumentContentChangeEvent(
      void Function(TextDocumentContentChangeEvent$Builder) init) {
    final b = TextDocumentContentChangeEvent$Builder._();
    init(b);
    return TextDocumentContentChangeEvent._(b.range, b.rangeLength, b.text);
  }

  factory TextDocumentContentChangeEvent.fromJson(Map params) =>
      TextDocumentContentChangeEvent._(
          params.containsKey('range') && params['range'] != null
              ? Range.fromJson((params['range'] as Map))
              : null,
          params.containsKey('rangeLength') && params['rangeLength'] != null
              ? (params['rangeLength'] as int)
              : null,
          params.containsKey('text') && params['text'] != null
              ? (params['text'] as String)
              : null);

  final Range range;

  final int rangeLength;

  final String text;

  Map toJson() =>
      {'range': range?.toJson(), 'rangeLength': rangeLength, 'text': text};
  @override
  int get hashCode {
    var hash = 180616113;
    hash = _hashCombine(hash, _deepHashCode(range));
    hash = _hashCombine(hash, _deepHashCode(rangeLength));
    hash = _hashCombine(hash, _deepHashCode(text));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is TextDocumentContentChangeEvent &&
      range == other.range &&
      rangeLength == other.rangeLength &&
      text == other.text;
}

class TextDocumentContentChangeEvent$Builder {
  TextDocumentContentChangeEvent$Builder._();

  Range range;

  int rangeLength;

  String text;
}

class TextDocumentIdentifier {
  TextDocumentIdentifier._(this.uri);

  factory TextDocumentIdentifier(
      void Function(TextDocumentIdentifier$Builder) init) {
    final b = TextDocumentIdentifier$Builder._();
    init(b);
    return TextDocumentIdentifier._(b.uri);
  }

  factory TextDocumentIdentifier.fromJson(Map params) =>
      TextDocumentIdentifier._(
          params.containsKey('uri') && params['uri'] != null
              ? (params['uri'] as String)
              : null);

  final String uri;

  Map toJson() => {'uri': uri};
  @override
  int get hashCode {
    var hash = 553241737;
    hash = _hashCombine(hash, _deepHashCode(uri));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is TextDocumentIdentifier && uri == other.uri;
}

class TextDocumentIdentifier$Builder {
  TextDocumentIdentifier$Builder._();

  String uri;
}

class TextDocumentItem {
  TextDocumentItem._(this.languageId, this.text, this.uri, this.version);

  factory TextDocumentItem(void Function(TextDocumentItem$Builder) init) {
    final b = TextDocumentItem$Builder._();
    init(b);
    return TextDocumentItem._(b.languageId, b.text, b.uri, b.version);
  }

  factory TextDocumentItem.fromJson(Map params) => TextDocumentItem._(
      params.containsKey('languageId') && params['languageId'] != null
          ? (params['languageId'] as String)
          : null,
      params.containsKey('text') && params['text'] != null
          ? (params['text'] as String)
          : null,
      params.containsKey('uri') && params['uri'] != null
          ? (params['uri'] as String)
          : null,
      params.containsKey('version') && params['version'] != null
          ? (params['version'] as int)
          : null);

  final String languageId;

  final String text;

  final String uri;

  final int version;

  Map toJson() =>
      {'languageId': languageId, 'text': text, 'uri': uri, 'version': version};
  @override
  int get hashCode {
    var hash = 448755309;
    hash = _hashCombine(hash, _deepHashCode(languageId));
    hash = _hashCombine(hash, _deepHashCode(text));
    hash = _hashCombine(hash, _deepHashCode(uri));
    hash = _hashCombine(hash, _deepHashCode(version));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is TextDocumentItem &&
      languageId == other.languageId &&
      text == other.text &&
      uri == other.uri &&
      version == other.version;
}

class TextDocumentItem$Builder {
  TextDocumentItem$Builder._();

  String languageId;

  String text;

  String uri;

  int version;
}

class TextDocumentSyncKind {
  factory TextDocumentSyncKind.fromJson(int value) {
    const values = {
      1: TextDocumentSyncKind.full,
      2: TextDocumentSyncKind.incremental,
      0: TextDocumentSyncKind.none
    };
    return values[value];
  }

  const TextDocumentSyncKind._(this._value);

  static const full = TextDocumentSyncKind._(1);

  static const incremental = TextDocumentSyncKind._(2);

  static const none = TextDocumentSyncKind._(0);

  final int _value;

  int toJson() => _value;
}

class TextDocumentSyncOptions {
  TextDocumentSyncOptions._(this.change, this.openClose, this.save,
      this.willSave, this.willSaveWaitUntil);

  factory TextDocumentSyncOptions(
      void Function(TextDocumentSyncOptions$Builder) init) {
    final b = TextDocumentSyncOptions$Builder._();
    init(b);
    return TextDocumentSyncOptions._(
        b.change, b.openClose, b.save, b.willSave, b.willSaveWaitUntil);
  }

  factory TextDocumentSyncOptions.fromJson(
          Map params) =>
      TextDocumentSyncOptions._(
          params.containsKey('change') && params['change'] != null
              ? TextDocumentSyncKind.fromJson((params['change'] as int))
              : null,
          params.containsKey('openClose') && params['openClose'] != null
              ? (params['openClose'] as bool)
              : null,
          params.containsKey('save') && params['save'] != null
              ? SaveOptions.fromJson((params['save'] as Map))
              : null,
          params.containsKey('willSave') && params['willSave'] != null
              ? (params['willSave'] as bool)
              : null,
          params.containsKey('willSaveWaitUntil') &&
                  params['willSaveWaitUntil'] != null
              ? (params['willSaveWaitUntil'] as bool)
              : null);

  final TextDocumentSyncKind change;

  final bool openClose;

  final SaveOptions save;

  final bool willSave;

  final bool willSaveWaitUntil;

  Map toJson() => {
        'change': change?.toJson(),
        'openClose': openClose,
        'save': save?.toJson(),
        'willSave': willSave,
        'willSaveWaitUntil': willSaveWaitUntil
      };
  @override
  int get hashCode {
    var hash = 541969480;
    hash = _hashCombine(hash, _deepHashCode(change));
    hash = _hashCombine(hash, _deepHashCode(openClose));
    hash = _hashCombine(hash, _deepHashCode(save));
    hash = _hashCombine(hash, _deepHashCode(willSave));
    hash = _hashCombine(hash, _deepHashCode(willSaveWaitUntil));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is TextDocumentSyncOptions &&
      change == other.change &&
      openClose == other.openClose &&
      save == other.save &&
      willSave == other.willSave &&
      willSaveWaitUntil == other.willSaveWaitUntil;
}

class TextDocumentSyncOptions$Builder {
  TextDocumentSyncOptions$Builder._();

  TextDocumentSyncKind change;

  bool openClose;

  SaveOptions save;

  bool willSave;

  bool willSaveWaitUntil;
}

class TextEdit {
  TextEdit._(this.newText, this.range);

  factory TextEdit(void Function(TextEdit$Builder) init) {
    final b = TextEdit$Builder._();
    init(b);
    return TextEdit._(b.newText, b.range);
  }

  factory TextEdit.fromJson(Map params) => TextEdit._(
      params.containsKey('newText') && params['newText'] != null
          ? (params['newText'] as String)
          : null,
      params.containsKey('range') && params['range'] != null
          ? Range.fromJson((params['range'] as Map))
          : null);

  final String newText;

  final Range range;

  Map toJson() => {'newText': newText, 'range': range?.toJson()};
  @override
  int get hashCode {
    var hash = 1034224162;
    hash = _hashCombine(hash, _deepHashCode(newText));
    hash = _hashCombine(hash, _deepHashCode(range));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is TextEdit && newText == other.newText && range == other.range;
}

class TextEdit$Builder {
  TextEdit$Builder._();

  String newText;

  Range range;
}

class VersionedTextDocumentIdentifier {
  VersionedTextDocumentIdentifier._(this.uri, this.version);

  factory VersionedTextDocumentIdentifier(
      void Function(VersionedTextDocumentIdentifier$Builder) init) {
    final b = VersionedTextDocumentIdentifier$Builder._();
    init(b);
    return VersionedTextDocumentIdentifier._(b.uri, b.version);
  }

  factory VersionedTextDocumentIdentifier.fromJson(Map params) =>
      VersionedTextDocumentIdentifier._(
          params.containsKey('uri') && params['uri'] != null
              ? (params['uri'] as String)
              : null,
          params.containsKey('version') && params['version'] != null
              ? (params['version'] as int)
              : null);

  final String uri;

  final int version;

  Map toJson() => {'uri': uri, 'version': version};
  @override
  int get hashCode {
    var hash = 6046273;
    hash = _hashCombine(hash, _deepHashCode(uri));
    hash = _hashCombine(hash, _deepHashCode(version));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is VersionedTextDocumentIdentifier &&
      uri == other.uri &&
      version == other.version;
}

class VersionedTextDocumentIdentifier$Builder {
  VersionedTextDocumentIdentifier$Builder._();

  String uri;

  int version;
}

class WorkspaceClientCapabilities {
  WorkspaceClientCapabilities._(this.applyEdit, this.didChangeConfiguration,
      this.didChangeWatchedFiles, this.executeCommand, this.symbol);

  factory WorkspaceClientCapabilities(
      void Function(WorkspaceClientCapabilities$Builder) init) {
    final b = WorkspaceClientCapabilities$Builder._();
    init(b);
    return WorkspaceClientCapabilities._(b.applyEdit, b.didChangeConfiguration,
        b.didChangeWatchedFiles, b.executeCommand, b.symbol);
  }

  factory WorkspaceClientCapabilities.fromJson(
          Map params) =>
      WorkspaceClientCapabilities._(
          params.containsKey('applyEdit') && params['applyEdit'] != null
              ? (params['applyEdit'] as bool)
              : null,
          params.containsKey('didChangeConfiguration') &&
                  params['didChangeConfiguration'] != null
              ? DynamicRegistrationCapability.fromJson(
                  (params['didChangeConfiguration'] as Map))
              : null,
          params.containsKey('didChangeWatchedFiles') &&
                  params['didChangeWatchedFiles'] != null
              ? DynamicRegistrationCapability.fromJson(
                  (params['didChangeWatchedFiles'] as Map))
              : null,
          params.containsKey('executeCommand') &&
                  params['executeCommand'] != null
              ? DynamicRegistrationCapability.fromJson(
                  (params['executeCommand'] as Map))
              : null,
          params.containsKey('symbol') && params['symbol'] != null
              ? DynamicRegistrationCapability.fromJson(
                  (params['symbol'] as Map))
              : null);

  final bool applyEdit;

  final DynamicRegistrationCapability didChangeConfiguration;

  final DynamicRegistrationCapability didChangeWatchedFiles;

  final DynamicRegistrationCapability executeCommand;

  final DynamicRegistrationCapability symbol;

  Map toJson() => {
        'applyEdit': applyEdit,
        'didChangeConfiguration': didChangeConfiguration?.toJson(),
        'didChangeWatchedFiles': didChangeWatchedFiles?.toJson(),
        'executeCommand': executeCommand?.toJson(),
        'symbol': symbol?.toJson()
      };
  @override
  int get hashCode {
    var hash = 1031534926;
    hash = _hashCombine(hash, _deepHashCode(applyEdit));
    hash = _hashCombine(hash, _deepHashCode(didChangeConfiguration));
    hash = _hashCombine(hash, _deepHashCode(didChangeWatchedFiles));
    hash = _hashCombine(hash, _deepHashCode(executeCommand));
    hash = _hashCombine(hash, _deepHashCode(symbol));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is WorkspaceClientCapabilities &&
      applyEdit == other.applyEdit &&
      didChangeConfiguration == other.didChangeConfiguration &&
      didChangeWatchedFiles == other.didChangeWatchedFiles &&
      executeCommand == other.executeCommand &&
      symbol == other.symbol;
}

class WorkspaceClientCapabilities$Builder {
  WorkspaceClientCapabilities$Builder._();

  bool applyEdit;

  DynamicRegistrationCapability didChangeConfiguration;

  DynamicRegistrationCapability didChangeWatchedFiles;

  DynamicRegistrationCapability executeCommand;

  DynamicRegistrationCapability symbol;
}

class WorkspaceEdit {
  WorkspaceEdit._(this.changes);

  factory WorkspaceEdit(void Function(WorkspaceEdit$Builder) init) {
    final b = WorkspaceEdit$Builder._();
    init(b);
    return WorkspaceEdit._(b.changes);
  }

  factory WorkspaceEdit.fromJson(Map params) =>
      WorkspaceEdit._(params.containsKey('changes') && params['changes'] != null
          ? (params['changes'] as Map).map((k, v) =>
              MapEntry<String, List<TextEdit>>(
                  (k as String),
                  (v as List)
                      .map((v) => TextEdit.fromJson((v as Map)))
                      .toList()))
          : null);

  final Map<String, List<TextEdit>> changes;

  Map toJson() => {
        'changes': changes?.map((k, v) =>
            MapEntry<String, dynamic>(k, v?.map((v) => v?.toJson())?.toList()))
      };
  @override
  int get hashCode {
    var hash = 920194645;
    hash = _hashCombine(hash, _deepHashCode(changes));
    return _hashComplete(hash);
  }

  @override
  bool operator ==(Object other) =>
      other is WorkspaceEdit && _deepEquals(changes, other.changes);
}

class WorkspaceEdit$Builder {
  WorkspaceEdit$Builder._();

  Map<String, List<TextEdit>> changes;
}

int _hashCombine(int hash, int value) {
  hash = 0x1fffffff & (hash + value);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int _hashComplete(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}

int _deepHashCode(dynamic value) {
  if (value is List) {
    return value.map(_deepHashCode).reduce(_hashCombine);
  }
  if (value is Map) {
    return (value.keys
            .map((key) => _hashCombine(key.hashCode, _deepHashCode(value[key])))
            .toList(growable: false)
              ..sort())
        .reduce(_hashCombine);
  }
  return value.hashCode;
}

bool _deepEquals(dynamic left, dynamic right) {
  if (left is List && right is List) {
    final leftLength = left.length;
    final rightLength = right.length;
    if (leftLength != rightLength) return false;
    for (var i = 0; i < leftLength; i++) {
      if (!_deepEquals(left[i], right[i])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    final leftLength = left.length;
    final rightLength = right.length;
    if (leftLength != rightLength) return false;
    for (final key in left.keys) {
      if (!_deepEquals(left[key], right[key])) return false;
    }
    return true;
  }
  return left == right;
}
