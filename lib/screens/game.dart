import 'dart:ui';
import 'package:begger_card_game/models/player.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/card.dart';
import '../services/websocket.dart';
import '../widgets/card_widget.dart';
import 'lobby.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerId;

  const GameScreen({required this.gameId, required this.playerId, super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
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
  BuildContext? _dialogContext;
  bool _isRestarted = false; // Tracks if restart was initiated

  @override
  void initState() {
    super.initState();
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
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _updateScrollThumbVisibility();
    });
    _scrollController.addListener(_updateScrollThumbVisibility);
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.addListener(_onGameStateChanged);
    ws.onDismissDialog = () {
      if (_isDialogShowing && _dialogContext != null && mounted) {
        Navigator.of(_dialogContext!).pop();
        setState(() {
          _isDialogShowing = false;
          _dialogContext = null;
          _isRestarted = true; // Mark as restarted
        });
      }
    };
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
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.removeListener(_onGameStateChanged);
    ws.onDismissDialog = null;
    super.dispose();
  }

  void _onGameStateChanged() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null) {
      _showGameMessages();
      return;
    }

    if (!_hasShownNewRoundMessage && game.status != 'waiting' && game.pile.isEmpty && game.passCount == 0) {
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
                  _isRestarted = false; // Reset after new round notification
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(jokerMessage, style: GoogleFonts.poppins()),
                    backgroundColor: Colors.blueAccent,
                    duration: const Duration(seconds: 3),
                  ),
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

    final titledPlayers = game.players.where((p) => p.title != null).toList();
    if (titledPlayers.isNotEmpty && titledPlayers.length == game.players.length) {
      final message = titledPlayers.map((p) => '${p.name}: ${p.title}').join('\n');
      if (!_shownMessages.contains(message)) {
        _shownMessages.add(message);
        _showGameSummaryDialog(message);
      }
    }
  }

  void _showGameSummaryDialog(String message) {
    if (_isDialogShowing || !mounted) return;
    setState(() {
      _isDialogShowing = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          _dialogContext = dialogContext;
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Game Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200,
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          message,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        AnimatedScaleDailogButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            setState(() {
                              _isDialogShowing = false;
                              _dialogContext = null;
                            });
                            _hasShownNewRoundMessage = false;
                            _shownMessages.clear();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LobbyScreen()),
                            );
                          },
                          child: Text(
                            'Lobby',
                            style: GoogleFonts.poppins(
                              color: Colors.teal,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        AnimatedScaleDailogButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            setState(() {
                              _isDialogShowing = false;
                              _dialogContext = null;
                              _isRestarted = true; // Mark as restarted
                            });
                            _handleRestartGame();
                          },
                          child: Text(
                            'Replay',
                            style: GoogleFonts.poppins(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).then((_) {
        setState(() {
          _isDialogShowing = false;
          _dialogContext = null;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Rank',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            value: selectedRank,
                            items: [
                              '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2'
                            ].map((rank) => DropdownMenuItem(
                              value: rank,
                              child: Text(rank, style: GoogleFonts.poppins()),
                            )).toList(),
                            onChanged: (value) => setDialogState(() => selectedRank = value),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Suit',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
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
                              child: Text(suit, style: GoogleFonts.poppins()),
                            ))
                                .toList(),
                            onChanged: (value) => setDialogState(() => selectedSuit = value),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(
                                      color: Colors.grey[600], fontWeight: FontWeight.w500),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: selectedRank != null && selectedSuit != null
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
                                  style: GoogleFonts.poppins(
                                      color: Colors.white, fontWeight: FontWeight.w500),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joker assignment cancelled', style: GoogleFonts.poppins()),
              backgroundColor: Colors.redAccent,
            ),
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
    final effectiveRank = firstCard.isJoker ? firstCard.assignedRank : firstCard.rank;
    final effectiveSuit = firstCard.isJoker ? firstCard.assignedSuit : firstCard.suit;

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
            '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
            '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14, '2': 15,
          };
          final valueA = rankA != null ? values[rankA] ?? 0 : 0;
          final valueB = rankB != null ? values[rankB] ?? 0 : 0;
          return valueA - valueB;
        });
      final startCard = sortedCards.first;
      final startRank = startCard.isJoker ? startCard.assignedRank : startCard.rank;
      final startSuit = startCard.isJoker ? startCard.assignedSuit : startCard.suit;
      return hasJoker
          ? 'Joker Consecutive: Starting at $startRank of $startSuit'
          : 'Consecutive: Starting at $startRank of $startSuit';
    }
    return '';
  }

  bool _validateDetailsCard(List<Cards> cards) {
    if (cards.any((c) => c.isDetails) && cards.length > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Details card can only be played alone', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return false;
    }
    return true;
  }

  void _playCards(List<Cards> cards, {bool isTakeChance = false}) async {
    if (!_validateDetailsCard(cards)) return;

    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game not loaded', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Player not found in game', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final assignedCards = await _assignJokerValues(cards);
    if (assignedCards == null || assignedCards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play cancelled', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final playedCardIds = assignedCards.map(_cardId).toList();
    final remainingHand = player.hand.where((c) => !playedCardIds.contains(_cardId(c))).toList();

    if (game.isTestMode) {
      setState(() {
        player.hand = remainingHand;
        game.pile.add(assignedCards);
        selectedCards = [];
        _lastSentHand = List.from(remainingHand);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Played ${assignedCards.length} cards in test mode', style: GoogleFonts.poppins()),
            backgroundColor: Colors.green,
          ),
        );
      }
      ws.playPattern(widget.gameId, widget.playerId, assignedCards, remainingHand);
    } else {
      if (isTakeChance) {
        ws.takeChance(widget.gameId, widget.playerId, assignedCards, remainingHand);
      } else {
        ws.playPattern(widget.gameId, widget.playerId, assignedCards, remainingHand);
      }
      if (ws.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play failed: ${ws.error}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
        ws.error = null;
      }
      setState(() {
        selectedCards = [];
        _lastSentHand = List.from(remainingHand);
      });
    }
  }

  void _handlePass() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    final game = ws.game;
    if (game == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Game not loaded', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    if (game.isTestMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passing not allowed in test mode', style: GoogleFonts.poppins()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    ws.pass(widget.gameId, widget.playerId);
    if (ws.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pass failed: ${ws.error}', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      ws.error = null;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passed!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        selectedCards = [];
      });
    }
  }

  void _handleStartGame() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.startGame(widget.gameId, widget.playerId);
    if (ws.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start game: ${ws.error}', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      ws.error = null;
    }
  }

  void _handleRestartGame() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.restartGame(widget.gameId, widget.playerId);
    if (ws.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restart game: ${ws.error}', style: GoogleFonts.poppins()),
          backgroundColor: Colors.redAccent,
        ),
      );
      ws.error = null;
    } else {
      // Clear messages and reset state only after successful restart
      _hasShownNewRoundMessage = false;
      _shownMessages.clear();
    }
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $errorMessage', style: GoogleFonts.poppins()),
                  backgroundColor: Colors.redAccent,
                ),
              );
              if (errorMessage == 'Game is full' || errorMessage == 'Game has already started') {
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
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.purple.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          );
        }

        if (game.status == 'waiting') {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.purple.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Waiting for more players to join...',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Players: ${game.players.length}/6',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Need at least 2 players to start',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedScaleButton(
                      onPressed: game.players.length >= 2 ? _handleStartGame : null,
                      child: Text(
                        'Start Game',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
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
                gradient: LinearGradient(
                  colors: [Colors.blue.shade300, Colors.purple.shade300],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Error: Player not found in game',
                      style: GoogleFonts.poppins(
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
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LobbyScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Return to Lobby',
                        style: GoogleFonts.poppins(
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

        final isMyTurn = game.isTestMode || game.players[game.currentTurn].id == widget.playerId;
        final canPass = isMyTurn &&
            !game.isTestMode &&
            !(game.pile.isEmpty && game.passCount == 0 && player.hand.isNotEmpty);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade300, Colors.purple.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                    child: Column(
                      children: [
                        if (game.isTestMode)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Single Player Test: Play cards to test UI',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        if (game.pile.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getPatternMessage(game.pile.last, game.currentPattern),
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        if (!game.isTestMode)
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: game.players.length,
                              itemBuilder: (context, i) {
                                final p = game.players[i];
                                if (p.id == widget.playerId) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Container(
                                    height: 50,
                                    width: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.blueAccent.withOpacity(0.3),
                                            child: Text(
                                              p.name[0],
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  p.name,
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${p.hand.length} cards${p.title != null ? ', ${p.title}' : ''}',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (p.id == game.players[game.currentTurn].id)
                                            const Icon(Icons.timer, color: Colors.yellow, size: 24),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                        Container(
                          height: 157,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: game.pile.isNotEmpty
                              ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: ListView.builder(
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
                            ),
                          )
                              : Center(
                            child: Text(
                              'No cards played',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 16,
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
                          style: GoogleFonts.poppins(
                            color: isMyTurn ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      Column(
                                        children: [
                                          Container(
                                            constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 8.0, right: 20),
                                              child: GridView.builder(
                                                physics: const NeverScrollableScrollPhysics(),
                                                shrinkWrap: true,
                                                itemCount: player.hand.length,
                                                gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 4,
                                                  mainAxisSpacing: 4,
                                                  crossAxisSpacing: 4,
                                                  childAspectRatio: 3.07 / 4.4,
                                                ),
                                                itemBuilder: (context, index) {
                                                  final card = player.hand[index];
                                                  return DragTarget<int>(
                                                    builder: (context, candidateData, rejectedData) {
                                                      return Draggable<int>(
                                                        data: index,
                                                        feedback: Material(
                                                          type: MaterialType.transparency,
                                                          elevation: 8,
                                                          child: Container(
                                                            color: Colors.transparent,
                                                            height: 175,
                                                            width: 120,
                                                            child: CardWidget(
                                                                card: card, isSelected: false),
                                                          ),
                                                        ),
                                                        childWhenDragging: Opacity(
                                                          opacity: 0.3,
                                                          child: CardWidget(
                                                            card: card,
                                                            isSelected: selectedCards.contains(card),
                                                          ),
                                                        ),
                                                        child: GestureDetector(
                                                          onLongPress: () {
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
                                                                        filter: ImageFilter.blur(
                                                                            sigmaX: 5, sigmaY: 5),
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
                                                          child: AnimatedContainer(
                                                            duration: const Duration(milliseconds: 200),
                                                            transform: Matrix4.identity()
                                                              ..scale(
                                                                  selectedCards.contains(card) ? 1.1 : 1.0)
                                                              ..translate(
                                                                  0.0,
                                                                  selectedCards.contains(card)
                                                                      ? -10.0
                                                                      : 0.0),
                                                            child: CardWidget(
                                                              card: card,
                                                              isSelected: selectedCards.contains(card),
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
                                                    onAccept: (oldIndex) {
                                                      setState(() {
                                                        final card = player.hand.removeAt(oldIndex);
                                                        player.hand.insert(index, card);
                                                        final currentHandIds =
                                                        _lastSentHand.map(_cardId).toList()
                                                          ..sort();
                                                        final newHandIds =
                                                        player.hand.map(_cardId).toList()
                                                          ..sort();
                                                        if (currentHandIds != newHandIds) {
                                                          Provider.of<WebSocketService>(context,
                                                              listen: false)
                                                              .updateHandOrder(
                                                              widget.gameId,
                                                              widget.playerId,
                                                              player.hand);
                                                          _lastSentHand = List.from(player.hand);
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
                                            cursor: SystemMouseCursors.click,
                                            child: GestureDetector(
                                              onVerticalDragUpdate: (details) {
                                                final newOffset = _scrollController.offset +
                                                    details.delta.dy * 1.5;
                                                _scrollController.jumpTo(
                                                  newOffset.clamp(
                                                      0.0, _scrollController.position.maxScrollExtent),
                                                );
                                              },
                                              child: Container(
                                                width: 12,
                                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(6),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Center(
                                                  child: Icon(Icons.drag_handle,
                                                      color: Colors.black54, size: 10),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AnimatedScaleButton(
                              onPressed: isMyTurn && selectedCards.isNotEmpty
                                  ? () => _playCards(selectedCards)
                                  : null,
                              child: Text(
                                'Play',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            AnimatedScaleButton(
                              onPressed: canPass ? _handlePass : null,
                              child: Text(
                                'Pass',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              tooltip: game.isTestMode
                                  ? 'Passing not allowed in test mode'
                                  : (game.pile.isEmpty && game.passCount == 0 && player.hand.isNotEmpty)
                                  ? 'Cannot pass as new round starter'
                                  : '',
                            ),
                            AnimatedScaleButton(
                              onPressed: isMyTurn && selectedCards.isNotEmpty
                                  ? () => _playCards(selectedCards, isTakeChance: true)
                                  : null,
                              child: Text(
                                'Take Chance',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_showNewRoundNotification && _newRoundMessage != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 16,
                      child: SlideTransition(
                        position: _notificationAnimation!,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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
        );
      },
    );
  }
}

class AnimatedScaleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  const AnimatedScaleButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(onPressed != null ? 1.0 : 0.95),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? Colors.blueAccent : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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