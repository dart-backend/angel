import 'package:angel3_serialize/angel3_serialize.dart';
part 'game_pad_button.g.dart';

@serializable
abstract class GamepadButtonEntity {
  String? get name;
  int? get radius;
}

@serializable
class GamepadEntity {
  List<GamepadButtonEntity>? buttons;

  Map<String, dynamic>? dynamicMap;

  // ignore: unused_field
  String? _somethingPrivate;
}
