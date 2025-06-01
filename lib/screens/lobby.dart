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

  final List<String> _botNameOptions = [
    'Emma', 'Liam', 'Olivia', 'Noah',
    'Sophia', 'Jackson', 'Ava', 'Lucas',
    'Isabella', 'Ethan', 'Mia', 'Mason',
    'Amelia', 'Logan', 'Harper', 'James',
    'Elizabeth', 'Thomas', 'Victoria', 'Daniel',
    'Grace', 'Samuel', 'Lily', 'Matthew',
    'Emily', 'George', 'Ruby', 'Joseph'
  ];

  // autoplay mode: Add single-player mode toggle and bot settings
  bool isSinglePlayer = false;
  int botCount = 3; // Default to 3 bots (4 players total)
  late List<TextEditingController> botNameControllers;

  @override
  void initState() {
    super.initState();
    _playerNameController = TextEditingController(text: widget.playerName);
    _gameIdController.text = _generateGameId();
    
    // Initialize bot name controllers with real names
    _initBotNameControllers();

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

  void _initBotNameControllers() {
    // Shuffle the list of real names to get random selections
    final shuffledNames = List<String>.from(_botNameOptions)..shuffle();
    botNameControllers = List.generate(
      3,
      (i) => TextEditingController(text: shuffledNames[i]),
    );
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
                          elevation: 12,
                          shadowColor: Colors.blue.shade900.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(
                              color: isSinglePlayer 
                                ? Colors.amber.withOpacity(0.5) 
                                : Colors.blue.shade300.withOpacity(0.5),
                              width: 1.5,
                            ),
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
                                  // autoplay mode: Add mode toggle
                                  _buildModeToggle(isLargeScreen),
                                  Divider(
                                    color:isSinglePlayer
                                        ? Colors.amber.withOpacity(0.5)
                                        : Colors.blue.shade100,
                                    thickness: 1.5,
                                    height: isLargeScreen ? 48 : 40,
                                  ),
                                  _buildInputFields(isLargeScreen),
                                  // autoplay mode: Add bot settings for single-player
                                  if (isSinglePlayer) ..._buildBotSettings(isLargeScreen),
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

  // autoplay mode: Add mode toggle switch
  Widget _buildModeToggle(bool isLargeScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Multiplayer',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: !isSinglePlayer ? FontWeight.w600 : FontWeight.normal,
                      color: !isSinglePlayer ? Colors.blue.shade900 : Colors.grey,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _isHovered = true),
                    onExit: (_) => setState(() => _isHovered = false),
                    child: Switch(
                      value: isSinglePlayer,
                      onChanged: (value) {
                        setState(() {
                          isSinglePlayer = value;
                          if (isSinglePlayer) {
                            _gameIdController.text = _generateGameId();
                            // Shuffle names again when switching to single player
                            final shuffledNames = List<String>.from(_botNameOptions)..shuffle();
                            botNameControllers = List.generate(
                              botCount,
                              (i) => TextEditingController(text: shuffledNames[i]),
                            );
                          }
                        });
                      },
                      activeColor: Colors.amber.shade600,
                      activeTrackColor: Colors.amber.shade200,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    'Single Player',
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: isSinglePlayer ? FontWeight.w600 : FontWeight.normal,
                      color: isSinglePlayer ? Colors.amber.shade800 : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          )
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
                color: isSinglePlayer ? Colors.amber.shade800 : Colors.blue.shade900,
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
              color: isSinglePlayer ? Colors.amber.shade800 : Colors.blue.shade900,
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
          fillColor: isSinglePlayer ? Colors.amber.shade50 : Colors.blue.shade50,
        ),
        SizedBox(height: isLargeScreen ? 24 : 16),
        CustomTextField(
          controller: _gameIdController,
          hint: 'Game ID',
          fillColor: isSinglePlayer ? Colors.amber.shade50 : Colors.blue.shade50,
          // autoplay mode: Make game ID uneditable in single-player mode
          isReadOnly: isSinglePlayer,
          suffixIcon: !isSinglePlayer ? _buildCopyButton() : null,
        ),
        // autoplay mode: Hide instruction text in single-player mode
        if (!isSinglePlayer) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Copy this Game ID to share with friends or paste your friend's Game ID",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 14 : 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  // autoplay mode: Add bot settings UI
  List<Widget> _buildBotSettings(bool isLargeScreen) {
    return [
      SizedBox(height: isLargeScreen ? 24 : 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Opponents',
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: isLargeScreen ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Opponents: $botCount',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: isLargeScreen ? 16 : 14,
                    color: Colors.amber.shade900,
                  ),
                ),

                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove, color: Colors.amber.shade800),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: botCount > 2
                              ? () {
                                  setState(() {
                                    botCount--;
                                    botNameControllers.removeLast();
                                  });
                                }
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$botCount',
                            style: TextStyle(
                              fontFamily: "Poppins",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.amber.shade800),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: botCount < 5
                              ? () {
                                  setState(() {
                                    botCount++;
                                    // Get a name that's not already used
                                    final usedNames = botNameControllers
                                        .map((c) => c.text)
                                        .toList();
                                    String newName = _botNameOptions.firstWhere(
                                        (name) => !usedNames.contains(name),
                                        orElse: () => 'Player ${botCount + 1}');
                                    botNameControllers.add(
                                      TextEditingController(text: newName),
                                    );
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(botCount, (index) {
              return Padding(
                padding: EdgeInsets.only(top: isLargeScreen ? 12 : 8),
                child: CustomTextField(
                  controller: botNameControllers[index],
                  hint: 'Opponent ${index + 1} Name',
                  isReadOnly: true,
                  fillColor:Colors.amber.shade100,
                  // prefixIcon: Icon(Icons.person, color: Colors.amber.shade600),
                ),
              );
            }),
          ],
        ),
      ),
    ];
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
                    colors: isSinglePlayer 
                      ? [Colors.amber.shade500, Colors.orange.shade700]
                      : [Colors.blue.shade600, Colors.blue.shade900],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isSinglePlayer 
                        ? Colors.amber.shade200.withOpacity(0.5)
                        : Colors.blue.shade200.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 20 : 16),
                width: double.infinity,
                child: Center(
                  child: Text(
                    isSinglePlayer ? 'Start Game' : 'Join/Create Game',
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
    // autoplay mode: Handle single-player mode
    if (isSinglePlayer) {
      final botNames = botNameControllers.map((controller) => controller.text.trim().isEmpty ? 'Bot' : controller.text.trim()).toList();
      websocket.joinSinglePlayer(gameId, playerId, name, botNames);
      websocket.startGame(gameId, playerId); // Start game immediately
    } else {
      websocket.joinGame(gameId, playerId, name, isTestMode: isTestMode);
      websocket.requestGameState(gameId);
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameScreen(gameId: gameId, playerId: playerId, isSinglePlayer: isSinglePlayer),
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
    _playerNameController.dispose();
    // Dispose bot name controllers
    for (var controller in botNameControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
