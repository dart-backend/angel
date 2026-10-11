import 'dart:io';

import 'headers.dart';

/// Headers that can be locked to editing, i.e. after a request body has been written.
class LockableMockHttpHeaders extends MockHttpHeaders {
  bool _locked = false;

  StateError _stateError() =>
      StateError('Cannot modify headers after they have been write-locked.');

  void lock() {
    _locked = true;
  }

  // Writes through MockHttpHeaders.set, past the lock checks here.
  void _setContentLengthUnlocked(int length) =>
      super.set(HttpHeaders.contentLengthHeader, length);

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    if (_locked) {
      throw _stateError();
    } else {
      super.add(name, value, preserveHeaderCase: preserveHeaderCase);
    }
  }

  @override
  void clear() {
    if (_locked) {
      throw _stateError();
    } else {
      super.clear();
    }
  }

  @override
  void noFolding(String name) {
    if (_locked) {
      throw _stateError();
    } else {
      super.noFolding(name);
    }
  }

  @override
  void remove(String name, Object value) {
    if (_locked) {
      throw _stateError();
    } else {
      super.remove(name, value);
    }
  }

  @override
  void removeAll(String name) {
    if (_locked) {
      throw _stateError();
    } else {
      super.removeAll(name);
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    if (_locked) {
      throw _stateError();
    } else {
      super.set(name, value, preserveHeaderCase: preserveHeaderCase);
    }
  }

  // Like the header writes above, as in dart:io.
  @override
  set persistentConnection(bool value) {
    if (_locked) throw _stateError();
    super.persistentConnection = value;
  }

  @override
  set host(String? host) {
    if (_locked) throw _stateError();
    super.host = host;
  }

  @override
  set port(int? port) {
    if (_locked) throw _stateError();
    super.port = port;
  }
}

/// Sets the content-length of [headers] even when they are locked, for
/// `MockHttpRequest.close`. Not exported from the package.
void setLockedContentLength(LockableMockHttpHeaders headers, int length) =>
    headers._setContentLengthUnlocked(length);
