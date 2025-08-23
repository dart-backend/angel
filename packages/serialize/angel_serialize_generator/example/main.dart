// ignore_for_file: unused_element
import 'package:angel3_serialize/angel3_serialize.dart';
part 'main.g.dart';

@serializable
class TodoEntity {
  String? text;
  bool? completed;
}
