import 'package:angel3_framework/angel3_framework.dart';
import 'package:user_agent_analyzer/user_agent_analyzer.dart';

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
