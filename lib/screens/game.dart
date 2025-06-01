import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:begger_card_game/models/player.dart';
import 'package:begger_card_game/screens/home_screen.dart';
import 'package:begger_card_game/widgets/floating_particles.dart';
import 'package:begger_card_game/widgets/leave_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game.dart';
import '../models/card.dart';
import '../services/voice_chat_audio_renderers.dart';
import '../services/websocket.dart';
import '../services/voice_chat_service.dart';
import '../widgets/card_widget.dart';
import 'lobby.dart';
import 'game_summary_screen.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerId;
  // autoplay mode: Add flag for single-player mode
  final bool isSinglePlayer;

  const GameScreen({required this.gameId, required this.playerId,this.isSinglePlayer = false, super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  List<Cards> selectedCards = [];
  final ScrollController _scrollController = ScrollController();
  bool _showScrollThumb = false;
  List<Cards> _lastSentHand = [];
  String? _lastJokerMessage;
  final Set<String> _shownMessages = {};
  bool _isDialogShowing = false;
  bool _hasShownNewRoundMessage = false;
  bool _showNewRoundNotification = false;
  AnimationController? _notificationController;
  Animation<Offset>? _notificationAnimation;
  String? _newRoundMessage;
  bool _isRestarted = false;
  bool _isReplayInitiator = false;
  VoiceChatService? _voiceChatService;
  AnimationController?
  _timerController; // Pass Timer: Controller for turn timer animation
  String? _currentTurnPlayerId; // Pass Timer: Track current turn player
  double _timerProgress = 0.0; // Pass Timer: Track timer progress
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRestarting = false;

  @override
  void initState() {
    super.initState();
    // Clear shown messages to prevent stale data from previous games
    _shownMessages.clear();
    _notificationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _notificationAnimation = Tween<Offset>(
      begin: const Offset(0, -5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _notificationController!,
      curve: Curves.easeInOut,
    ));
    // Pass Timer: Initialize timer animation controller
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..addListener(() {
      setState(() {
        _timerProgress = _timerController!.value;
      });
    });
    // Initialize voice chat only if not in single-player mode
    if (!widget.isSinglePlayer) {
      _initializeVoiceChat();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _updateScrollThumbVisibility();
    });
    _scrollController.addListener(_updateScrollThumbVisibility);
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.addListener(_onGameStateChanged);
    ws.onDismissDialog = () {
      if (_isDialogShowing && mounted && !_isReplayInitiator) {
        setState(() {
          _isDialogShowing = false;
          _isRestarted = true;
        });
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    };
    // Pass Timer: Handle turn timer start
    ws.onTurnTimerStart = (playerId, duration) {
      if (mounted) {
        setState(() {
          _currentTurnPlayerId = playerId;
          _timerController?.stop(); // Stop any ongoing animation
          _timerController?.reset();
          _timerController?.duration = Duration(seconds: duration.toInt());
          _timerController?.forward();
        });
      }
    };
    // Listen for gameEnded event
    ws.socket.on('gameEnded', (data) {
      if (mounted) {
        _timerController?.stop(); // Stop timer on game end
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content:
        //         Text(data['message'], style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //     duration: const Duration(seconds: 3),
        //   ),
        // );
        _showEnhancedSnackBar(
          message: data['message'],
          icon: Icons.info,
          color: Colors.redAccent,
          isError: true,
        );
        _hasShownNewRoundMessage = false;
        _shownMessages.clear();
        //need to end voice chat service
        // Dispose voice chat service only if initialized (not single-player)
        if (!widget.isSinglePlayer) {
          _voiceChatService?.dispose();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
    ws.socket.on('gameRestarted', (data) {
      if (mounted) {
        // Reset any additional game state if needed
        setState(() {
          _isRestarted = true;
          _isReplayInitiator = false;
        });
        // Ensure the game screen is active
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              gameId: widget.gameId,
              playerId: widget.playerId,
              isSinglePlayer: widget.isSinglePlayer, // Pass single-player flag
              // Add other parameters
            ),
          ),
        );
      }
    });
    _audioPlayer.setSource(AssetSource('sounds/suffel.mp3'));
    _audioPlayer.setSource(AssetSource('sounds/play.mp3'));
  }

  Future<void> _initializeVoiceChat() async {
    // Only initialize voice chat if not in single-player mode
    if (widget.isSinglePlayer) return;

    final permissionStatus = await Permission.microphone.request();
    if (permissionStatus.isGranted) {
      final ws = Provider.of<WebSocketService>(context, listen: false);
      _voiceChatService = VoiceChatService(ws, widget.gameId, widget.playerId);
      _voiceChatService!.addListener(() {
        if (mounted) setState(() {});
      });
    } else {
      if (mounted) {
        _showEnhancedSnackBar(
          message: 'Microphone permission denied. Voice chat disabled.',
          icon: Icons.mic_off,
          color: Colors.redAccent,
          isError: true,
        );
      }
    }
  }

  void _shareGameInvite() {
    Share.share(
      'Join my Beggar game! Game ID: ${widget.gameId}\nLet\'s play together!',
      subject: 'Invite to Beggar Game',
    );
  }

  void _handleLeaveGame() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.leaveGame(widget.gameId, widget.playerId);
    _hasShownNewRoundMessage = false;
    _shownMessages.clear();
    _timerController?.stop(); // Pass Timer: Stop timer on leave
    // Dispose voice chat service only if initialized (not single-player)
    if (!widget.isSinglePlayer) {
      _voiceChatService?.dispose();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  void didUpdateWidget(GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _showGameMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notificationController?.dispose();
    _timerController?.dispose(); // Pass Timer: Dispose timer controller
    // Dispose voice chat service only if initialized (not single-player)
    if (!widget.isSinglePlayer) {
      _voiceChatService?.dispose();
    }
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.removeListener(_onGameStateChanged);
    ws.onDismissDialog = null;
    ws.onTurnTimerStart = null; // Pass Timer: Clear timer callback
    ws.socket.off('gameEnded');
    ws.socket.off('gameRestarted');
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null) {
      _showGameMessages();
      return;
    }

    debugPrint(
        'Game state updated. Current turn: ${game.currentTurn}, Player: ${game.players[game.currentTurn].name}');

    // Update current turn player and manage timer
    if (!game.isTestMode &&
        _currentTurnPlayerId != game.players[game.currentTurn].id) {
      setState(() {
        _currentTurnPlayerId = game.players[game.currentTurn].id;
        _timerController?.stop();
        _timerController?.reset();
        _timerController?.forward();
      });
    }

    if (!_hasShownNewRoundMessage &&
        game.status != 'waiting' &&
        game.pile.isEmpty &&
        game.passCount == 0) {
      final starter = game.players[game.currentTurn];
      final message = 'New Round Started! ${starter.name} begins!';
      if (!_shownMessages.contains(message)) {
        _shownMessages.add(message);
        _hasShownNewRoundMessage = true;
        setState(() {
          _newRoundMessage = message;
          _showNewRoundNotification = true;
          _notificationController?.forward();
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _notificationController?.reverse().then((_) {
                _showNewRoundNotification = false;
                _newRoundMessage = null;
                _hasShownNewRoundMessage = false;
                if (_isRestarted) {
                  _isRestarted = false;
                }
              });
            });
          }
        });
      }
    }

    if (game.pile.isNotEmpty) {
      final lastPlay = game.pile.last;
      final player = game.lastPlayedPlayerId != null
          ? game.players.firstWhere(
            (p) => p.id == game.lastPlayedPlayerId,
        orElse: () => Player(id: '', name: 'Unknown', hand: []),
      )
          : null;

      if (player != null && player.id != '' && player.id != widget.playerId) {
        final jokerCards = lastPlay.where((c) => c.isJoker).toList();
        if (jokerCards.isNotEmpty) {
          final jokerMessage = jokerCards.length == 1
              ? '${player.name} played Joker as ${jokerCards[0].assignedRank} of ${jokerCards[0].assignedSuit}'
              : '${player.name} played Jokers: ${jokerCards.map((c) => '${c.assignedRank} of ${c.assignedSuit}').join(', ')}';

          if (jokerMessage != _lastJokerMessage) {
            _lastJokerMessage = jokerMessage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text(jokerMessage,
                //         style: TextStyle(fontFamily: "Poppins")),
                //     backgroundColor: Colors.blueAccent,
                //     duration: const Duration(seconds: 3),
                //   ),
                // );
                _showEnhancedSnackBar(
                  message: jokerMessage,
                  icon: Icons.card_giftcard,
                  color: Colors.blueAccent,
                );
              }
            });
          }
        }
      }
    }

    _showGameMessages();
  }

  void _showGameMessages() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null || _isDialogShowing || _isRestarted) return;

    // Only show game over summary if the game is actually finished
    if (ws.gameOverSummary != null &&
        game.status == 'finished' &&
        !_shownMessages.contains(ws.gameOverSummary)) {
      _shownMessages.add(ws.gameOverSummary!);
      _showGameSummaryScreen(ws.gameOverSummary!);
      return;
    }

    final titledPlayers = game.players.where((p) => p.title != null).toList();
    if (titledPlayers.isNotEmpty &&
        titledPlayers.length == game.players.length &&
        game.status == 'finished') {
      final message =
      titledPlayers.map((p) => '${p.name}: ${p.title}').join('\n');
      if (!_shownMessages.contains(message)) {
        _shownMessages.add(message);
        _showGameSummaryScreen(message);
      }
    }
  }

  void _showGameSummaryScreen(String message) {
    if (_isDialogShowing || !mounted) return;
    setState(() {
      _isDialogShowing = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameSummaryScreen(
            summaryMessage: message,
            gameId: widget.gameId,
            playerId: widget.playerId,
            onHomePressed: () {
              _hasShownNewRoundMessage = false;
              _shownMessages.clear();
              setState(() {
                _isDialogShowing = false;
                _isRestarted = true;
                _isReplayInitiator = false;
              });
              _voiceChatService?.dispose();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            onReplayPressed: () {
              setState(() {
                _isDialogShowing = false;
                _isRestarted = true;
                _isReplayInitiator = true;
              });
              Navigator.pop(context); // Dismiss GameSummaryScreen
              _handleRestartGame();
            },
          ),
        ),
      ).then((_) {
        setState(() {
          _isDialogShowing = false;
          _isReplayInitiator = false;
        });
      });
    });
  }

  void _updateScrollThumbVisibility() {
    if (!_scrollController.hasClients || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final newVisibility = maxScrollExtent > 0;

      if (newVisibility != _showScrollThumb) {
        setState(() {
          _showScrollThumb = newVisibility;
        });
      }
    });
  }

  String _cardId(Cards card) {
    return '${card.suit ?? 'none'}-${card.rank ?? 'none'}-${card.isJoker}-${card.isDetails}';
  }

  Future<List<Cards>?> _assignJokerValues(List<Cards> cards) async {
    List<Cards> assignedCards = [];

    for (var card in cards) {
      if (!card.isJoker) {
        assignedCards.add(card);
        continue;
      }

      final assignedCard = await showDialog<Cards>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.3),
        builder: (dialogContext) {
          String? selectedRank;
          String? selectedSuit;

          return GestureDetector(
            onTap: () => Navigator.of(dialogContext).pop(),
            child: Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Joker Value',
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Rank',
                              labelStyle: TextStyle(
                                  fontFamily: "Poppins",
                                  color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            value: selectedRank,
                            items: [
                              '3',
                              '4',
                              '5',
                              '6',
                              '7',
                              '8',
                              '9',
                              '10',
                              'J',
                              'Q',
                              'K',
                              'A',
                              '2'
                            ]
                                .map((rank) => DropdownMenuItem(
                              value: rank,
                              child: Text(rank,
                                  style:
                                  TextStyle(fontFamily: "Poppins")),
                            ))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => selectedRank = value),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Suit',
                              labelStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontFamily: "Poppins"),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            value: selectedSuit,
                            items: ['hearts', 'diamonds', 'clubs', 'spades']
                                .map((suit) => DropdownMenuItem(
                              value: suit,
                              child: Text(suit,
                                  style:
                                  TextStyle(fontFamily: "Poppins")),
                            ))
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => selectedSuit = value),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                      fontFamily: "Poppins"),
                                ),
                              ),
                              ElevatedButton(
                                onPressed:
                                selectedRank != null && selectedSuit != null
                                    ? () {
                                  Navigator.of(dialogContext).pop(
                                    Cards(
                                      isJoker: true,
                                      suit: card.suit,
                                      assignedRank: selectedRank,
                                      assignedSuit: selectedSuit,
                                      isDetails: false,
                                    ),
                                  );
                                }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: "Poppins"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      if (assignedCard == null) {
        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('Joker assignment cancelled',
          //         style: TextStyle(fontFamily: "Poppins")),
          //     backgroundColor: Colors.redAccent,
          //   ),
          // );
          _showEnhancedSnackBar(
            message: 'Joker assignment cancelled',
            icon: Icons.cancel,
            color: Colors.redAccent,
            isError: true,
          );
        }
        return null;
      }
      assignedCards.add(assignedCard);
    }

    return assignedCards.isEmpty ? null : assignedCards;
  }

  String _getPatternMessage(List<Cards> cards, String? pattern) {
    if (cards.isEmpty) return '';
    final hasJoker = cards.any((c) => c.isJoker);
    final firstCard = cards[0];
    final effectiveRank =
    firstCard.isJoker ? firstCard.assignedRank : firstCard.rank;
    final effectiveSuit =
    firstCard.isJoker ? firstCard.assignedSuit : firstCard.suit;

    if (pattern == 'single') {
      if (firstCard.isDetails) return 'Details Card';
      return hasJoker
          ? 'Joker as $effectiveRank of $effectiveSuit'
          : 'Single: $effectiveRank of $effectiveSuit';
    } else if (pattern == 'pair') {
      return hasJoker
          ? 'Joker Pair: Two $effectiveRank\'s'
          : 'Pair: Two $effectiveRank\'s';
    } else if (pattern == 'group-3') {
      return hasJoker
          ? 'Joker Three: Three $effectiveRank\'s'
          : 'Three of a kind: Three $effectiveRank\'s';
    } else if (pattern == 'group-4') {
      return hasJoker
          ? 'Joker Four: Four $effectiveRank\'s'
          : 'Four of a kind: Four $effectiveRank\'s';
    } else if (pattern == 'consecutive') {
      final sortedCards = cards
        ..sort((a, b) {
          final rankA = a.isJoker ? a.assignedRank : a.rank;
          final rankB = b.isJoker ? b.assignedRank : b.rank;
          const values = {
            '3': 3,
            '4': 4,
            '5': 5,
            '6': 6,
            '7': 7,
            '8': 8,
            '9': 9,
            '10': 10,
            'J': 11,
            'Q': 12,
            'K': 13,
            'A': 14,
            '2': 15,
          };
          final valueA = rankA != null ? values[rankA] ?? 0 : 0;
          final valueB = rankB != null ? values[rankB] ?? 0 : 0;
          return valueA - valueB;
        });
      final startCard = sortedCards.first;
      final startRank =
      startCard.isJoker ? startCard.assignedRank : startCard.rank;
      final startSuit =
      startCard.isJoker ? startCard.assignedSuit : startCard.suit;
      return hasJoker
          ? 'Joker Consecutive: Starting at $startRank of $startSuit'
          : 'Consecutive: Starting at $startRank of $startSuit';
    }
    return '';
  }

  bool _validateDetailsCard(List<Cards> cards) {
    if (cards.any((c) => c.isDetails) && cards.length > 1) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Details card can only be played alone',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Details card can only be played alone',
          icon: Icons.warning,
          color: Colors.redAccent,
          isError: true,
        );
      }
      return false;
    }
    return true;
  }

  void _playCards(List<Cards> cards) async {
    if (!_validateDetailsCard(cards)) return;

    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Game not loaded',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Game not loaded',
          icon: Icons.error,
          color: Colors.redAccent,
          isError: true,
        );
      }
      return;
    }

    final player = game.players.firstWhere(
          (p) => p.id == widget.playerId,
      orElse: () => Player(id: widget.playerId, name: 'Unknown', hand: []),
    );

    if (player.id == 'Unknown') {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Player not found in game',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Player not found in game',
          icon: Icons.error,
          color: Colors.redAccent,
          isError: true,
        );
      }
      return;
    }

    final assignedCards = await _assignJokerValues(cards);
    if (assignedCards == null || assignedCards.isEmpty) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Play cancelled',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Play cancelled',
          icon: Icons.cancel,
          color: Colors.redAccent,
          isError: true,
        );
      }
      return;
    }

    final playedCardIds = assignedCards.map(_cardId).toList();
    final remainingHand =
    player.hand.where((c) => !playedCardIds.contains(_cardId(c))).toList();

    if (game.isTestMode) {
      setState(() {
        player.hand = remainingHand;
        game.pile.add(assignedCards);
        selectedCards = [];
        _lastSentHand = List.from(remainingHand);
      });
      // Play card play sound
      await _audioPlayer.play(AssetSource('sounds/play.mp3'));
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Played ${assignedCards.length} cards in test mode',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Played ${assignedCards.length} cards in test mode',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      }
      ws.playPattern(widget.gameId, widget.playerId, assignedCards, remainingHand);
    } else {
      ws.playPattern(widget.gameId, widget.playerId, assignedCards, remainingHand);
      if (ws.error != null && mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Play failed: ${ws.error}',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Play failed: ${ws.error}',
          icon: Icons.error,
          color: Colors.redAccent,
          isError: true,
        );
        ws.error = null;
      } else {
        // Play card play sound
        await _audioPlayer.play(AssetSource('sounds/play.mp3'));
        setState(() {
          selectedCards = [];
          _lastSentHand = List.from(remainingHand);
        });
      }
    }
  }

  void _handlePass() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Game not loaded',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Game not loaded',
          icon: Icons.error,
          color: Colors.redAccent,
          isError: true,
        );
      }
      return;
    }
    if (game.isTestMode) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Passing not allowed in test mode',
        //         style: TextStyle(fontFamily: "Poppins")),
        //     backgroundColor: Colors.redAccent,
        //   ),
        // );
        _showEnhancedSnackBar(
          message: 'Passing not allowed in test mode',
          icon: Icons.block,
          color: Colors.redAccent,
          isError: true,
        );
      }
      return;
    }
    ws.pass(widget.gameId, widget.playerId);
    if (ws.error != null && mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Pass failed: ${ws.error}',
      //         style: TextStyle(fontFamily: "Poppins")),
      //     backgroundColor: Colors.redAccent,
      //   ),
      // );
      _showEnhancedSnackBar(
        message: 'Pass failed: ${ws.error}',
        icon: Icons.error,
        color: Colors.redAccent,
        isError: true,
      );
      ws.error = null;
    } else if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Passed!', style: TextStyle(fontFamily: "Poppins")),
      //     backgroundColor: Colors.green,
      //   ),
      // );
      _showEnhancedSnackBar(
        message: 'Passed!',
        icon: Icons.check_circle,
        color: Colors.green,
      );
      setState(() {
        selectedCards = [];
      });
    }
  }

  void _handleStartGame()  {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.startGame(widget.gameId, widget.playerId);
    _audioPlayer.play(AssetSource('sounds/suffel.mp3'));
    if (ws.error != null && mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to start game: ${ws.error}',
      //         style: TextStyle(fontFamily: "Poppins")),
      //     backgroundColor: Colors.redAccent,
      //   ),
      // );
      _showEnhancedSnackBar(
        message: 'Failed to start game: ${ws.error}',
        icon: Icons.error,
        color: Colors.redAccent,
        isError: true,
      );
      ws.error = null;
    }
  }

  Future<void> _handleRestartGame() async {
    if (_isRestarting) return;
    setState(() => _isRestarting = true);

    try {
      final ws = Provider.of<WebSocketService>(context, listen: false);

      if (Navigator.canPop(context) && _isDialogShowing) {
        Navigator.pop(context);
      }

      ws.restartGame(widget.gameId, widget.playerId);

      if (ws.error != null && mounted) {
        _showEnhancedSnackBar(
          message: 'Failed to restart game: ${ws.error}',
          icon: Icons.error,
          color: Colors.redAccent,
          isError: true,
        );
        ws.error = null;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      } else if (mounted) {
        // Reset game state
        setState(() {
          _hasShownNewRoundMessage = false;
          _shownMessages.clear();
          selectedCards = [];
          _lastSentHand = [];
          _lastJokerMessage = null;
          _isDialogShowing = false;
          _showNewRoundNotification = false;
          _isRestarted = true;
          _timerProgress = 0.0;
          _currentTurnPlayerId = null;
        });

        if (_timerController != null) {
          _timerController!.stop();
          _timerController!.reset();
        }

        // Initialize voice chat only if not in single-player mode
        if (!widget.isSinglePlayer) {
          await _initializeVoiceChat();
        }
        await _audioPlayer.play(AssetSource('sounds/suffel.mp3'));

        _showEnhancedSnackBar(
          message: 'Game restarted successfully!',
          icon: Icons.restart_alt,
          color: Colors.green,
        );

        // Navigate to the game screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(
              gameId: widget.gameId,
              playerId: widget.playerId,
              isSinglePlayer: widget.isSinglePlayer, // Pass single-player flag
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showEnhancedSnackBar(
          message: 'An error occurred while restarting: $e',
          icon: Icons.error,
          color: Colors.redAccent,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestarting = false);
      }
    }
  }

  void _showEnhancedSnackBar({
    required String message,
    required IconData icon,
    required Color color,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: isError ? 4 : 2),
        animation: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, ws, _) {
        if (ws.error != null) {
          final errorMessage = ws.error!;
          ws.error = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(
              //     content: Text('Error: $errorMessage',
              //         style: const TextStyle(fontFamily: "Poppins")),
              //     backgroundColor: Colors.redAccent,
              //   ),
              // );
              _showEnhancedSnackBar(
                message: 'Error: $errorMessage',
                icon: Icons.error,
                color: Colors.redAccent,
                isError: true,
              );
              if (errorMessage == 'Game is full' ||
                  errorMessage == 'Game has already started') {
                _hasShownNewRoundMessage = false;
                _shownMessages.clear();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LobbyScreen()),
                );
              }
            }
          });
        }

        final game = ws.game;
        if (game == null) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(widget.isSinglePlayer
                        ? 'assets/images/beggarbg2.png'
                        : 'assets/images/beggarbg.png'),
                    fit: BoxFit.cover),
              ),
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
          );
        }

        if (game.status == 'waiting') {
          return WillPopScope(
            onWillPop: () async {
              showCupertinoDialog(
                context: context,
                builder: (BuildContext context) {
                  return CupertinoAlertDialog(
                    title: const Text("Leave Game"),
                    content:
                    const Text("Are you sure you want to exit the game?"),
                    actions: <Widget>[
                      CupertinoDialogAction(
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.blueAccent,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        child: const Text("Leave"),
                        onPressed: () {
                          _handleLeaveGame();
                        },
                      ),
                    ],
                  );
                },
              );
              return false;
            },
            child: Scaffold(
              body: Stack(
                children: [
                  // Background Image
                  Positioned.fill(
                    child: Image.asset(
                      widget.isSinglePlayer
                          ? 'assets/images/beggarbg2.png'
                          : 'assets/images/beggarbg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Floating particles
                  WaveParticles(
                    particleCount: 25,
                    minParticleSize: 5.0,
                    maxParticleSize: 12.0,
                    particleColors: [Colors.yellow, Colors.green, Colors.blue],
                    animationSpeed: 0.7,
                    waveAmplitude: 60.0,
                    waveFrequency: 0.4,
                  ),
                  // Main content
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWeb = constraints.maxWidth > 1070;
                        return isWeb
                            ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth:
                              1200, // Maximum width for larger screens
                              minWidth:
                              300, // Minimum width for smaller screens
                            ),
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 24),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                    0.8), // Optional: Background for contrast
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      // Left side: Player count, Minimum players, Game ID
                                      Expanded(
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              const SizedBox(height: 20),
                                              // Header with leave button
                                              Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  const Text(
                                                    'Waiting Room',
                                                    style: TextStyle(
                                                      fontFamily:
                                                      "Poppins",
                                                      fontSize: 28,
                                                      color: Colors.white,
                                                      fontWeight:
                                                      FontWeight.w700,
                                                      letterSpacing: 1.2,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 4),
                                                  AnimatedDots(),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              // Player count with circular progress
                                              Stack(
                                                alignment:
                                                Alignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 150,
                                                    height: 150,
                                                    child:
                                                    CircularProgressIndicator(
                                                      value: (game.players
                                                          .length /
                                                          6)
                                                          .clamp(
                                                          0.0, 1.0),
                                                      strokeWidth: 10,
                                                      backgroundColor:
                                                      Colors.white
                                                          .withOpacity(
                                                          0.2),
                                                      valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                          Colors.amber
                                                              .shade600),
                                                    ),
                                                  ),
                                                  Column(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        '${game.players.length}',
                                                        style:
                                                        const TextStyle(
                                                          fontFamily:
                                                          "Poppins",
                                                          fontSize: 45,
                                                          color: Colors
                                                              .white,
                                                          fontWeight:
                                                          FontWeight
                                                              .w700,
                                                          height: 1,
                                                        ),
                                                      ),
                                                      const Text(
                                                        '/6 Players',
                                                        style: TextStyle(
                                                          fontFamily:
                                                          "Poppins",
                                                          fontSize: 16,
                                                          color: Colors
                                                              .white70,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              // Minimum players indicator
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 16,
                                                    vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(20),
                                                  border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(
                                                          0.1)),
                                                ),
                                                child: const Text(
                                                  'Minimum 3 players required',
                                                  style: TextStyle(
                                                    fontFamily: "Poppins",
                                                    fontSize: 14,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              // Game ID and Copy Game ID
                                              Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  Text(
                                                    'Game ID: ${widget.gameId}',
                                                    style:
                                                    const TextStyle(
                                                      fontFamily:
                                                      "Poppins",
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      Clipboard.setData(
                                                          ClipboardData(
                                                              text: widget
                                                                  .gameId));
                                                      // ScaffoldMessenger
                                                      //         .of(context)
                                                      //     .showSnackBar(
                                                      //   SnackBar(
                                                      //     content:
                                                      //         const Text(
                                                      //       'Game ID copied to clipboard',
                                                      //       style: TextStyle(
                                                      //           fontFamily:
                                                      //               "Poppins"),
                                                      //     ),
                                                      //     backgroundColor:
                                                      //         Colors
                                                      //             .green,
                                                      //   ),
                                                      // );
                                                      _showEnhancedSnackBar(
                                                        message:
                                                        'Game ID copied to clipboard',
                                                        icon: Icons
                                                            .content_copy,
                                                        color: Colors
                                                            .green,
                                                      );
                                                    },
                                                    child: const Icon(
                                                        Icons.copy,
                                                        color:
                                                        Colors.white,
                                                        size: 20),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              // Rectangular Leave Button
                                              GestureDetector(
                                                onTap: () {
                                                  showCupertinoDialog(
                                                    context: context,
                                                    builder: (BuildContext
                                                    context) {
                                                      return CupertinoAlertDialog(
                                                        title: const Text(
                                                            "Leave Game"),
                                                        content: const Text(
                                                            "Are you sure you want to leave the game?"),
                                                        actions: <Widget>[
                                                          CupertinoDialogAction(
                                                            child:
                                                            const Text(
                                                              "Cancel",
                                                              style:
                                                              TextStyle(
                                                                color: Colors
                                                                    .blueAccent,
                                                              ),
                                                            ),
                                                            onPressed:
                                                                () {
                                                              Navigator.of(
                                                                  context)
                                                                  .pop();
                                                            },
                                                          ),
                                                          CupertinoDialogAction(
                                                            isDestructiveAction:
                                                            true,
                                                            child: const Text(
                                                                "Leave"),
                                                            onPressed:
                                                                () {
                                                              _handleLeaveGame();
                                                            },
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                                child: Container(
                                                  padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      vertical: 12,
                                                      horizontal: 24),
                                                  decoration:
                                                  BoxDecoration(
                                                    color:
                                                    Colors.redAccent,
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                    MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.exit_to_app,
                                                        color:
                                                        Colors.white,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(
                                                          width: 8),
                                                      const Text(
                                                        'Leave Game',
                                                        style: TextStyle(
                                                          fontFamily:
                                                          "Poppins",
                                                          fontSize: 16,
                                                          color: Colors
                                                              .white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Right side: Players list, Action buttons, Voice chat
                                      Expanded(
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              const SizedBox(height: 50),
                                              // Players list
                                              ConstrainedBox(
                                                constraints:
                                                const BoxConstraints(
                                                    maxHeight: 200),
                                                child: Container(
                                                  width: double.infinity,
                                                  padding:
                                                  const EdgeInsets
                                                      .all(16),
                                                  decoration:
                                                  BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(16),
                                                  ),
                                                  child:
                                                  game.players.isEmpty
                                                      ? const Center(
                                                    child: Text(
                                                      'No players yet',
                                                      style:
                                                      TextStyle(
                                                        fontFamily:
                                                        "Poppins",
                                                        color: Colors
                                                            .white70,
                                                      ),
                                                    ),
                                                  )
                                                      : ListView
                                                      .separated(
                                                    shrinkWrap:
                                                    true,
                                                    itemCount: game
                                                        .players
                                                        .length,
                                                    separatorBuilder:
                                                        (context,
                                                        index) =>
                                                        Divider(
                                                          color: Colors
                                                              .white
                                                              .withOpacity(
                                                              0.1),
                                                          height:
                                                          16,
                                                        ),
                                                    itemBuilder:
                                                        (context,
                                                        index) {
                                                      final player =
                                                      game.players[
                                                      index];
                                                      return Padding(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            vertical:
                                                            4),
                                                        child:
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.person_rounded,
                                                              color: Colors.white,
                                                              size: 25,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              player.name,
                                                              style: const TextStyle(
                                                                fontFamily: "Poppins",
                                                                fontSize: 16,
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 30),
                                              // Action buttons
                                              Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  Expanded(
                                                    child: _GameButton(
                                                      onPressed: game
                                                          .players
                                                          .length >=
                                                          3
                                                          ? _handleStartGame
                                                          : null,
                                                      text: 'START GAME',
                                                      icon: Icons
                                                          .play_arrow_rounded,
                                                      gradient:
                                                      LinearGradient(
                                                        colors: [
                                                          Colors.amber
                                                              .shade600,
                                                          Colors.amber
                                                              .shade800
                                                        ],
                                                      ),
                                                      textColor:
                                                      Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 16),
                                                  Expanded(
                                                    child: _GameButton(
                                                      onPressed:
                                                      _shareGameInvite,
                                                      text:
                                                      'INVITE FRIENDS',
                                                      icon: Icons
                                                          .share_rounded,
                                                      gradient:
                                                      LinearGradient(
                                                        colors: [
                                                          Colors.blue
                                                              .shade600,
                                                          Colors.blue
                                                              .shade800
                                                        ],
                                                      ),
                                                      textColor:
                                                      Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_voiceChatService !=
                                                  null) ...[
                                                const SizedBox(
                                                    height: 20),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _voiceChatService!
                                                          .toggleMute(),
                                                  child: Container(
                                                    padding:
                                                    const EdgeInsets
                                                        .all(12),
                                                    decoration:
                                                    BoxDecoration(
                                                      shape:
                                                      BoxShape.circle,
                                                      color: _voiceChatService!
                                                          .isMuted
                                                          ? Colors.red
                                                          .withOpacity(
                                                          0.7)
                                                          : Colors.green
                                                          .withOpacity(
                                                          0.7),
                                                    ),
                                                    child: Icon(
                                                      _voiceChatService!
                                                          .isMuted
                                                          ? CupertinoIcons
                                                          .mic_slash_fill
                                                          : CupertinoIcons
                                                          .mic_fill,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (_voiceChatService
                                                  ?.remoteRenderers !=
                                                  null)
                                                VoiceChatAudioRenderers(
                                                    remoteRenderers:
                                                    _voiceChatService!
                                                        .remoteRenderers),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                            : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Stack(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                    MediaQuery.of(context).size.width,
                                    minHeight: MediaQuery.of(context)
                                        .size
                                        .height,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 50),
                                      // Header with leave button
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Waiting Room',
                                            style: TextStyle(
                                              fontFamily: "Poppins",
                                              fontSize: 28,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          AnimatedDots(),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      // Player count with circular progress
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            width: 150,
                                            height: 150,
                                            child:
                                            CircularProgressIndicator(
                                              value:
                                              (game.players.length /
                                                  6)
                                                  .clamp(0.0, 1.0),
                                              strokeWidth: 10,
                                              backgroundColor: Colors
                                                  .white
                                                  .withOpacity(0.2),
                                              valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(
                                                  Colors.amber
                                                      .shade600),
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${game.players.length}',
                                                style: const TextStyle(
                                                  fontFamily: "Poppins",
                                                  fontSize: 45,
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  height: 1,
                                                ),
                                              ),
                                              const Text(
                                                '/6 Players',
                                                style: TextStyle(
                                                  fontFamily: "Poppins",
                                                  fontSize: 16,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      // Minimum players indicator
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withOpacity(0.3),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.1)),
                                        ),
                                        child: const Text(
                                          'Minimum 3 players required',
                                          style: TextStyle(
                                            fontFamily: "Poppins",
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Game ID and Copy Game ID
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Game ID: ${widget.gameId}',
                                            style: const TextStyle(
                                              fontFamily: "Poppins",
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(
                                                  ClipboardData(
                                                      text:
                                                      widget.gameId));
                                              // ScaffoldMessenger.of(
                                              //         context)
                                              //     .showSnackBar(
                                              //   SnackBar(
                                              //     content: const Text(
                                              //         'Game ID copied to clipboard',
                                              //         style: TextStyle(
                                              //             fontFamily:
                                              //                 "Poppins")),
                                              //     backgroundColor:
                                              //         Colors.green,
                                              //   ),
                                              // );
                                              _showEnhancedSnackBar(
                                                message:
                                                'Game ID copied to clipboard',
                                                icon: Icons.content_copy,
                                                color: Colors.green,
                                              );
                                            },
                                            child: const Icon(Icons.copy,
                                                color: Colors.white,
                                                size: 20),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Players list
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            maxHeight: 200),
                                        child: Container(
                                          width: double.infinity,
                                          padding:
                                          const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withOpacity(0.3),
                                            borderRadius:
                                            BorderRadius.circular(16),
                                          ),
                                          child: game.players.isEmpty
                                              ? const Center(
                                            child: Text(
                                              'No players yet',
                                              style: TextStyle(
                                                fontFamily:
                                                "Poppins",
                                                color:
                                                Colors.white70,
                                              ),
                                            ),
                                          )
                                              : ListView.separated(
                                            shrinkWrap: true,
                                            itemCount:
                                            game.players.length,
                                            separatorBuilder:
                                                (context, index) =>
                                                Divider(
                                                  color: Colors.white
                                                      .withOpacity(0.1),
                                                  height: 16,
                                                ),
                                            itemBuilder:
                                                (context, index) {
                                              final player = game
                                                  .players[index];
                                              return Padding(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    vertical:
                                                    4),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .person_rounded,
                                                        color: Colors
                                                            .white,
                                                        size: 25),
                                                    const SizedBox(
                                                        width: 4),
                                                    Text(
                                                      player.name,
                                                      style:
                                                      const TextStyle(
                                                        fontFamily:
                                                        "Poppins",
                                                        fontSize:
                                                        16,
                                                        color: Colors
                                                            .white,
                                                        fontWeight:
                                                        FontWeight
                                                            .w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      // Action buttons
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final isWeb =
                                              constraints.maxWidth > 600;
                                          return isWeb
                                              ? Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment
                                                .center,
                                            children: [
                                              Expanded(
                                                child: _GameButton(
                                                  onPressed: game
                                                      .players
                                                      .length >=
                                                      3
                                                      ? _handleStartGame
                                                      : null,
                                                  text:
                                                  'START GAME',
                                                  icon: Icons
                                                      .play_arrow_rounded,
                                                  gradient:
                                                  LinearGradient(
                                                    colors: [
                                                      Colors.amber
                                                          .shade600,
                                                      Colors.amber
                                                          .shade800
                                                    ],
                                                  ),
                                                  textColor:
                                                  Colors.black,
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 16),
                                              Expanded(
                                                child: _GameButton(
                                                  onPressed:
                                                  _shareGameInvite,
                                                  text:
                                                  'INVITE FRIENDS',
                                                  icon: Icons
                                                      .share_rounded,
                                                  gradient:
                                                  LinearGradient(
                                                    colors: [
                                                      Colors.blue
                                                          .shade600,
                                                      Colors.blue
                                                          .shade800
                                                    ],
                                                  ),
                                                  textColor:
                                                  Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                              : Column(
                                            mainAxisSize:
                                            MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width:
                                                double.infinity,
                                                child: _GameButton(
                                                  onPressed: game
                                                      .players
                                                      .length >=
                                                      3
                                                      ? _handleStartGame
                                                      : null,
                                                  text:
                                                  'START GAME',
                                                  icon: Icons
                                                      .play_arrow_rounded,
                                                  gradient:
                                                  LinearGradient(
                                                    colors: [
                                                      Colors.amber
                                                          .shade600,
                                                      Colors.amber
                                                          .shade800
                                                    ],
                                                  ),
                                                  textColor:
                                                  Colors.black,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 16),
                                              SizedBox(
                                                width:
                                                double.infinity,
                                                child: _GameButton(
                                                  onPressed:
                                                  _shareGameInvite,
                                                  text:
                                                  'INVITE FRIENDS',
                                                  icon: Icons
                                                      .share_rounded,
                                                  gradient:
                                                  LinearGradient(
                                                    colors: [
                                                      Colors.blue
                                                          .shade600,
                                                      Colors.blue
                                                          .shade800
                                                    ],
                                                  ),
                                                  textColor:
                                                  Colors.white,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      if (_voiceChatService != null) ...[
                                        const SizedBox(height: 20),
                                        GestureDetector(
                                          onTap: () => _voiceChatService!
                                              .toggleMute(),
                                          child: Container(
                                            padding:
                                            const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _voiceChatService!
                                                  .isMuted
                                                  ? Colors.red
                                                  .withOpacity(0.7)
                                                  : Colors.green
                                                  .withOpacity(0.7),
                                            ),
                                            child: Icon(
                                              _voiceChatService!.isMuted
                                                  ? CupertinoIcons
                                                  .mic_slash_fill
                                                  : CupertinoIcons
                                                  .mic_fill,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (_voiceChatService
                                          ?.remoteRenderers !=
                                          null)
                                        VoiceChatAudioRenderers(
                                            remoteRenderers:
                                            _voiceChatService!
                                                .remoteRenderers),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: LeaveButton(
                                    onPressed: () {
                                      showCupertinoDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return CupertinoAlertDialog(
                                            title:
                                            const Text("Leave Game"),
                                            content: const Text(
                                                "Are you sure you want to Leave the game?"),
                                            actions: <Widget>[
                                              CupertinoDialogAction(
                                                child: const Text(
                                                  "Cancel",
                                                  style: TextStyle(
                                                    color:
                                                    Colors.blueAccent,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop();
                                                },
                                              ),
                                              CupertinoDialogAction(
                                                isDestructiveAction: true,
                                                child:
                                                const Text("Leave"),
                                                onPressed: () {
                                                  _handleLeaveGame();
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    tooltip: 'Leave Game',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final player = game.players.firstWhere(
              (p) => p.id == widget.playerId,
          orElse: () {
            debugPrint('Player not found: ${widget.playerId}');
            return Player(id: widget.playerId, name: 'Unknown', hand: []);
          },
        );

        if (player.id == 'Unknown') {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(widget.isSinglePlayer
                        ? 'assets/images/beggarbg2.png'
                        : 'assets/images/beggarbg.png'),
                    fit: BoxFit.cover),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error: Player not found in game',
                      style: TextStyle(
                        fontFamily: "Poppins",
                        fontSize: 20,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        ws.connect();
                        _hasShownNewRoundMessage = false;
                        _shownMessages.clear();
                        _timerController?.stop();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LobbyScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'Return to Lobby',
                        style: TextStyle(
                          fontFamily: "Poppins",
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final isMyTurn = game.isTestMode ||
            game.players[game.currentTurn].id == widget.playerId;
        final canPass = isMyTurn &&
            !game.isTestMode &&
            !(game.pile.isEmpty &&
                game.passCount == 0 &&
                player.hand.isNotEmpty);

        return WillPopScope(
          onWillPop: () async {
            showCupertinoDialog(
              context: context,
              builder: (BuildContext context) {
                return CupertinoAlertDialog(
                  title: const Text("Leave Game"),
                  content:
                  const Text("Are you sure you want to exit the game?"),
                  actions: <Widget>[
                    CupertinoDialogAction(
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.blueAccent,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text("Leave"),
                      onPressed: () {
                        _handleLeaveGame();
                      },
                    ),
                  ],
                );
              },
            );
            return false;
          },
          child: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(widget.isSinglePlayer
                        ? 'assets/images/beggarbg2.png'
                        : 'assets/images/beggarbg.png'),
                    fit: BoxFit.cover),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWeb = constraints.maxWidth > 850;
                        return isWeb
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side: Pile, Players list, Turn indicator
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.start,
                                      children: [
                                        // LeaveButton(
                                        //   onPressed: () {
                                        //     showCupertinoDialog(
                                        //       context: context,
                                        //       builder:
                                        //           (BuildContext context) {
                                        //         return CupertinoAlertDialog(
                                        //           title: const Text(
                                        //               "Leave Game"),
                                        //           content: const Text(
                                        //               "Are you sure you want to Leave the game?"),
                                        //           actions: <Widget>[
                                        //             CupertinoDialogAction(
                                        //               child: const Text(
                                        //                 "Cancel",
                                        //                 style: TextStyle(
                                        //                   color: Colors
                                        //                       .blueAccent,
                                        //                 ),
                                        //               ),
                                        //               onPressed: () {
                                        //                 Navigator.of(
                                        //                         context)
                                        //                     .pop();
                                        //               },
                                        //             ),
                                        //             CupertinoDialogAction(
                                        //               isDestructiveAction:
                                        //                   true,
                                        //               child: const Text(
                                        //                   "Leave"),
                                        //               onPressed: () {
                                        //                 _handleLeaveGame();
                                        //               },
                                        //             ),
                                        //           ],
                                        //         );
                                        //       },
                                        //     );
                                        //   },
                                        //   tooltip: 'Leave Game',
                                        // ),
                                        GestureDetector(
                                          onTap: () {
                                            showCupertinoDialog(
                                              context: context,
                                              builder:
                                                  (BuildContext context) {
                                                return CupertinoAlertDialog(
                                                  title: const Text(
                                                      "Leave Game"),
                                                  content: const Text(
                                                      "Are you sure you want to Leave the game?"),
                                                  actions: <Widget>[
                                                    CupertinoDialogAction(
                                                      child: const Text(
                                                        "Cancel",
                                                        style: TextStyle(
                                                          color: Colors
                                                              .blueAccent,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(
                                                            context)
                                                            .pop();
                                                      },
                                                    ),
                                                    CupertinoDialogAction(
                                                      isDestructiveAction:
                                                      true,
                                                      child: const Text(
                                                          "Leave"),
                                                      onPressed: () {
                                                        _handleLeaveGame();
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 8,
                                                vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.exit_to_app,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  "Leave",
                                                  style: const TextStyle(
                                                    fontFamily: "Poppins",
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 8,
                                                vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                              Colors.lightGreenAccent,
                                              borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.games_outlined,
                                                  color: Colors.black,
                                                  size: 30,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'ID: ${widget.gameId}',
                                                  style: const TextStyle(
                                                    fontFamily: "Poppins",
                                                    color: Colors.black,
                                                    fontSize: 16,
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (game.isTestMode)
                                      const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          'Single Player Test: Play cards to test UI',
                                          style: TextStyle(
                                            fontFamily: "Poppins",
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    if (game.pile.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          _getPatternMessage(
                                              game.pile.last,
                                              game.currentPattern),
                                          style: const TextStyle(
                                            fontFamily: "Poppins",
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    const SizedBox(height: 5),
                                    if (!game.isTestMode)
                                      SizedBox(
                                        height: 80,
                                        child: ListView.builder(
                                          scrollDirection:
                                          Axis.horizontal,
                                          itemCount: game.players.length,
                                          itemBuilder: (context, index) {
                                            final sortedPlayers = [
                                              ...game.players.where((p) =>
                                              p.id ==
                                                  widget.playerId),
                                              ...game.players.where((p) =>
                                              p.id !=
                                                  widget.playerId),
                                            ];
                                            final p =
                                            sortedPlayers[index];
                                            final isCurrentTurn = p.id ==
                                                _currentTurnPlayerId &&
                                                !game.isTestMode;
                                            return Padding(
                                              padding:
                                              const EdgeInsets.only(
                                                  right: 10,
                                                  left: 5,
                                                  top: 3,
                                                  bottom: 2),
                                              child:
                                              GlowingPlayerContainer(
                                                liquidGradient: widget.isSinglePlayer
                                                    ? Colors.amberAccent.withOpacity(0.4)
                                                    : Colors.blueAccent.withOpacity(0.4),
                                                avatarBgColor: widget.isSinglePlayer
                                                    ? Colors.amberAccent.withOpacity(0.3)
                                                    : Colors.blueAccent.withOpacity(0.3),
                                                pIconColor: widget.isSinglePlayer
                                                    ? Colors.amberAccent
                                                    : Colors.cyanAccent,
                                                borderColor: isCurrentTurn ? widget.isSinglePlayer
                                                    ? Colors.amberAccent
                                                    :Colors.cyanAccent
                                                    : Colors.white.withOpacity(0.1),
                                                player: p,
                                                isCurrentTurn:
                                                isCurrentTurn,
                                                timerProgress:
                                                isCurrentTurn
                                                    ? _timerProgress
                                                    : 0,
                                                currentTurnPlayerId: game
                                                    .players[
                                                game.currentTurn]
                                                    .id,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    Container(
                                      height: 306.8,
                                      decoration: BoxDecoration(
                                        color:
                                        Colors.white.withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: game.pile.isNotEmpty
                                          ? ListView.builder(
                                        scrollDirection:
                                        Axis.horizontal,
                                        itemCount:
                                        game.pile.last.length,
                                        itemBuilder: (context, i) {
                                          final card =
                                          game.pile.last[i];
                                          return Tooltip(
                                              message: card.isJoker
                                                  ? 'Joker: ${card.assignedRank} of ${card.assignedSuit}'
                                                  : card.isDetails
                                                  ? 'Details Card'
                                                  : '${card.rank} of ${card.suit}',
                                              child: CardWidget(
                                                card: card,
                                              ));
                                        },
                                      )
                                          : Center(
                                        child: Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                          children: [
                                            const Text(
                                              'No cards played',
                                              style: TextStyle(
                                                fontFamily:
                                                "Poppins",
                                                color:
                                                Colors.white70,
                                                fontSize: 20,
                                              ),
                                            ),
                                            const SizedBox(
                                                width: 4),
                                            AnimatedEmoji(
                                              AnimatedEmojis.sad,
                                              size: 30,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      game.isTestMode
                                          ? 'Test Mode: Your turn'
                                          : (isMyTurn
                                          ? 'Your turn!'
                                          : '${game.players[game.currentTurn].name}\'s turn'),
                                      style: TextStyle(
                                        fontFamily: "Poppins",
                                        color: isMyTurn
                                            ? Colors.greenAccent
                                            : (widget.isSinglePlayer
                                            ? Colors.amber
                                            : Colors.redAccent),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Spacer(),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Expanded(
                                          child: AnimatedScaleButton(
                                            myBtnColor: Colors.amber,
                                            onPressed: canPass
                                                ? _handlePass
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  vertical: 10.0),
                                              child: const Text(
                                                'Pass',
                                                style: TextStyle(
                                                  fontFamily: "Poppins",
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w500,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                            tooltip: game.isTestMode
                                                ? 'Passing not allowed in test mode'
                                                : (game.pile.isEmpty &&
                                                game.passCount ==
                                                    0 &&
                                                player.hand
                                                    .isNotEmpty)
                                                ? 'Cannot Pass'
                                                : '',
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        if (_voiceChatService != null)
                                          AnimatedScaleButton(
                                            onPressed: () =>
                                                _voiceChatService!
                                                    .toggleMute(),
                                            child: Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  vertical: 10.0),
                                              child: Icon(
                                                _voiceChatService!.isMuted
                                                    ? CupertinoIcons
                                                    .mic_slash_fill
                                                    : CupertinoIcons
                                                    .mic_fill,
                                                color: Colors.white,
                                                size: 26,
                                              ),
                                            ),
                                            tooltip:
                                            _voiceChatService!.isMuted
                                                ? 'Unmute'
                                                : 'Mute',
                                          ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: AnimatedScaleButton(
                                            myBtnColor: Colors.amber,
                                            onPressed: isMyTurn &&
                                                selectedCards
                                                    .isNotEmpty
                                                ? () => _playCards(
                                                selectedCards)
                                                : null,
                                            child: Padding(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  vertical: 10.0),
                                              child: const Text(
                                                'Play',
                                                style: TextStyle(
                                                  fontFamily: "Poppins",
                                                  color: Colors.white,
                                                  fontWeight:
                                                  FontWeight.w500,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                            // Right side: Player's hand, Action buttons
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10.0),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        child: Padding(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 2.0),
                                          child: LayoutBuilder(
                                            builder:
                                                (context, constraints) {
                                              return Stack(
                                                children: [
                                                  Column(
                                                    children: [
                                                      Container(
                                                        constraints:
                                                        BoxConstraints(
                                                            maxHeight:
                                                            constraints
                                                                .maxHeight),
                                                        child: Padding(
                                                          padding:
                                                          const EdgeInsets
                                                              .only(
                                                              top:
                                                              8.0,
                                                              right:
                                                              20),
                                                          child: GridView
                                                              .builder(
                                                            physics:
                                                            const NeverScrollableScrollPhysics(),
                                                            shrinkWrap:
                                                            true,
                                                            itemCount:
                                                            player
                                                                .hand
                                                                .length,
                                                            gridDelegate:
                                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                                              crossAxisCount:
                                                              4,
                                                              mainAxisSpacing:
                                                              4,
                                                              crossAxisSpacing:
                                                              4,
                                                              childAspectRatio:
                                                              1.20 /
                                                                  1.75,
                                                            ),
                                                            itemBuilder:
                                                                (context,
                                                                index) {
                                                              final card =
                                                              player.hand[
                                                              index];
                                                              return DragTarget<
                                                                  int>(
                                                                builder: (context,
                                                                    candidateData,
                                                                    rejectedData) {
                                                                  return Draggable<
                                                                      int>(
                                                                    data:
                                                                    index,
                                                                    feedback:
                                                                    Material(
                                                                      type:
                                                                      MaterialType.transparency,
                                                                      elevation:
                                                                      8,
                                                                      child:
                                                                      Container(
                                                                        color: Colors.transparent,
                                                                        height: 175,
                                                                        width: 120,
                                                                        child: CardWidget(
                                                                          card: card,
                                                                          isSelected: false,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    childWhenDragging:
                                                                    Opacity(
                                                                      opacity:
                                                                      0.3,
                                                                      child:
                                                                      CardWidget(
                                                                        card: card,
                                                                        isSelected: selectedCards.contains(card),
                                                                      ),
                                                                    ),
                                                                    child:
                                                                    GestureDetector(
                                                                      onLongPress:
                                                                          () {
                                                                        showDialog(
                                                                          context: context,
                                                                          barrierDismissible: true,
                                                                          barrierColor: Colors.transparent,
                                                                          builder: (context) => GestureDetector(
                                                                            onTap: () => Navigator.of(context).pop(),
                                                                            child: Dialog(
                                                                              backgroundColor: Colors.transparent,
                                                                              elevation: 0,
                                                                              insetPadding: EdgeInsets.zero,
                                                                              child: Stack(
                                                                                children: [
                                                                                  BackdropFilter(
                                                                                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                                                                    child: Container(
                                                                                      color: Colors.black.withOpacity(0.3),
                                                                                    ),
                                                                                  ),
                                                                                  Center(
                                                                                    child: GestureDetector(
                                                                                      onTap: () {},
                                                                                      child: SizedBox(
                                                                                        height: 460,
                                                                                        width: 310,
                                                                                        child: CardWidget(
                                                                                          card: card,
                                                                                          isSelected: false,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                      child:
                                                                      AnimatedContainer(
                                                                        duration: const Duration(milliseconds: 200),
                                                                        transform: Matrix4.identity()
                                                                          ..scale(selectedCards.contains(card) ? 1.1 : 1.0)
                                                                          ..translate(0.0, selectedCards.contains(card) ? -10.0 : 0.0),
                                                                        child: CardWidget(
                                                                          card: card,
                                                                          isSelected: selectedCards.contains(card),
                                                                          cardHeight: double.infinity,
                                                                          cardWidth: double.infinity,
                                                                          onTap: isMyTurn
                                                                              ? () {
                                                                            setState(() {
                                                                              if (selectedCards.contains(card)) {
                                                                                selectedCards.remove(card);
                                                                              } else {
                                                                                selectedCards.add(card);
                                                                              }
                                                                              _updateScrollThumbVisibility();
                                                                            });
                                                                          }
                                                                              : null,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                                onAccept:
                                                                    (oldIndex) {
                                                                  setState(
                                                                          () {
                                                                        final card = player
                                                                            .hand
                                                                            .removeAt(oldIndex);
                                                                        player.hand.insert(
                                                                            index,
                                                                            card);
                                                                        final currentHandIds = _lastSentHand
                                                                            .map(_cardId)
                                                                            .toList()
                                                                          ..sort();
                                                                        final newHandIds = player
                                                                            .hand
                                                                            .map(_cardId)
                                                                            .toList()
                                                                          ..sort();
                                                                        if (currentHandIds !=
                                                                            newHandIds) {
                                                                          Provider.of<WebSocketService>(context, listen: false).updateHandOrder(
                                                                              widget.gameId,
                                                                              widget.playerId,
                                                                              player.hand);
                                                                          _lastSentHand =
                                                                              List.from(player.hand);
                                                                        }
                                                                      });
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (_showScrollThumb)
                                                    Positioned(
                                                      right: 4,
                                                      top: 0,
                                                      bottom: 0,
                                                      child: MouseRegion(
                                                        cursor:
                                                        SystemMouseCursors
                                                            .click,
                                                        child:
                                                        GestureDetector(
                                                          onVerticalDragUpdate:
                                                              (details) {
                                                            final newOffset = _scrollController
                                                                .offset +
                                                                details.delta
                                                                    .dy *
                                                                    1.5;
                                                            _scrollController
                                                                .jumpTo(
                                                              newOffset.clamp(
                                                                  0.0,
                                                                  _scrollController
                                                                      .position
                                                                      .maxScrollExtent),
                                                            );
                                                          },
                                                          child:
                                                          Container(
                                                            width: 12,
                                                            margin: const EdgeInsets
                                                                .symmetric(
                                                                vertical:
                                                                8.0),
                                                            decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .white
                                                                  .withOpacity(
                                                                  0.7),
                                                              borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(0.2),
                                                                  blurRadius:
                                                                  4,
                                                                  offset: const Offset(
                                                                      0,
                                                                      2),
                                                                ),
                                                              ],
                                                            ),
                                                            child:
                                                            const Center(
                                                              child: Icon(
                                                                  Icons
                                                                      .drag_handle,
                                                                  color: Colors
                                                                      .black54,
                                                                  size:
                                                                  10),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                            : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.start,
                                children: [
                                  LeaveButton(
                                    onPressed: () {
                                      showCupertinoDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return CupertinoAlertDialog(
                                            title:
                                            const Text("Leave Game"),
                                            content: const Text(
                                                "Are you sure you want to Leave the game?"),
                                            actions: <Widget>[
                                              CupertinoDialogAction(
                                                child: const Text(
                                                  "Cancel",
                                                  style: TextStyle(
                                                    color:
                                                    Colors.blueAccent,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop();
                                                },
                                              ),
                                              CupertinoDialogAction(
                                                isDestructiveAction: true,
                                                child:
                                                const Text("Leave"),
                                                onPressed: () {
                                                  _handleLeaveGame();
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    tooltip: 'Leave Game',
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.lightGreenAccent,
                                        borderRadius:
                                        BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.games_outlined,
                                            color: Colors.black,
                                            size: 30,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'ID: ${widget.gameId}',
                                            style: const TextStyle(
                                              fontFamily: "Poppins",
                                              color: Colors.black,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (game.isTestMode)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Single Player Test: Play cards to test UI',
                                  style: TextStyle(
                                    fontFamily: "Poppins",
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            if (game.pile.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  _getPatternMessage(game.pile.last,
                                      game.currentPattern),
                                  style: const TextStyle(
                                    fontFamily: "Poppins",
                                    color: Colors.white70,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 5),
                            if (!game.isTestMode)
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: game.players.length,
                                  itemBuilder: (context, index) {
                                    final sortedPlayers = [
                                      ...game.players.where(
                                              (p) => p.id == widget.playerId),
                                      ...game.players.where(
                                              (p) => p.id != widget.playerId),
                                    ];
                                    final p = sortedPlayers[index];
                                    final isCurrentTurn =
                                        p.id == _currentTurnPlayerId &&
                                            !game.isTestMode;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          right: 10,
                                          left: 5,
                                          top: 3,
                                          bottom: 2),
                                      child: GlowingPlayerContainer(
                                        liquidGradient: widget.isSinglePlayer
                                            ? Colors.amberAccent.withOpacity(0.4)
                                            : Colors.blueAccent.withOpacity(0.4),
                                        avatarBgColor: widget.isSinglePlayer
                                            ? Colors.amberAccent.withOpacity(0.3)
                                            : Colors.blueAccent.withOpacity(0.3),
                                        pIconColor: widget.isSinglePlayer
                                            ? Colors.amberAccent
                                            : Colors.cyanAccent,
                                        borderColor: isCurrentTurn ? widget.isSinglePlayer
                                            ? Colors.amberAccent
                                            :Colors.cyanAccent
                                            : Colors.white.withOpacity(0.1),
                                        player: p,
                                        isCurrentTurn: isCurrentTurn,
                                        timerProgress: isCurrentTurn
                                            ? _timerProgress
                                            : 0,
                                        currentTurnPlayerId: game
                                            .players[game.currentTurn].id,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0),
                              child: Container(
                                height: 157,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: game.pile.isNotEmpty
                                    ? ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: game.pile.last.length,
                                  itemBuilder: (context, i) {
                                    final card = game.pile.last[i];
                                    return Tooltip(
                                      message: card.isJoker
                                          ? 'Joker: ${card.assignedRank} of ${card.assignedSuit}'
                                          : card.isDetails
                                          ? 'Details Card'
                                          : '${card.rank} of ${card.suit}',
                                      child: CardWidget(card: card),
                                    );
                                  },
                                )
                                    : Center(
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'No cards played',
                                        style: TextStyle(
                                          fontFamily: "Poppins",
                                          color: Colors.white70,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      AnimatedEmoji(
                                        AnimatedEmojis.sad,
                                        size: 30,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              game.isTestMode
                                  ? 'Test Mode: Your turn'
                                  : (isMyTurn
                                  ? 'Your turn!'
                                  : '${game.players[game.currentTurn].name}\'s turn'),
                              style: TextStyle(
                                fontFamily: "Poppins",
                                color: isMyTurn
                                    ? Colors.greenAccent
                                    : (widget.isSinglePlayer
                                    ? Colors.amber
                                    : Colors.redAccent),
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Stack(
                                        children: [
                                          Column(
                                            children: [
                                              Container(
                                                constraints: BoxConstraints(
                                                    maxHeight: constraints
                                                        .maxHeight),
                                                child: Padding(
                                                  padding:
                                                  const EdgeInsets
                                                      .only(
                                                      top: 8.0,
                                                      right: 20),
                                                  child: GridView.builder(
                                                    physics:
                                                    const NeverScrollableScrollPhysics(),
                                                    shrinkWrap: true,
                                                    itemCount: player
                                                        .hand.length,
                                                    gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                      crossAxisCount: 4,
                                                      mainAxisSpacing: 4,
                                                      crossAxisSpacing: 4,
                                                      childAspectRatio:
                                                      3.07 / 4.4,
                                                    ),
                                                    itemBuilder:
                                                        (context, index) {
                                                      final card = player
                                                          .hand[index];
                                                      return DragTarget<
                                                          int>(
                                                        builder: (context,
                                                            candidateData,
                                                            rejectedData) {
                                                          return Draggable<
                                                              int>(
                                                            data: index,
                                                            feedback:
                                                            Material(
                                                              type: MaterialType
                                                                  .transparency,
                                                              elevation:
                                                              8,
                                                              child:
                                                              Container(
                                                                color: Colors
                                                                    .transparent,
                                                                height:
                                                                175,
                                                                width:
                                                                120,
                                                                child: CardWidget(

                                                                    card:
                                                                    card,
                                                                    isSelected:
                                                                    false),
                                                              ),
                                                            ),
                                                            childWhenDragging:
                                                            Opacity(
                                                              opacity:
                                                              0.3,
                                                              child:
                                                              CardWidget(

                                                                card:
                                                                card,
                                                                isSelected:
                                                                selectedCards
                                                                    .contains(card),
                                                              ),
                                                            ),
                                                            child:
                                                            GestureDetector(
                                                              onLongPress:
                                                                  () {
                                                                showDialog(
                                                                  context:
                                                                  context,
                                                                  barrierDismissible:
                                                                  true,
                                                                  barrierColor:
                                                                  Colors.transparent,
                                                                  builder:
                                                                      (context) =>
                                                                      GestureDetector(
                                                                        onTap: () =>
                                                                            Navigator.of(context).pop(),
                                                                        child:
                                                                        Dialog(
                                                                          backgroundColor:
                                                                          Colors.transparent,
                                                                          elevation:
                                                                          0,
                                                                          insetPadding:
                                                                          EdgeInsets.zero,
                                                                          child:
                                                                          Stack(
                                                                            children: [
                                                                              BackdropFilter(
                                                                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                                                                child: Container(
                                                                                  color: Colors.black.withOpacity(0.3),
                                                                                ),
                                                                              ),
                                                                              Center(
                                                                                child: GestureDetector(
                                                                                  onTap: () {},
                                                                                  child: SizedBox(
                                                                                    height: 460,
                                                                                    width: 310,
                                                                                    child: CardWidget(
                                                                                      card: card,
                                                                                      isSelected: false,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                );
                                                              },
                                                              child:
                                                              AnimatedContainer(
                                                                duration: const Duration(
                                                                    milliseconds:
                                                                    200),
                                                                transform: Matrix4
                                                                    .identity()
                                                                  ..scale(selectedCards.contains(card)
                                                                      ? 1.1
                                                                      : 1.0)
                                                                  ..translate(
                                                                      0.0,
                                                                      selectedCards.contains(card)
                                                                          ? -10.0
                                                                          : 0.0),
                                                                child:
                                                                CardWidget(
                                                                  borderColor: widget.isSinglePlayer
                                                                      ? Colors.amber
                                                                      : Colors.blue,
                                                                  selectedColor: widget.isSinglePlayer
                                                                      ? Colors.amberAccent.withOpacity(0.3)
                                                                      : Colors.blueAccent.withOpacity(0.3),
                                                                  card:
                                                                  card,
                                                                  isSelected:
                                                                  selectedCards.contains(card),
                                                                  cardWidth:
                                                                  double.infinity,
                                                                  cardHeight:
                                                                  double.infinity,
                                                                  onTap: isMyTurn
                                                                      ? () {
                                                                    setState(() {
                                                                      if (selectedCards.contains(card)) {
                                                                        selectedCards.remove(card);
                                                                      } else {
                                                                        selectedCards.add(card);
                                                                      }
                                                                      _updateScrollThumbVisibility();
                                                                    });
                                                                  }
                                                                      : null,
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        onAccept:
                                                            (oldIndex) {
                                                          setState(() {
                                                            final card = player
                                                                .hand
                                                                .removeAt(
                                                                oldIndex);
                                                            player.hand
                                                                .insert(
                                                                index,
                                                                card);
                                                            final currentHandIds =
                                                            _lastSentHand
                                                                .map(
                                                                _cardId)
                                                                .toList()
                                                              ..sort();
                                                            final newHandIds = player
                                                                .hand
                                                                .map(
                                                                _cardId)
                                                                .toList()
                                                              ..sort();
                                                            if (currentHandIds !=
                                                                newHandIds) {
                                                              Provider.of<WebSocketService>(context, listen: false).updateHandOrder(
                                                                  widget
                                                                      .gameId,
                                                                  widget
                                                                      .playerId,
                                                                  player
                                                                      .hand);
                                                              _lastSentHand =
                                                                  List.from(
                                                                      player.hand);
                                                            }
                                                          });
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_showScrollThumb)
                                            Positioned(
                                              right: 4,
                                              top: 0,
                                              bottom: 0,
                                              child: MouseRegion(
                                                cursor: SystemMouseCursors
                                                    .click,
                                                child: GestureDetector(
                                                  onVerticalDragUpdate:
                                                      (details) {
                                                    final newOffset =
                                                        _scrollController
                                                            .offset +
                                                            details.delta
                                                                .dy *
                                                                1.5;
                                                    _scrollController
                                                        .jumpTo(
                                                      newOffset.clamp(
                                                          0.0,
                                                          _scrollController
                                                              .position
                                                              .maxScrollExtent),
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 12,
                                                    margin:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        vertical:
                                                        8.0),
                                                    decoration:
                                                    BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(
                                                          0.7),
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                          6),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors
                                                              .black
                                                              .withOpacity(
                                                              0.2),
                                                          blurRadius: 4,
                                                          offset:
                                                          const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                          Icons
                                                              .drag_handle,
                                                          color: Colors
                                                              .black54,
                                                          size: 10),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: AnimatedScaleButton(
                                      myBtnColor: Colors.amber,
                                      onPressed:
                                      canPass ? _handlePass : null,
                                      child: const Text(
                                        'Pass',
                                        style: TextStyle(
                                          fontFamily: "Poppins",
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      tooltip: game.isTestMode
                                          ? 'Passing not allowed in test mode'
                                          : (game.pile.isEmpty &&
                                          game.passCount == 0 &&
                                          player.hand.isNotEmpty)
                                          ? 'Cannot pass as new round starter'
                                          : '',
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  if (_voiceChatService != null)
                                    AnimatedScaleButton(
                                      onPressed: () =>
                                          _voiceChatService!.toggleMute(),
                                      child: Icon(
                                        _voiceChatService!.isMuted
                                            ? CupertinoIcons
                                            .mic_slash_fill
                                            : CupertinoIcons.mic_fill,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      tooltip: _voiceChatService!.isMuted
                                          ? 'Unmute'
                                          : 'Mute',
                                    ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: AnimatedScaleButton(
                                      myBtnColor: Colors.amber,
                                      onPressed: isMyTurn &&
                                          selectedCards.isNotEmpty
                                          ? () =>
                                          _playCards(selectedCards)
                                          : null,
                                      child: const Text(
                                        'Play',
                                        style: TextStyle(
                                          fontFamily: "Poppins",
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                    if (_showNewRoundNotification && _newRoundMessage != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 16,
                        child: SlideTransition(
                          position: _notificationAnimation!,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _newRoundMessage!,
                              style: const TextStyle(
                                fontFamily: "Poppins",
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// New widget for the animated player container
class GlowingPlayerContainer extends StatelessWidget {
  final Player player;
  final bool isCurrentTurn;
  final double timerProgress;
  final String currentTurnPlayerId;
  final Color borderColor;
  final Color pIconColor;
  final Color avatarBgColor;
  final Color liquidGradient;

  const GlowingPlayerContainer({
    required this.player,
    required this.isCurrentTurn,
    required this.timerProgress,
    required this.currentTurnPlayerId,
    required this.borderColor,
    required this.pIconColor,
    required this.avatarBgColor,
    required this.liquidGradient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: borderColor,
          // isCurrentTurn ? borderColor ?? Colors.cyanAccent : Colors.white.withOpacity(0.1),
          width: isCurrentTurn ? 2.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          if (isCurrentTurn)
            Positioned.fill(
              child: Animate(
                effects: [
                  ShimmerEffect(
                    duration: const Duration(seconds: 40),
                    colors:   [
                      liquidGradient,
                      liquidGradient.withOpacity(0.5),
                      liquidGradient.withOpacity(0.3),
                    ],
                  ),
                ],
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (isCurrentTurn)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LinearProgressIndicator(
                  value: 1.0 -
                      timerProgress, // Reverse progress for countdown effect
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    liquidGradient,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarBgColor,
                  child: Text(
                    player.name[0],
                    style: const TextStyle(
                      fontFamily: "Poppins",
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${player.hand.length} cards${player.title != null ? ', ${player.title}' : ''}',
                        style: const TextStyle(
                          fontFamily: "Poppins",
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isCurrentTurn)
                  AnimateIcon(
                    onTap: () {},
                    iconType: IconType.continueAnimation,
                    height: 30,
                    width: 30,
                    color: pIconColor,
                    animateIcon: AnimateIcons.loading5,
                  ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(
      target: isCurrentTurn ? 1 : 0,
    )
        .scaleXY(
      begin: 0.97,
      end: 1.03,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }
}

// Custom game button widget
class _GameButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final IconData icon;
  final LinearGradient gradient;
  final Color textColor;

  const _GameButton({
    required this.onPressed,
    required this.text,
    required this.icon,
    required this.gradient,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? gradient
              : LinearGradient(
            colors: [Colors.grey.shade600, Colors.grey.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (onPressed != null)
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: textColor,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontFamily: "Poppins",
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedScaleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;
  final Color? myBtnColor;

  const AnimatedScaleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
    this.myBtnColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(onPressed != null ? 1.0 : 0.95),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? myBtnColor?? Colors.blueAccent : Colors.grey,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: onPressed != null ? 4 : 0,
        ),
        child: child,
      ),
    );

    return tooltip != null && tooltip!.isNotEmpty
        ? Tooltip(
      message: tooltip!,
      child: button,
    )
        : button;
  }
}

class AnimatedScaleDailogButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const AnimatedScaleDailogButton({
    super.key,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(onPressed != null ? 1.0 : 0.95),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.2),
          foregroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        child: child,
      ),
    );
  }
}

// Animated dots widget
class AnimatedDots extends StatefulWidget {
  @override
  _AnimatedDotsState createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double opacity = (index + 1) * 0.25;
            final double scale =
                1.0 + (0.2 * sin(_controller.value * 2 * pi + index * 0.5));
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          },
          child: Text(
            '.',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }),
    );
  }
}

