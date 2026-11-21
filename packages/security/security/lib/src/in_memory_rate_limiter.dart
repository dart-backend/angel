import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';

import 'rate_limiter.dart';
import 'rate_limiting_window.dart';

/// A simple [RateLimiter] implementation that uses a simple in-memory map
/// to store rate limiting information.
class InMemoryRateLimiter<User> extends RateLimiter<User> {
  /// A callback used to compute the current user.
  final FutureOr<User> Function(RequestContext, ResponseContext) getUser;
  final _cache = <User, RateLimitingWindow<User>>{};

  /// When ended windows were last removed from the cache.
  DateTime? _lastPrune;

  InMemoryRateLimiter(
    super.maxPointsPerWindow,
    super.windowDuration,
    this.getUser, {
    super.errorMessage,
  });

  @override
  FutureOr<RateLimitingWindow<User>> getCurrentWindow(
    RequestContext req,
    ResponseContext res,
    DateTime currentTime,
  ) async {
    _prune(currentTime);
    var user = await getUser(req, res);
    return _cache[user] ??= RateLimitingWindow(user, currentTime, 0);
  }

  /// Removes the windows that have ended, at most once per window, so the
  /// cache does not keep one entry for every user ever seen (e.g. every IP).
  void _prune(DateTime currentTime) {
    var last = _lastPrune;
    // A clock set back (a negative difference) prunes too, rather than
    // waiting until it catches up.
    var since = last == null ? null : currentTime.difference(last);
    if (since != null && !since.isNegative && since < windowDuration) return;
    _lastPrune = currentTime;
    // A window that starts after now was made before the clock was set back.
    _cache.removeWhere(
      (_, window) =>
          window.startTime.isAfter(currentTime) ||
          !currentTime.isBefore(window.startTime.add(windowDuration)),
    );
  }

  @override
  FutureOr<void> updateCurrentWindow(
    RequestContext req,
    ResponseContext res,
    RateLimitingWindow<User> window,
    DateTime currentTime,
  ) {
    _cache[window.user] = window;
  }
}
