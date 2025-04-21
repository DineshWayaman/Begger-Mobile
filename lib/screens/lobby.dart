import 'package:begger_card_game/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket.dart';
import 'game.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  _LobbyScreenState createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _gameIdController = TextEditingController();
  final _playerNameController = TextEditingController();
  String playerId = DateTime.now().toString();
  bool isTestMode = false;

  @override
  Widget build(BuildContext context) {
    final websocket = Provider.of<WebSocketService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Begger Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Image.asset("assets/cards/info_card.png", width: 200, height: 200,),
            Text("Beggar",style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,

            ),),
            SizedBox(height: 10,),
            CustomTextField(
              controller: _playerNameController,
              hint: 'Your Name',
            ),
            SizedBox(height: 10,),
            CustomTextField(
              controller: _gameIdController,
              hint: 'Game ID',
            ),


            CheckboxListTile(
              title: const Text('Test Mode (Single Player)'),
              value: isTestMode,
              onChanged: (value) => setState(() => isTestMode = value!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final gameId = _gameIdController.text.isEmpty
                    ? DateTime.now().toString()
                    : _gameIdController.text;
                final name = _playerNameController.text.isEmpty
                    ? 'Player'
                    : _playerNameController.text;
                websocket.joinGame(gameId, playerId, name, isTestMode: isTestMode);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameScreen(
                      gameId: gameId,
                      playerId: playerId,
                    ),
                  ),
                );
              },
              child: const Text('Join/Create Game'),
            ),
          ],
        ),
      ),
    );
  }
}