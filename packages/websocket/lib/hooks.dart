import 'package:angel3_framework/angel3_framework.dart';

/// Prevents a WebSocket event from being broadcasted, to any client from the given [provider].
///
/// [provider] can be a String, a [Provider], or an Iterable.
/// If [provider] is `null`, any provider will be blocked.
HookedServiceEventListener<Id, Data, T>
doNotBroadcast<Id, Data, T extends Service<Id, Data>>([Object? provider]) {
  return (HookedServiceEvent<Id, Data, T> e) {
    if (e.params.containsKey('provider')) {
      var eParam = e.params;
      var deny = false;
      var providers = provider is Iterable ? provider : [provider];

      for (var p in providers) {
        if (deny) break;

        var given = eParam['provider'];
        var via = given is Providers ? given.via : given?.toString();
        if (p is Providers) {
          deny = p == given || p.via == via;
        } else if (p == null) {
          deny = true;
        } else {
          deny = via == p.toString();
        }
      }

      if (deny) eParam['broadcast'] = false;
    }
  };
}
