/// Not exported: the errors that close a raw response abruptly.
library;

import 'package:meta/meta.dart';

import 'response_context.dart';

/// The errors added to raw responses to close them abruptly; see
/// [abortErrorOf].
final Expando<bool> _abortErrors = Expando('abort errors');

/// The error to add to a raw response (e.g. an `HttpResponse`) to close it
/// abruptly because of [error]: [error] itself, marked so that
/// [isAbortError] knows it, or a [ResponseAborted] of it if it cannot be
/// marked (a string or a number).
///
/// `dart:io` reports such an error as uncaught in the zone that serves the
/// connection, even when the response's `done` is awaited, so
/// `Driver.startServer` serves in a zone that ignores them.
@internal
Object abortErrorOf(Object error) {
  try {
    _abortErrors[error] = true;
    return error;
  } on ArgumentError {
    return ResponseAborted(error);
  }
}

/// Whether [error] was added to a raw response by [abortErrorOf].
@internal
bool isAbortError(Object error) {
  if (error is ResponseAborted) return true;
  try {
    return _abortErrors[error] ?? false;
  } on ArgumentError {
    return false;
  }
}
