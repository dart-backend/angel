import 'dart:async';
import 'dart:io';

import 'package:json_rpc_2/json_rpc_2.dart';

import 'interface.dart';
import 'messages.dart';
import 'wireformat.dart';

/// A Language Server communicating over stdin and stdout.
class StdIOLanguageServer {
  final LanguageServer _server;
  Future<void> onDone;

  /// Wrap [_server] and register RPC methods using the LSP wire protocol.
  ///
  /// Methods are guarded against being called before the server is initialized.
  StdIOLanguageServer.start(this._server) {
    final peer = Peer(lspChannel(stdin, stdout));

    _lifecycleMethods(peer);
    _fileHandlingMethods(peer);
    _notifications(peer);
    _completionMethods(peer);
    _referenceMethods(peer);
    _codeActionMethods(peer);

    _server.setupExtraMethods(peer);

    peer.listen();

    onDone = _server.onDone.then((_) => peer.close()).then((_) => null);
  }

  bool _isInitialized = false;

  void _lifecycleMethods(Peer peer) {
    peer
      ..registerMethod('initialize', (params) async {
        final serverCapabilities = await _server.initialize(
            params['processId'].valueOr(0) as int,
            params['rootUri'].valueOr('') as String,
            ClientCapabilities.fromJson(params['capabilities'].value as Map),
            params['trace'].valueOr('off') as String);
        _isInitialized = true;
        return {'capabilities': serverCapabilities.toJson()};
      })
      ..registerMethod('initialized', (params) => _server.initialized())
      ..registerMethod('shutdown', _server.shutdown)
      ..registerMethod('exit', _server.exit);
  }

  /// Register a request that will throw if throw if used before initialization.
  void _registerRequest(Peer peer, String methodName, Function callback) {
    peer.registerMethod(methodName, (params) {
      if (!_isInitialized) {
        throw RpcException(-32003, 'The server has not been initialized');
      }
      return callback(params);
    });
  }

  /// Notifications are ignored until after initialization.
  void _registerNotification(Peer peer, String methodName, Function callback) {
    peer.registerMethod(methodName, (params) {
      if (_isInitialized) return callback(params);
    });
  }

  void _fileHandlingMethods(Peer peer) {
    _registerNotification(peer, 'textDocument/didOpen', (params) {
      _server.textDocumentDidOpen(_documentItem(params));
    });
    _registerNotification(peer, 'textDocument/didChange', (params) {
      _server.textDocumentDidChange(
          _versionedDocument(params), _contentChanges(params));
    });
    _registerNotification(peer, 'textDocument/didClose', (params) {
      _server.textDocumentDidClose(_document(params));
    });
  }

  void _notifications(Peer peer) {
    _server
      ..diagnostics.map((d) => d.toJson()).forEach((diagnostics) =>
          peer.sendNotification('textDocument/publishDiagnostics', diagnostics))
      ..workspaceEdits.map((e) => e.toJson()).forEach((edit) {
        // Ignore response?
        peer.sendRequest('workspace/applyEdit', edit);
      })
      ..logMessages.map((e) => e.toJson()).forEach(
          (message) => peer.sendNotification('window/logMessage', message))
      ..showMessages.map((e) => e.toJson()).forEach(
          (message) => peer.sendNotification('window/showMessage', message));
  }

  void _completionMethods(Peer peer) {
    _registerRequest(
        peer,
        'textDocument/completion',
        (params) => _server
            .textDocumentCompletion(_document(params), _position(params))
            .then((r) => r.toJson()));
  }

  void _referenceMethods(Peer peer) {
    _registerRequest(
        peer,
        'textDocument/definition',
        (params) => _server
            .textDocumentDefinition(_document(params), _position(params))
            .then((r) => r?.toJson()));
    _registerRequest(
        peer,
        'textDocument/hover',
        (params) => _server
            .textDocumentHover(_document(params), _position(params))
            .then((r) => r?.toJson()));
    _registerRequest(
        peer,
        'textDocument/references',
        (params) => _server
            .textDocumentReferences(
                _document(params), _position(params), _referenceContext(params))
            .then((r) => r?.map((e) => e.toJson())?.toList()));
    _registerRequest(
        peer,
        'textDocument/implementation',
        (params) => _server
            .textDocumentImplementation(_document(params), _position(params))
            .then((r) => r?.map((e) => e.toJson())?.toList()));
    _registerRequest(
        peer,
        'textDocument/documentHighlight',
        (params) => _server
            .textDocumentHighlight(_document(params), _position(params))
            .then((r) => r?.map((e) => e.toJson())?.toList()));
    _registerRequest(
        peer,
        'textDocument/documentSymbol',
        (params) => _server
            .textDocumentSymbols(_document(params))
            .then((r) => r?.map((e) => e.toJson())?.toList()));
    _registerRequest(
        peer,
        'workspace/symbol',
        (params) => _server
            .workspaceSymbol(_query(params))
            .then((r) => r?.map((e) => e.toJson())?.toList()));
  }

  void _codeActionMethods(Peer peer) {
    _registerRequest(
        peer,
        'textDocument/codeAction',
        (params) => _server
            .textDocumentCodeAction(
                _document(params), _range(params), _codeActionContext(params))
            .then((r) => r?.map((e) => e.toJson())?.toList()));
    _registerRequest(
        peer,
        'workspace/executeCommand',
        (params) => _server.workspaceExecuteCommand(
            params['command'].value as String,
            params['arguments']?.value as List));
    _registerRequest(
        peer,
        'textDocument/rename',
        (params) async => (await _server.textDocumentRename(_document(params),
                _position(params), params['newName'].value as String))
            .toJson());
  }
}

TextDocumentItem _documentItem(params) =>
    TextDocumentItem.fromJson(params['textDocument'].value as Map);

VersionedTextDocumentIdentifier _versionedDocument(params) =>
    VersionedTextDocumentIdentifier.fromJson(
        params['textDocument'].value as Map);

TextDocumentIdentifier _document(params) =>
    TextDocumentIdentifier.fromJson(params['textDocument'].value as Map);

Range _range(params) => Range.fromJson(params['range'].value as Map);

Position _position(params) =>
    Position.fromJson(params['position'].value as Map);

CodeActionContext _codeActionContext(params) =>
    CodeActionContext.fromJson(params['context'].value as Map);

ReferenceContext _referenceContext(params) =>
    ReferenceContext.fromJson(params['context'].value as Map);

List<TextDocumentContentChangeEvent> _contentChanges(params) =>
    (params['contentChanges'].value as Iterable)
        .map((change) => TextDocumentContentChangeEvent.fromJson(change as Map))
        .toList();

String _query(params) => params['query'].value as String;
