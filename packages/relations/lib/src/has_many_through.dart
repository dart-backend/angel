import 'dart:async';
import 'dart:mirrors';
import 'package:angel_framework/angel_framework.dart';
import 'plural.dart' as pluralize;
import 'no_service.dart';

HookedServiceEventListener hasManyThrough(String servicePath, String pivotPath,
    {String? as,
    String? localKey,
    String? pivotKey,
    String? foreignKey,
    Function(dynamic obj)? getLocalKey,
    Function(dynamic obj)? getPivotKey,
    Function(dynamic obj)? getForeignKey,
    Function(dynamic foreign, dynamic obj)? assignForeignObjects}) {
  var foreignName =
      as?.isNotEmpty == true ? as : pluralize.plural(servicePath.toString());

  return (HookedServiceEvent e) async {
    var pivotService = e.getService(pivotPath);
    var foreignService = e.getService(servicePath);

    if (pivotService == null) {
      throw noService(pivotPath);
    } else if (foreignService == null) throw noService(servicePath);

    dynamic _assignForeignObjects(foreign, obj) {
      if (assignForeignObjects != null) {
        return assignForeignObjects(foreign, obj);
      } else if (obj is Map) {
        obj[foreignName] = foreign;
      } else {
        reflect(obj).setField(Symbol(foreignName!), foreign);
      }
    }

    dynamic _getLocalKey(obj) {
      if (getLocalKey != null) {
        return getLocalKey(obj);
      } else if (obj is Map) {
        return obj[localKey ?? 'id'];
      } else if (localKey == null || localKey == 'id') {
        return obj.id;
      } else {
        return reflect(obj).getField(Symbol(localKey)).reflectee;
      }
    }

    dynamic _getPivotKey(obj) {
      if (getPivotKey != null) {
        return getPivotKey(obj);
      } else if (obj is Map) {
        return obj[pivotKey ?? 'id'];
      } else if (pivotKey == null || pivotKey == 'id') {
        return obj.id;
      } else {
        return reflect(obj).getField(Symbol(pivotKey)).reflectee;
      }
    }

    Future _normalize(obj) async {
      // First, resolve pivot
      var id = await _getLocalKey(obj);
      var indexed = await pivotService.index({
        'query': {pivotKey ?? 'userId': id}
      });

      if (indexed is! List || indexed.isNotEmpty != true) {
        await _assignForeignObjects([], obj);
      } else {
        // Now, resolve from foreign service
        var mapped = await Future.wait(indexed.map((pivot) async {
          var id = await _getPivotKey(obj);
          var indexed = await foreignService.index({
            'query': {foreignKey ?? 'postId': id}
          });

          if (indexed is! List || indexed.isNotEmpty != true) {
            await _assignForeignObjects([], pivot);
          } else {
            await _assignForeignObjects(indexed, pivot);
          }

          return pivot;
        }));
        await _assignForeignObjects(mapped, obj);
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
