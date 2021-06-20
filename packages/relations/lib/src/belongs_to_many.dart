import 'dart:async';
import 'dart:mirrors';
import 'package:angel_framework/angel_framework.dart';
import 'plural.dart' as pluralize;
import 'no_service.dart';

/// Represents a relationship in which the current [service] "belongs to"
/// multiple members of the service at [servicePath]. Use [as] to set the name
/// on the target object.
///
/// Defaults:
/// * [foreignKey]: `userId`
/// * [localKey]: `id`
HookedServiceEventListener belongsToMany(Pattern servicePath,
    {String? as,
    String? foreignKey,
    String? localKey,
    Function(dynamic obj)? getForeignKey,
    Function(dynamic foreign, dynamic obj)? assignForeignObject}) {
  var localId = localKey;
  var foreignName =
      as?.isNotEmpty == true ? as! : pluralize.plural(servicePath.toString());

  localId ??= foreignName + 'Id';

  return (HookedServiceEvent e) async {
    var ref = e.getService(servicePath);
    if (ref == null) throw noService(servicePath);

    dynamic _getForeignKey(obj) {
      if (getForeignKey != null) {
        return getForeignKey(obj);
      } else if (obj is Map) {
        return obj[localId];
      } else if (localId == null || localId == 'userId') {
        return obj.userId;
      } else {
        return reflect(obj).getField(Symbol(localId)).reflectee;
      }
    }

    dynamic _assignForeignObject(foreign, obj) {
      if (assignForeignObject != null) {
        return assignForeignObject(foreign as List?, obj);
      } else if (obj is Map) {
        obj[foreignName] = foreign;
      } else {
        reflect(obj).setField(Symbol(foreignName), foreign);
      }
    }

    Future<void> _normalize(obj) async {
      if (obj != null) {
        var id = await _getForeignKey(obj);
        var indexed = await ref.index({
          'query': {foreignKey ?? 'id': id}
        });

        if (indexed == null || indexed is! List || indexed.isNotEmpty != true) {
          await _assignForeignObject(null, obj);
        } else {
          var child = indexed is Iterable ? indexed.toList() : [indexed];
          await _assignForeignObject(child, obj);
        }
      }
    }

    if (e.result is Iterable) {
      //await Future.wait(e.result.map(_normalize));
      await e.result.map(_normalize);
    } else {
      await _normalize(e.result);
    }
  };
}
