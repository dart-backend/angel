import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_websocket/server.dart';
import 'package:quiver/core.dart';

part 'common.g.dart';

class Game {
  final String? playerOne, playerTwo;

  const Game({this.playerOne, this.playerTwo});

  factory Game.fromJson(Map data) => Game(
    playerOne: data['playerOne'].toString(),
    playerTwo: data['playerTwo'].toString(),
  );

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

/// Of `@ExposeWs`, found through the reflection data generated for it
/// (regenerate it with `dart run build_runner build`).
@injectable
@Expose('/game')
class GameController extends WebSocketController {
  GameController(super.ws);

  @ExposeWs('search')
  dynamic search(WebSocketContext socket) async {
    print('User is searching for a game...');
    socket.send('searched', johnVsBob);
  }
}

/// The [GameController] of [WebSocketController.exposeWs], which needs no
/// reflection.
@Expose('/game')
class RegisteredGameController extends WebSocketController {
  RegisteredGameController(super.ws);

  @override
  void configureWs() {
    exposeWs('search', (action, socket) => socket.send('searched', johnVsBob));
  }
}
