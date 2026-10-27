import 'dart:io';

import 'headers.dart';

/// Headers that can be locked to editing, i.e. after a request body has been written.
class LockableMockHttpHeaders extends MockHttpHeaders {
  bool _locked = false;

  // Every change to the headers goes through this, as in dart:io.
  void _checkLocked() {
    if (_locked) {
      throw StateError(
        'Cannot modify headers after they have been write-locked.',
      );
    }
  }

  void lock() {
    _locked = true;
  }

  // Writes through MockHttpHeaders.set, past the lock checks here.
  void _setContentLengthUnlocked(int length) =>
      super.set(HttpHeaders.contentLengthHeader, length);

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkLocked();
    super.add(name, value, preserveHeaderCase: preserveHeaderCase);
  }

  @override
  void clear() {
    _checkLocked();
    super.clear();
  }

  @override
  void noFolding(String name) {
    _checkLocked();
    super.noFolding(name);
  }

  @override
  void remove(String name, Object value) {
    _checkLocked();
    super.remove(name, value);
  }

  @override
  void removeAll(String name) {
    _checkLocked();
    super.removeAll(name);
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkLocked();
    super.set(name, value, preserveHeaderCase: preserveHeaderCase);
  }

  @override
  set persistentConnection(bool value) {
    _checkLocked();
    super.persistentConnection = value;
  }

  @override
  set host(String? host) {
    _checkLocked();
    super.host = host;
  }

  @override
  set port(int? port) {
    _checkLocked();
    super.port = port;
  }
}

/// Sets the content-length of [headers] even when they are locked, for
/// `MockHttpRequest.close`. Not exported from the package.
void setLockedContentLength(LockableMockHttpHeaders headers, int length) =>
    headers._setContentLengthUnlocked(length);
