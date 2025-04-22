import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/game.dart';
import '../models/card.dart';

class WebSocketService with ChangeNotifier {
  late IO.Socket socket;
  Game? game;
  String? error;

  WebSocketService() {
    socket = IO.io('http://192.168.8.210:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      print('Socket connected');
      notifyListeners();
    });

    socket.onConnectError((data) {
      print('Connect error: $data');
      error = 'Connection failed: $data';
      notifyListeners();
    });

    socket.on('gameUpdate', (data) {
      print('Received gameUpdate: $data');
      try {
        game = Game.fromJson(data);
        error = null;
      } catch (e) {
        print('Error parsing game: $e');
        error = 'Failed to load game: $e';
      }
      notifyListeners();
    });

    socket.on('error', (data) {
      print('Received error: $data');
      error = data.toString();
      notifyListeners();
    });
  }

  void connect() {
    socket.connect();
  }

  void requestGameState(String gameId) {
    print('Requesting game state for $gameId');
    socket.emit('requestGameState', {'gameId': gameId});
  }

  void joinGame(String gameId, String playerId, String playerName, {bool isTestMode = false}) {
    print('Joining game: $gameId, player: $playerId, test: $isTestMode');
    socket.emit('join', {
      'gameId': gameId,
      'playerId': playerId,
      'playerName': playerName,
      'isTestMode': isTestMode,
    });
  }
  void startGame(String gameId, String playerId) {
    print('Starting game: $gameId, player: $playerId');
    socket.emit('startGame', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void playPattern(String gameId, String playerId, List<Cards> cards, List<Cards> hand) {
    print('WebSocket: Sending playPattern with cards: ${cards.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
    socket.emit('playPattern', {
      'gameId': gameId,
      'playerId': playerId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  void pass(String gameId, String playerId) {
    print('WebSocket: Sending pass for player $playerId in game $gameId');
    socket.emit('pass', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void takeChance(String gameId, String playerId, List<Cards> cards, List<Cards> hand) {
    print('WebSocket: Sending takeChance with cards: ${cards.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
    socket.emit('takeChance', {
      'gameId': gameId,
      'playerId': playerId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  void updateHandOrder(String gameId, String playerId, List<Cards> hand) {
    print('WebSocket: Sending updateHandOrder with hand: ${hand.map((c) => c.isJoker ? "${c.suit} (${c.assignedRank} of ${c.assignedSuit})" : "${c.rank} of ${c.suit}").toList()}');
    socket.emit('updateHandOrder', {
      'gameId': gameId,
      'playerId': playerId,
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }
}