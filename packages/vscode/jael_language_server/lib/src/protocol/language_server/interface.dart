import 'dart:async';

import 'package:json_rpc_2/json_rpc_2.dart';

import 'messages.dart';

abstract class LanguageServer {
  final _onDone = Completer<void>();
  Future<void> get onDone => _onDone.future;

  Future<void> shutdown() async {}
  void exit() {
    _onDone.complete();
  }

  Future<ServerCapabilities> initialize(int clientPid, String rootUri,
          ClientCapabilities clientCapabilities, String trace) async =>
      ServerCapabilities((b) => b);
  void initialized() {}
  void textDocumentDidOpen(TextDocumentItem document) {}
  void textDocumentDidChange(VersionedTextDocumentIdentifier documentId,
      List<TextDocumentContentChangeEvent> changes) {}
  void textDocumentDidClose(TextDocumentIdentifier documentId) {}
  Future<CompletionList> textDocumentCompletion(
          TextDocumentIdentifier documentId, Position position) async =>
      CompletionList((b) => b);
  Future<Location> textDocumentDefinition(
          TextDocumentIdentifier documentId, Position position) async =>
      null;
  Future<List<Location>> textDocumentReferences(
          TextDocumentIdentifier documentId,
          Position position,
          ReferenceContext context) async =>
      [];
  Future<List<Location>> textDocumentImplementation(
          TextDocumentIdentifier documentId, Position position) async =>
      [];
  Future<List<DocumentHighlight>> textDocumentHighlight(
          TextDocumentIdentifier documentId, Position position) async =>
      [];
  Future<List<SymbolInformation>> textDocumentSymbols(
          TextDocumentIdentifier documentId) async =>
      [];
  Future<List<SymbolInformation>> workspaceSymbol(String query) async => [];
  Future<dynamic> textDocumentHover(
          TextDocumentIdentifier documentId, Position position) async =>
      null;
  Future<List<dynamic /*Command|CodeAction*/ >> textDocumentCodeAction(
          TextDocumentIdentifier documentId,
          Range range,
          CodeActionContext context) async =>
      [];
  Future<void> workspaceExecuteCommand(
      String command, List<dynamic> arguments) async {}
  Future<WorkspaceEdit> textDocumentRename(TextDocumentIdentifier documentId,
          Position position, String newName) async =>
      null;
  Stream<Diagnostics> get diagnostics => Stream.empty();
  Stream<ApplyWorkspaceEditParams> get workspaceEdits => Stream.empty();
  Stream<ShowMessageParams> get showMessages => Stream.empty();
  Stream<ShowMessageParams> get logMessages => Stream.empty();

  void setupExtraMethods(Peer peer) {}
}
