import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/websocket.dart';
import '../widgets/custom_text_field.dart';
import 'game.dart';

class LobbyScreen extends StatefulWidget {
  final String? playerName;

  const LobbyScreen({super.key, this.playerName});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _gameIdController = TextEditingController();
  late final TextEditingController _playerNameController;
  bool isTestMode = false;

  @override
  void initState() {
    super.initState();
    _playerNameController = TextEditingController(text: widget.playerName);
    _gameIdController.text = _generateGameId();
  }

  String _generateGameId() {
    const uuid = Uuid();
    // Generate a UUID and take the first 8 characters for brevity
    return uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
  }

  void _copyGameId() {
    Clipboard.setData(ClipboardData(text: _gameIdController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Game ID copied to clipboard',
          style: TextStyle(fontFamily: "Poppins"),
        ),
        backgroundColor: Colors.green.shade400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final websocket = Provider.of<WebSocketService>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/beggarbg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.blue.shade900,
                              size: 40,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Beggar',
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _playerNameController,
                        hint: 'Your Name',
                        isReadOnly: true,
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _gameIdController,
                        hint: 'Game ID',
                        isReadOnly: false,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.copy, color: Colors.blue.shade900),
                          onPressed: _copyGameId,
                        ),
                      ),
                      Text(
                        "Copy this Game ID and share it with your friends or Paste your friend's Game ID",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          final name = _playerNameController.text.trim().isEmpty
                              ? 'Player'
                              : _playerNameController.text.trim();
                          final gameId = _gameIdController.text.trim();
                          if (name.length > 20) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Name must be 20 characters or less',
                                  style: TextStyle(
                                    fontFamily: "Poppins",
                                  ),
                                ),
                                backgroundColor: Colors.red.shade400,
                              ),
                            );
                            return;
                          }
                          final playerId = '$gameId-$name';
                          // Reset WebSocketService state before joining
                          websocket.joinGame(gameId, playerId, name, isTestMode: isTestMode);
                          websocket.requestGameState(gameId);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GameScreen(gameId: gameId, playerId: playerId),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade600, Colors.blue.shade900],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade200.withOpacity(0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          width: double.infinity,
                          child: Center(
                            child: Text(
                              'Join/Create Game',
                              style: TextStyle(
                                fontFamily: "Poppins",
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameIdController.dispose();
    _playerNameController.dispose();
    super.dispose();
  }
}