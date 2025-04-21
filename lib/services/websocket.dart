import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/game.dart';
import '../models/card.dart';

class WebSocketService with ChangeNotifier {
  late IO.Socket socket;
  Game? game;
  String? error;


  WebSocketService() {
    socket = IO.io('http://192.168.8.181:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      print('Socket connected');
    });
    socket.onConnectError((data) {
      print('Connect error: $data');
      error = 'Connection failed: $data';
      notifyListeners();
    });
    socket.on('update', (data) {
      print('Received update: $data');
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



  void joinGame(String gameId, String playerId, String playerName, {bool isTestMode = false}) {
    print('Joining game: $gameId, player: $playerId, test: $isTestMode');
    socket.emit('join', {
      'gameId': gameId,
      'playerId': playerId,
      'playerName': playerName,
      'isTestMode': isTestMode,
    });
  }

  void playPattern(String gameId, String playerId, List<Cards> cards, List<Cards> hand) {
    // Fix: Send hand order to preserve playing player's order
    print('WebSocket: Sending playPattern with hand order: ${hand.map((c) => c.isJoker ? "${c.suit} (${c.assignedRank} of ${c.assignedSuit})" : "${c.rank} of ${c.suit}").toList()}');
    socket!.emit('playPattern', {
      'gameId': gameId,
      'playerId': playerId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  void pass(String gameId, String playerId) {
    // Fix Bug 2: Log pass action
    print('WebSocket: Sending pass for player $playerId in game $gameId');
    socket!.emit('pass', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void takeChance(String gameId, String playerId, List<Cards> cards, List<Cards> hand) {
    // Fix: Send hand order to preserve playing player's order
    print('WebSocket: Sending takeChance with hand order: ${hand.map((c) => c.isJoker ? "${c.suit} (${c.assignedRank} of ${c.assignedSuit})" : "${c.rank} of ${c.suit}").toList()}');
    socket!.emit('takeChance', {
      'gameId': gameId,
      'playerId': playerId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  // Fix: Sync hand order after drag-and-drop
  void updateHandOrder(String gameId, String playerId, List<Cards> hand) {
    print('WebSocket: Sending updateHandOrder with hand: ${hand.map((c) => c.isJoker ? "${c.suit} (${c.assignedRank} of ${c.assignedSuit})" : "${c.rank} of ${c.suit}").toList()}');
    socket!.emit('updateHandOrder', {
      'gameId': gameId,
      'playerId': playerId,
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  // Improvement 1: Notify Joker assignment
  void notifyJokerAssignment(String gameId, String playerName, String jokerSuit, String assignedRank, String assignedSuit) {
    print('WebSocket: Sending jokerAssignment for $playerName: $jokerSuit as $assignedRank of $assignedSuit');
    socket!.emit('notifyJokerAssignment', {
      'gameId': gameId,
      'playerName': playerName,
      'jokerSuit': jokerSuit,
      'assignedRank': assignedRank,
      'assignedSuit': assignedSuit,
    });
  }



  @override
  void dispose() {
    socket!.dispose();
    super.dispose();
  }
}