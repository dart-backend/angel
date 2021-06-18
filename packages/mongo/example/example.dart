import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_mongo/angel3_mongo.dart';
import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  var app = Angel();
  var db = Db('mongodb://localhost:27017/local');
  await db.open();

  var service = app.use('/api/users', MongoService(db.collection('users')));

  service.afterCreated.listen((event) {
    print('New user: ${event.result}');
  });
}
