import 'dart:io';
import 'dart:math';
import 'package:begger_card_game/widgets/floating_particles.dart';
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

class _LobbyScreenState extends State<LobbyScreen> with SingleTickerProviderStateMixin {
  final _gameIdController = TextEditingController();
  late final TextEditingController _playerNameController;
  bool isTestMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _playerNameController = TextEditingController(text: widget.playerName);
    _gameIdController.text = _generateGameId();

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    // Start the animation
    _animationController.forward();
  }

  String _generateGameId() {
    const uuid = Uuid();
    return uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
  }

  void _copyGameId() {
    Clipboard.setData(ClipboardData(text: _gameIdController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'Game ID copied to clipboard',
              style: const TextStyle(fontFamily: "Poppins"),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade400,
        duration: const Duration(seconds: 2),
        animation: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final websocket = Provider.of<WebSocketService>(context, listen: false);
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 600;
    final cardWidth = isLargeScreen ? 500.0 : screenSize.width * 0.9;

    return Scaffold(
      body: Stack(
        children: [
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/beggarbg.png'),
                fit: BoxFit.cover,
              ),
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 16 : 24,
                  vertical: isLargeScreen ? 32 : 16,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 200),
                            tween: Tween<double>(
                              begin: 1.0,
                              end: _isHovered ? 1.02 : 1.0,
                            ),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: child,
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isLargeScreen ? 32 : 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeader(isLargeScreen),
                                  SizedBox(height: isLargeScreen ? 32 : 24),
                                  _buildInputFields(isLargeScreen),
                                  SizedBox(height: isLargeScreen ? 32 : 24),
                                  _buildJoinButton(isLargeScreen, websocket),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isLargeScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildBackButton(isLargeScreen),
        const SizedBox(width: 8),
        _buildTitle(isLargeScreen),
      ],
    );
  }

  Widget _buildBackButton(bool isLargeScreen) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween<double>(begin: 1.0, end: _isHovered ? 1.1 : 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.blue.shade900,
                size: isLargeScreen ? 48 : 40,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(bool isLargeScreen) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween<double>(begin: 0.8, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Text(
            'Beggar',
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: isLargeScreen ? 56 : 48,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputFields(bool isLargeScreen) {
    return Column(
      children: [
        CustomTextField(
          controller: _playerNameController,
          hint: 'Your Name',
          isReadOnly: true,
        ),
        SizedBox(height: isLargeScreen ? 24 : 16),
        CustomTextField(
          controller: _gameIdController,
          hint: 'Game ID',
          isReadOnly: false,
          suffixIcon: _buildCopyButton(),
        ),
        const SizedBox(height: 8),
        Text(
          "Copy this Game ID and share it with your friends or Paste your friend's Game ID",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildCopyButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween<double>(begin: 1.0, end: _isHovered ? 1.1 : 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: IconButton(
              icon: Icon(Icons.copy, color: Colors.blue.shade900),
              onPressed: _copyGameId,
            ),
          );
        },
      ),
    );
  }

  Widget _buildJoinButton(bool isLargeScreen, WebSocketService websocket) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _handleJoinGame(websocket),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween<double>(begin: 1.0, end: _isHovered ? 1.05 : 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
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
                padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 20 : 16),
                width: double.infinity,
                child: Center(
                  child: Text(
                    'Join/Create Game',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: isLargeScreen ? 20 : 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleJoinGame(WebSocketService websocket) {
    final name = _playerNameController.text.trim().isEmpty
        ? 'Player'
        : _playerNameController.text.trim();
    final gameId = _gameIdController.text.trim();

    if (name.length > 20) {
      _showErrorSnackbar('Name must be 20 characters or less');
      return;
    }

    final playerId = '$gameId-$name';
    websocket.joinGame(gameId, playerId, name, isTestMode: isTestMode);
    websocket.requestGameState(gameId);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameScreen(gameId: gameId, playerId: playerId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              message,
              style: const TextStyle(fontFamily: "Poppins"),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 2),
        animation: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gameIdController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}