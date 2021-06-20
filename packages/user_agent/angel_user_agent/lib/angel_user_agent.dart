import 'package:angel_framework/angel_framework.dart';
import 'package:user_agent/user_agent.dart';

/// Injects a [UserAgent] factory into requests.
///
/// Because it is an injected factory, the user agent will not be
/// parsed until you request it via `req.container.make<UserAgent>()`.
bool parseUserAgent(RequestContext req, ResponseContext res) {
  req.container!.registerFactory<UserAgent>((container) {
    var agentString = req.headers!.value('user-agent');

    if (agentString?.trim().isNotEmpty != true) {
      throw AngelHttpException.badRequest(
          message: 'User-Agent header is required.');
    } else if (agentString != null) {
      var userAgent = UserAgent(agentString);
      container.registerSingleton<UserAgent>(userAgent);
      return userAgent;
    }

    // TODO: To be reviewed
    return UserAgent('unknown');
  });

  return true;
}
