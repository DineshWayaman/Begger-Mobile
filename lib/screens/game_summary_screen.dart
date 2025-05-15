import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameSummaryScreen extends StatelessWidget {
  final String summaryMessage;
  final String gameId;
  final String playerId;
  final VoidCallback onLobbyPressed;
  final VoidCallback onReplayPressed;

  const GameSummaryScreen({
    super.key,
    required this.summaryMessage,
    required this.gameId,
    required this.playerId,
    required this.onLobbyPressed,
    required this.onReplayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.teal.shade50,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/beggarbg.png'), fit: BoxFit.cover),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events, color: Colors.orangeAccent, size: 50),
                  const SizedBox(height: 12),
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
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Text(
                        summaryMessage,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ClassicButton(
                        onPressed: onLobbyPressed,
                        label: 'Lobby',
                        icon: Icons.home,
                        color: Colors.blue,
                      ),
                      _ClassicButton(
                        onPressed: onReplayPressed,
                        label: 'Rematch',
                        icon: Icons.replay,
                        color: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassicButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final Color color;

  const _ClassicButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
    );
  }
}
