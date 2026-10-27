import 'package:angel3_framework/angel3_framework.dart';
import 'package:user_agent_analyzer/user_agent_analyzer.dart';

export 'package:user_agent_analyzer/user_agent_analyzer.dart';

/// The requests [parseUserAgent] has run on.
final Expando<bool> _parsed = Expando('parseUserAgent');

/// Injects a [UserAgent] factory into requests.
///
/// Because it is an injected factory, the user agent will not be
/// parsed until you request it via `req.container!.make<UserAgent>()`, which
/// throws a 400 if the request has no `User-Agent` header. It is parsed once
/// per request, also when made from a child container of the request's.
bool parseUserAgent(RequestContext req, ResponseContext res) {
  // Already run on the request, e.g. as another use of this middleware. A
  // [UserAgent] of the app's container does not count: it is not the
  // request's.
  if (_parsed[req] == true) return true;
  _parsed[req] = true;

  // Kept here rather than as a lazy singleton, which a child container
  // would make again.
  UserAgent? userAgent;
  req.container!.registerFactory<UserAgent>((_) {
    if (userAgent != null) return userAgent!;
    var agentString = req.headers?.value('user-agent')?.trim();
    if (agentString == null || agentString.isEmpty) {
      throw AngelHttpException.badRequest(
        message: 'User-Agent header is required.',
      );
    }
    return userAgent = UserAgent(agentString);
  });

  return true;
}
