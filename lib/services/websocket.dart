import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/game.dart';
import '../models/card.dart';

class WebSocketService with ChangeNotifier {
  late IO.Socket socket;
  Game? game;
  String? error;
  String? gameOverSummary;
  void Function()? onDismissDialog;
  void Function(Map<String, dynamic>)? onSelectKingCard;
  void Function(String)? onCardExchangeNotification;

  WebSocketService() {
    socket = IO.io('http://192.168.8.210:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.onConnect((_) {
      debugPrint('Socket connected');
      notifyListeners();
    });

    socket.onConnectError((data) {
      debugPrint('Connect error: $data');
      error = 'Connection failed: $data';
      notifyListeners();
    });

    socket.on('gameUpdate', (data) {
      debugPrint('Received gameUpdate: $data');
      try {
        game = Game.fromJson(data);
        error = null;
      } catch (e) {
        debugPrint('Error parsing game: $e');
        error = 'Failed to load game: $e';
      }
      notifyListeners();
    });

    socket.on('dismissDialog', (_) {
      debugPrint('Received dismissDialog event');
      if (onDismissDialog != null) {
        onDismissDialog!();
      }
      notifyListeners();
    });

    socket.on('gameOver', (data) {
      debugPrint('Received gameOver: $data');
      gameOverSummary = data['summaryMessage'];
      notifyListeners();
    });

    socket.on('selectKingCard', (data) {
      debugPrint('Received selectKingCard: $data');
      if (onSelectKingCard != null) {
        onSelectKingCard!(data);
      }
      notifyListeners();
    });

    socket.on('cardExchangeNotification', (data) {
      debugPrint('Received cardExchangeNotification: $data');
      if (onCardExchangeNotification != null) {
        onCardExchangeNotification!(data['message']);
      }
      notifyListeners();
    });

    socket.on('error', (data) {
      debugPrint('Received error: $data');
      error = data.toString();
      notifyListeners();
    });
  }

  void connect() {
    socket.connect();
  }

  void requestGameState(String gameId) {
    debugPrint('Requesting game state for $gameId');
    socket.emit('requestGameState', {'gameId': gameId});
  }

  void joinGame(String gameId, String playerId, String playerName, {bool isTestMode = false}) {
    debugPrint('Joining game: $gameId, player: $playerId, test: $isTestMode');
    socket.emit('join', {
      'gameId': gameId,
      'playerId': playerId,
      'playerName': playerName,
      'isTestMode': isTestMode,
    });
  }

  void startGame(String gameId, String playerId) {
    debugPrint('Starting game: $gameId, player: $playerId');
    socket.emit('startGame', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void restartGame(String gameId, String playerId) {
    debugPrint('Restarting game: $gameId, player: $playerId');
    socket.emit('restartGame', {
      'gameId': gameId,
      'playerId': playerId,
    });
    gameOverSummary = null;
  }

  void playPattern(String gameId, String playerId, List<Cards> cards, List<Cards> hand) {
    debugPrint(
        'WebSocket: Sending playPattern with cards: ${cards.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
    socket.emit('playPattern', {
      'gameId': gameId,
      'playerId': playerId,
      'cards': cards.map((c) => c.toJson()).toList(),
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  void pass(String gameId, String playerId) {
    debugPrint('WebSocket: Sending pass for player $playerId in game $gameId');
    socket.emit('pass', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  void updateHandOrder(String gameId, String playerId, List<Cards> hand) {
    debugPrint(
        'WebSocket: Sending updateHandOrder with hand: ${hand.map((c) => c.isJoker ? "${c.suit} (${c.assignedRank} of ${c.assignedSuit})" : "${c.rank} of ${c.suit}").toList()}');
    socket.emit('updateHandOrder', {
      'gameId': gameId,
      'playerId': playerId,
      'hand': hand.map((c) => c.toJson()).toList(),
    });
  }

  void selectKingCard(String gameId, String playerId, Cards card) {
    debugPrint('WebSocket: Sending kingCardSelected for player $playerId in game $gameId');
    socket.emit('kingCardSelected', {
      'gameId': gameId,
      'playerId': playerId,
      'card': card.toJson(),
    });
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }
}