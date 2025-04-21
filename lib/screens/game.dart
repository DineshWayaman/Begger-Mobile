import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/card.dart';
import '../services/websocket.dart';
import '../widgets/card_widget.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String playerId;

  const GameScreen({required this.gameId, required this.playerId, super.key});

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  List<Cards> selectedCards = [];
  String? roundMessage;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollThumb = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollThumbVisibility();
    });
    _scrollController.addListener(_updateScrollThumbVisibility);

  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  void _updateScrollThumbVisibility() {
    if (_scrollController.hasClients) {
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final viewportHeight = _scrollController.position.viewportDimension;
      final contentHeight = maxScrollExtent + viewportHeight;
      final showThumb = contentHeight > viewportHeight + 10;
      print(
          'Content Height: $contentHeight, Viewport Height: $viewportHeight, Show Thumb: $showThumb');
      if (showThumb != _showScrollThumb) {
        setState(() {
          _showScrollThumb = showThumb;
        });
      }
    } else {
      print('ScrollController not attached');
    }
  }

  Future<List<Cards>?> _assignJokerValues(List<Cards> cards) async {
    print('Joker Dialog: Starting assignment for ${cards.length} cards: ${cards.map((c) => c.isJoker ? c.suit : "${c.rank} of ${c.suit}").toList()}');
    List<Cards> assignedCards = [];



    for (var card in cards) {
      if (!card.isJoker) {
        assignedCards.add(card);
        print('Joker Dialog: Non-Joker card added: ${card.rank} of ${card.suit}');
        continue;
      }

      try {
        final assignedCard = await showDialog<Cards>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withOpacity(0.2),
          builder: (dialogContext) {
            String? selectedRank;
            String? selectedSuit;

            return GestureDetector(
              // From your April 16, 2025, dialog dismissal fix
              onTap: () {
                print('Joker Dialog: Tapped outside, dismissing');
                Navigator.of(dialogContext).pop();
              },
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assign Joker Value',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Rank',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedRank,
                              items: ['3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A', '2']
                                  .map((rank) => DropdownMenuItem(
                                value: rank,
                                child: Text(rank),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                print('Joker Dialog: Selected rank: $value');
                                setDialogState(() => selectedRank = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Suit',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedSuit,
                              items: ['hearts', 'diamonds', 'clubs', 'spades']
                                  .map((suit) => DropdownMenuItem(
                                value: suit,
                                child: Text(suit),
                              ))
                                  .toList(),
                              onChanged: (value) {
                                print('Joker Dialog: Selected suit: $value');
                                setDialogState(() => selectedSuit = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    print('Joker Dialog: Cancel pressed');
                                    Navigator.of(dialogContext).pop();
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: selectedRank != null && selectedSuit != null
                                      ? () {
                                    print('Joker Dialog: OK pressed, assigning $selectedRank of $selectedSuit');
                                    Navigator.of(dialogContext).pop(
                                      Cards(
                                        isJoker: true,
                                        suit: card.suit, // joker1 or joker2
                                        assignedRank: selectedRank,
                                        assignedSuit: selectedSuit,
                                      ),
                                    );
                                  }
                                      : null,
                                  child: const Text('OK'),
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
          print('Joker Dialog: Assignment cancelled for ${card.suit}');
          return null;
        }
        assignedCards.add(assignedCard);
        print('Joker Dialog: Assigned ${assignedCard.assignedRank} of ${assignedCard.assignedSuit} for ${card.suit}');
      } catch (e, stackTrace) {
        print('Joker Dialog: Error during assignment: $e\n$stackTrace');
        return null;
      }
    }

    // Fix Joker: Update hand with assigned Joker values
    final player = Provider.of<WebSocketService>(context, listen: false)
        .game!
        .players
        .firstWhere((p) => p.id == widget.playerId);
    final updatedHand = player.hand.map((c) {
      final assigned = assignedCards.firstWhere(
            (ac) => ac.suit == c.suit && ac.isJoker == c.isJoker,
        orElse: () => c,
      );
      return assigned;
    }).toList();
    print('Joker Dialog: Updating hand with assigned Jokers: ${updatedHand.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
    Provider.of<WebSocketService>(context, listen: false).updateHandOrder(
      widget.gameId,
      widget.playerId,
      updatedHand,
    );

    print('Joker Dialog: Completed assignment, returning ${assignedCards.length} cards: ${assignedCards.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
    return assignedCards;
  }


  // Group Pattern Update: Display pattern message
  String _getPatternMessage(List<Cards> cards, String? pattern) {
    if (cards.isEmpty) return '';
    final effectiveRank = cards[0].isJoker ? cards[0].assignedRank : cards[0].rank;
    if (pattern == 'single') {
      return 'Single: $effectiveRank';
    } else if (pattern == 'pair') {
      return 'Pair: Two $effectiveRank\'s';
    } else if (pattern == 'group-3') {
      return 'Three of a kind: Three $effectiveRank\'s';
    } else if (pattern == 'group-4') {
      return 'Four of a kind: Four $effectiveRank\'s';
    } else if (pattern == 'consecutive') {
      final sortedCards = cards..sort((a, b) {
        final rankA = a.isJoker ? a.assignedRank : a.rank;
        final rankB = b.isJoker ? b.assignedRank : b.rank;
        const values = {
          '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
          '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14, '2': 15,
        };
        return values[rankA!]! - values[rankB!]!;
      });
      final startRank = sortedCards.first.isJoker ? sortedCards.first.assignedRank : sortedCards.first.rank;
      return 'Consecutive: Starting at $startRank';
    }
    return '';
  }
// Fix Bug 1: Validate isDetails card is played alone
  bool _validateDetailsCard(List<Cards> cards) {
    if (cards.any((c) => c.isDetails) && cards.length > 1) {
      print('Validation failed: Details card can only be played as a single card');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details card can only be played alone')),
      );
      return false;
    }
    return true;
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<WebSocketService>(
      builder: (context, ws, _) {
        print('GameScreen build, game: ${ws.game}');
        final game = ws.game;
        if (game == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading Game')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (ws.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(ws.error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          );
        }

        if (game.status == 'waiting') {
          return Scaffold(
            appBar: AppBar(title: const Text('Waiting for Players')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Waiting for more players to join...'),
                  const SizedBox(height: 10),
                  Text('Players: ${game.players.length}/3'),
                  if (ws.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(ws.error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          );
        }

        final player = game.players.firstWhere((p) => p.id == widget.playerId);
        final isMyTurn = game.isTestMode || game.players[game.currentTurn].id == widget.playerId;


        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (game.lastPlayedPlayerId != null && game.pile.isEmpty && game.passCount == 0) {
            final winner = game.players.firstWhere((p) => p.id == game.lastPlayedPlayerId);
            setState(() {
              // roundMessage = '${winner.name} starts new round!';
            });
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => roundMessage = null);
            });
          }
        });

        return Scaffold(
          appBar: AppBar(
            title:
                Text(game.isTestMode ? 'Card Game (Test Mode)' : 'Beggar Game'),
          ),
          body: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              children: [
                if (game.isTestMode)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Single Player Test: Play cards to test UI',
                      style: TextStyle(
                          color: Colors.blue, fontStyle: FontStyle.italic),
                    ),
                  ),
                if (roundMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      roundMessage!,
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),


                // Group Pattern Update: Show last played pattern
                if (game.pile.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      _getPatternMessage(game.pile.last, game.currentPattern),
                      style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 15),
                if (!game.isTestMode)
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: game.players.length,
                      itemBuilder: (context, i) {
                        final p = game.players[i];
                        if (p.id == widget.playerId)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 120,
                              maxWidth: 180,
                            ),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                leading: CircleAvatar(
                                  radius: 20,
                                  child: Text(
                                    p.name[0],
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${p.hand.length} cards',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    p.id == game.players[game.currentTurn].id
                                        ? const Icon(Icons.timer,
                                            color: Colors.yellow, size: 30)
                                        : null,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  height: 155,
                  color: Colors.grey[200],
                  child: game.pile.isNotEmpty
                      ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: game.pile.last.length,
                            itemBuilder: (context, i) => CardWidget(

                              card: game.pile.last[i],
                            ),
                          ),
                      )
                      : const Center(child: Text('No cards played')),
                ),
                Text(
                  game.isTestMode
                      ? 'Test Mode: Your turn'
                      : (isMyTurn
                          ? 'Your turn!'
                          : '${game.players[game.currentTurn].name}\'s turn'),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              controller: _scrollController,
                              child: Container(
                                padding: EdgeInsets.only(
                                    right: _showScrollThumb ? 16.0 : 0.0),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: player.hand.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 1,
                                    childAspectRatio: 3.1 / 4.5,
                                  ),
                                  itemBuilder: (context, index) {
                                    final card = player.hand[index];
                                    return DragTarget<int>(
                                      builder: (context, candidateData,
                                          rejectedData) {
                                        return Draggable<int>(
                                          data: index,
                                          feedback: Material(
                                            type: MaterialType.transparency,
                                            elevation: 4,
                                            child: Container(
                                              color: Colors.transparent,
                                              height: 175,
                                              width: 120,
                                              child: CardWidget(
                                                card: card,
                                                isSelected: false,
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(
                                            opacity: 0.3,
                                            child: CardWidget(
                                              card: card,
                                              isSelected:
                                                  selectedCards.contains(card),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onLongPress: () {
                                              showDialog(
                                                context: context,
                                                barrierDismissible: true,
                                                barrierColor:
                                                    Colors.transparent,
                                                builder: (context) =>
                                                    GestureDetector(
                                                  onTap: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: Dialog(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    elevation: 0,
                                                    insetPadding:
                                                        EdgeInsets.zero,
                                                    child: Stack(
                                                      children: [
                                                        BackdropFilter(
                                                          filter:
                                                              ImageFilter.blur(
                                                                  sigmaX: 3,
                                                                  sigmaY: 3),
                                                          child: Container(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.2),
                                                          ),
                                                        ),
                                                        Center(
                                                          child:
                                                              GestureDetector(
                                                            onTap: () {},
                                                            child: SizedBox(
                                                              height: 460,
                                                              width: 310,
                                                              child: CardWidget(
                                                                card: card,
                                                                isSelected:
                                                                    false,
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
                                            child: CardWidget(
                                              card: card,
                                              isSelected:
                                                  selectedCards.contains(card),
                                              onTap: isMyTurn
                                                  ? () {
                                                      setState(() {
                                                        if (selectedCards
                                                            .contains(card)) {
                                                          selectedCards
                                                              .remove(card);
                                                        } else {
                                                          selectedCards
                                                              .add(card);
                                                        }
                                                        _updateScrollThumbVisibility();
                                                      });
                                                    }
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      onAccept: (oldIndex) {
                                        setState(() {
                                          final card = player.hand.removeAt(oldIndex);
                                          player.hand.insert(index, card);
                                          // Fix: Sync hand order with server after drag-and-drop
                                          print('Drag reorder: New hand order: ${player.hand.map((c) => c.isJoker ? c.suit : "${c.rank} of ${c.suit}").toList()}');
                                          Provider.of<WebSocketService>(context, listen: false).updateHandOrder(
                                            widget.gameId,
                                            widget.playerId,
                                            player.hand,
                                          );
                                        });
                                      },

                                      // onAccept: (oldIndex) {
                                      //   setState(() {
                                      //     final card =
                                      //         player.hand.removeAt(oldIndex);
                                      //     player.hand.insert(index, card);
                                      //     print('Drag reorder: New hand order: ${player.hand.map((c) => c.isJoker ? c.suit : "${c.rank} of ${c.suit}").toList()}');
                                      //     _updateScrollThumbVisibility();
                                      //   });
                                      // },
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (_showScrollThumb)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onVerticalDragUpdate: (details) {
                                    final newOffset = _scrollController.offset +
                                        details.delta.dy * 1.5;
                                    _scrollController.jumpTo(
                                      newOffset.clamp(
                                          0.0,
                                          _scrollController
                                              .position.maxScrollExtent),
                                    );
                                  },
                                  child: Container(
                                    width: 16,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: isMyTurn && selectedCards.isNotEmpty
                          ? () async {
                        // Fix Bug 1: Validate details card before play
                        if (!_validateDetailsCard(selectedCards)) return;
                        print('Play button: Selected cards: ${selectedCards.map((c) => c.isJoker ? c.suit : "${c.rank} of ${c.suit}").toList()}');
                        final assignedCards = await _assignJokerValues(selectedCards);
                        if (assignedCards != null) {
                          print('Play button: Sending assigned cards: ${assignedCards.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
                          // Fix: Send current hand order with play
                          ws.playPattern(
                            widget.gameId,
                            widget.playerId,
                            assignedCards,
                            player.hand,
                          );
                          setState(() => selectedCards = []);
                        } else {
                          print('Play button: No cards assigned, play cancelled');
                        }
                      }
                          : null,
                      child: const Text('Play'),
                    ),
                    // ElevatedButton(
                    //   onPressed: isMyTurn && selectedCards.isNotEmpty
                    //       ? () async {
                    //           // Joker Update: Assign values for Jokers
                    //           final assignedCards =
                    //               await _assignJokerValues(selectedCards);
                    //           if (assignedCards != null) {
                    //
                    //             // Card Order Fix: Send current hand order
                    //             ws.playPattern(
                    //               widget.gameId,
                    //               widget.playerId,
                    //               assignedCards,
                    //               player.hand, // Send full hand
                    //             );
                    //             setState(() => selectedCards = []);
                    //           }
                    //         }
                    //       : null,
                    //   child: const Text('Play'),
                    // ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isMyTurn
                          ? () {
                        ws.pass(widget.gameId, widget.playerId);
                        // Fix Bug 2: Clear selectedCards after pass
                        setState(() {
                          selectedCards = [];
                          print('Pass: Cleared selected cards');
                        });
                      }
                          : null,
                      child: const Text('Pass'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: isMyTurn && selectedCards.isNotEmpty
                          ? () async {
                        // Fix Bug 1: Validate details card before take chance
                        if (!_validateDetailsCard(selectedCards)) return;
                        print('Take Chance button: Selected cards: ${selectedCards.map((c) => c.isJoker ? c.suit : "${c.rank} of ${c.suit}").toList()}');
                        final assignedCards = await _assignJokerValues(selectedCards);
                        if (assignedCards != null) {
                          print('Take Chance button: Sending assigned cards: ${assignedCards.map((c) => c.isJoker ? "${c.assignedRank} of ${c.assignedSuit}" : "${c.rank} of ${c.suit}").toList()}');
                          // Fix: Send current hand order with take chance
                          ws.takeChance(
                            widget.gameId,
                            widget.playerId,
                            assignedCards,
                            player.hand,
                          );
                          setState(() => selectedCards = []);
                        } else {
                          print('Take Chance button: No cards assigned, take chance cancelled');
                        }
                      }
                          : null,
                      child: const Text('Take Chance'),
                    ),
                    // ElevatedButton(
                    //   onPressed: isMyTurn && selectedCards.isNotEmpty
                    //       ? () async {
                    //           // Joker Update: Assign values for Jokers
                    //           final assignedCards =
                    //               await _assignJokerValues(selectedCards);
                    //           if (assignedCards != null) {
                    //
                    //             // Card Order Fix: Send current hand order
                    //             ws.takeChance(
                    //               widget.gameId,
                    //               widget.playerId,
                    //               assignedCards,
                    //               player.hand, // Send full hand
                    //             );
                    //             setState(() => selectedCards = []);
                    //           }
                    //         }
                    //       : null,
                    //   child: const Text('Take Chance'),
                    // ),
                  ],
                ),
                if (ws.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(ws.error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
