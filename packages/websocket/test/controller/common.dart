import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_websocket/server.dart';
import 'package:quiver/core.dart';

class Game {
  final String? playerOne, playerTwo;

  const Game({this.playerOne, this.playerTwo});

  factory Game.fromJson(Map data) => Game(
      playerOne: data['playerOne'].toString(),
      playerTwo: data['playerTwo'].toString());

  Map<String, dynamic> toJson() {
    return {'playerOne': playerOne, 'playerTwo': playerTwo};
  }

  @override
  bool operator ==(other) =>
      other is Game &&
      other.playerOne == playerOne &&
      other.playerTwo == playerTwo;

  @override
  int get hashCode => hash2(playerOne, playerTwo);
}

const Game johnVsBob = Game(playerOne: 'John', playerTwo: 'Bob');

@Expose('/game')
class GameController extends WebSocketController {
  GameController(AngelWebSocket ws) : super(ws);

  @ExposeWs('search')
  dynamic search(WebSocketContext socket) async {
    print('User is searching for a game...');
    socket.send('searched', johnVsBob);
  }
}
