import 'dart:async';
import 'package:angel3_framework/angel3_framework.dart';
import 'rate_limiter.dart';
import 'rate_limiting_window.dart';

/// A RateLimiter] implementation that uses a [Service]
/// to store rate limiting information.
class ServiceRateLimiter<Id> extends RateLimiter<Id> {
  /// The underlying [Service] used to store data.
  final Service<Id, Map<String, dynamic>> service;

  /// A callback used to compute the current user ID.
  final FutureOr<Id> Function(RequestContext, ResponseContext) getId;

  ServiceRateLimiter(
      super.maxPointsPerWindow, super.windowDuration, this.service, this.getId,
      {super.errorMessage});

  @override
  FutureOr<RateLimitingWindow<Id>> getCurrentWindow(
      RequestContext req, ResponseContext res, DateTime currentTime) async {
    var id = await getId(req, res);
    try {
      var data = await service.read(id);
      return RateLimitingWindow.fromJson(data);
    } catch (e) {
      if (e is AngelHttpException) {
        if (e.statusCode == 404) {
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    var window = RateLimitingWindow(id, currentTime, 0);
    await updateCurrentWindow(req, res, window, currentTime);
    return window;
  }

  @override
  FutureOr<void> updateCurrentWindow(RequestContext req, ResponseContext res,
      RateLimitingWindow<Id> window, DateTime currentTime) async {
    await service.update(window.user, window.toJson());
  }
}
