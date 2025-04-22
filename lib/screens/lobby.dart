import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket.dart';
import '../widgets/custom_text_field.dart';
import 'game.dart';
import 'package:google_fonts/google_fonts.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _gameIdController = TextEditingController();
  final _playerNameController = TextEditingController();
  bool isTestMode = false;

  @override
  Widget build(BuildContext context) {
    final websocket = Provider.of<WebSocketService>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade300, Colors.purple.shade400],
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
                      Text(
                        'Beggar',
                        style: GoogleFonts.roboto(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomTextField(
                        controller: _playerNameController,
                        hint: 'Your Name',

                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _gameIdController,
                        hint: 'Game ID (leave blank to create new)',

                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: Text(
                          'Test Mode (Single Player)',
                          style: GoogleFonts.roboto(fontSize: 16),
                        ),
                        value: isTestMode,
                        onChanged: (value) => setState(() => isTestMode = value!),
                        activeColor: Colors.blue.shade700,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          final name = _playerNameController.text.trim().isEmpty
                              ? 'Player'
                              : _playerNameController.text.trim();
                          final gameId = _gameIdController.text.trim().isEmpty
                              ? DateTime.now().toString()
                              : _gameIdController.text.trim();
                          if (name.length > 20) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Name must be 20 characters or less',
                                  style: GoogleFonts.roboto(),
                                ),
                                backgroundColor: Colors.red.shade400,
                              ),
                            );
                            return;
                          }
                          final playerId = '$gameId-$name';
                          websocket.joinGame(gameId, playerId, name, isTestMode: isTestMode);
                          websocket.requestGameState(gameId);
                          Navigator.push(
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
                              style: GoogleFonts.roboto(
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