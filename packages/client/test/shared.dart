import 'package:angel3_model/angel3_model.dart';
import 'package:quiver/core.dart';

class Postcard extends Model {
  String? location;
  String? message;

  Postcard({String? id, this.location, this.message}) {
    this.id = id;
  }

  factory Postcard.fromJson(Map data) => Postcard(
      id: data['id'].toString(),
      location: data['location'].toString(),
      message: data['message'].toString());

  @override
  bool operator ==(other) {
    if (other is! Postcard) return false;

    return id == other.id &&
        location == other.location &&
        message == other.message;
  }

  Map toJson() {
    return {'id': id, 'location': location, 'message': message};
  }

  @override
  int get hashCode => hash2(id, location);
}
