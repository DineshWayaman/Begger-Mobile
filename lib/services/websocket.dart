import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/game.dart';
import '../models/card.dart';
import '../models/player.dart';

class WebSocketService with ChangeNotifier {
  late IO.Socket socket;
  Game? game;
  String? error;
  String? gameOverSummary;
  String? _lastPlayerId; // Store last known playerId for reconnection
  void Function()? onDismissDialog;
  void Function(Map<String, dynamic>)? onSelectKingCard;
  void Function(String)? onCardExchangeNotification;
  void Function(String, int)? onTurnTimerStart; // Pass Timer: Callback for turn timer

  WebSocketService() {
    // socket = IO.io('https://playbeggar.online/', <String, dynamic>{
    socket = IO.io('http://192.168.8.210:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true, // Enable automatic reconnection
      'reconnectionAttempts': 15, // Increased attempts for reliability
      'reconnectionDelay': 500, // Reduced initial delay for faster reconnect
      'reconnectionDelayMax': 3000, // Reduced max delay
    });

    // Connection established
    socket.onConnect((_) {
      debugPrint('Socket connected: ${socket.id}');
      if (game != null && _lastPlayerId != null) {
        requestGameState(game!.id );
      }
      notifyListeners();
    });

    // Handle reconnection
    socket.onReconnect((_) {
      debugPrint('Socket reconnected: ${socket.id}');
      if (game != null && _lastPlayerId != null) {
        debugPrint('Emitting rejoin for gameId=${game!.id}, playerId=$_lastPlayerId');
        socket.emit('rejoin', {
          'gameId': game!.id,
          'playerId': _lastPlayerId,
        });
        requestGameState(game!.id);
      } else {
        debugPrint('Rejoin skipped: game=${game?.id ?? 'null'}, playerId=${_lastPlayerId ?? 'null'}');
        error = 'Cannot rejoin: Game no longer available';
        game = null;
        _lastPlayerId = null;
        notifyListeners();
      }
    });

    socket.onConnectError((data) {
      debugPrint('Connect error: $data');
      error = 'Connection failed: $data';
      notifyListeners();
    });
    // Disconnection
    socket.onDisconnect((_) {
      debugPrint('Socket disconnected');
      error = 'Disconnected from server. Attempting to reconnect...';
      notifyListeners();
    });

    // Game state update
    socket.on('gameUpdate', (data) {
      debugPrint('Received gameUpdate');
      try {
        game = Game.fromJson(data);
        _lastPlayerId = game!.players
            .firstWhere(
                (p) => p.id.contains(socket.id as Pattern) || p.name == game!.players.first.name,
            orElse: () => Player(id: '', name: '', hand: []))
            .id;
        debugPrint('Updated lastPlayerId: $_lastPlayerId');
        error = null;
      } catch (e) {
        debugPrint('Error parsing game state: $e');
        error = 'Failed to load game: $e';
      }
      notifyListeners();
    });

    // Player disconnected
    socket.on('playerDisconnected', (data) {
      debugPrint('Player disconnected: $data');
      error = 'Player ${data['playerName'] ?? 'unknown'} disconnected. Waiting for reconnect.';
      notifyListeners();
    });
    // Player reconnected
    socket.on('playerReconnected', (data) {
      debugPrint('Player reconnected: $data');
      error = 'Player ${data['playerName'] ?? 'unknown'} has reconnected.';
      notifyListeners();
    });
    // Added: Handle player removal due to timeout or leave
    // Player removed
    socket.on('playerRemoved', (data) {
  debugPrint('Player removed: $data');
  error = data['message'] ?? 'You have been removed from the game.';
  game = null;
  _lastPlayerId = null;
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
    // Game ended
    socket.on('gameEnded', (data) {
      debugPrint('Game ended: $data');
      error = data['message'] ?? 'Game has ended.';
      game = null;
      _lastPlayerId = null;
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

    // Server error
    socket.on('error', (data) {
      debugPrint('Server error: $data');
      error = data ?? 'An error occurred on the server.';
      if (data.contains('Game not found') || data.contains('Player not found')) {
        game = null;
        _lastPlayerId = null;
      }
      notifyListeners();
    });
    // Home leave update: Listen for player leaving via summary screen
    socket.on('playerLeft', (data) {
      debugPrint('Received playerLeft: $data');
      notifyListeners();
    });
    // Pass Timer: Listen for turn timer start
    socket.on('turnTimerStart', (data) {
      debugPrint('Received turnTimerStart: $data');
      if (onTurnTimerStart != null) {
        onTurnTimerStart!(data['playerId'], data['duration']);
      }
      notifyListeners();
    });
    // Ensure error event is aliased as serverError for compatibility
    socket.on('serverError', (data) {
      socket.emit('error', data);
    });
  }

  void connect() {
    socket.connect();
  }

  // Request game state
  void requestGameState(String gameId) {
    debugPrint('Requesting game state for $gameId');
    socket.emit('requestGameState', {'gameId': gameId});
  }

  void joinGame(String gameId, String playerId, String playerName, {bool isTestMode = false}) {
    _lastPlayerId = '${gameId}-${playerName}'; // Store last playerId for reconnection
    debugPrint('Joining game: $gameId, player: $playerId, test: $isTestMode');
    // Reset game state to avoid carrying over previous game data
    game = null;
    gameOverSummary = null;
    error = null;
    socket.emit('join', {
      'gameId': gameId,
      'playerId': _lastPlayerId,
      'playerName': playerName,
      'isTestMode': isTestMode,
    });
    notifyListeners();
  }
  // autoplay mode: Add single-player join method
  void joinSinglePlayer(String gameId, String playerId, String playerName, List<String> botNames) {
    debugPrint('Joining single-player game: $gameId, player: $playerId, bots: $botNames');
    game = null;
    gameOverSummary = null;
    error = null;
    socket.emit('joinSingle', {
      'gameId': gameId,
      'playerId': playerId,
      'playerName': playerName,
      'botNames': botNames,
    });
    notifyListeners();
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
    notifyListeners();
  }

  void leaveGame(String gameId, String playerId) {
    debugPrint('Leaving game: $gameId, player: $playerId');
    socket.emit('leaveGame', {
      'gameId': gameId,
      'playerId': playerId,
    });
  }

  // Home leave update: New method for leaving from summary screen
  void leaveGameFromSummary(String gameId, String playerId) {
    debugPrint('Leaving game from summary: $gameId, player: $playerId');
    socket.emit('leaveGameFromSummary', {
      'gameId': gameId,
      'playerId': playerId,
    });
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