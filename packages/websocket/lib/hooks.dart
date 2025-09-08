import 'package:angel3_framework/angel3_framework.dart';

/// Prevents a WebSocket event from being broadcasted, to any client from the given [provider].
///
/// [provider] can be a String, a [Provider], or an Iterable.
/// If [provider] is `null`, any provider will be blocked.
HookedServiceEventListener doNotBroadcast([Object? provider]) {
  return (HookedServiceEvent e) {
    if (e.params.containsKey('provider')) {
      var eParam = e.params;
      var deny = false;
      var providers = provider is Iterable ? provider : [provider];

      for (var p in providers) {
        if (deny) break;

        if (p is Providers) {
          deny = deny || p == eParam['provider'] || eParam['provider'] == p.via;
        } else if (p == null) {
          deny = true;
        } else {
          deny = deny || (eParam['provider'] as Providers).via == p.toString();
        }
      }

      eParam['broadcast'] = false;
    }
  };
}
