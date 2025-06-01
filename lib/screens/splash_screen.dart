import 'dart:math';
import 'package:begger_card_game/screens/home_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _progressController; // Separate controller for progress
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  final List<String> _cardSuits = [
    '♠️', '♥️', '♦️', '♣️',
    '🃏', '🂿', '🂱', '🂮',
  ];

  final List<Map<String, dynamic>> _floatingElements = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Initialize floating elements
    for (int i = 0; i < 20; i++) {
      _floatingElements.add({
        'icon': _cardSuits[_random.nextInt(_cardSuits.length)],
        'position': Offset(
          _random.nextDouble() * 400 - 200,
          _random.nextDouble() * 800 - 400,
        ),
        'size': _random.nextDouble() * 20 + 10,
        'speed': _random.nextDouble() * 2 + 1,
        'opacity': _random.nextDouble() * 0.4 + 0.1,
        'angle': _random.nextDouble() * 2 * pi,
      });
    }

    // Main animation controller for most animations
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Separate controller for progress animation (no reverse)
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.elasticOut),
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOut),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.linear,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      }),
    );

    // Start both controllers
    _controller.forward();
    _progressController.forward();

    // Navigate to home screen after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 800; // Threshold for large screens

    return Scaffold(
      backgroundColor: const Color(0xFF0A1D37),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/beggarbg.png'),
            fit: BoxFit.cover,
            opacity: 0.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A1D37),
              Color(0xFF1F3A60),
            ],
          ),
        ),
        child: Stack(
          children: [
            ..._buildFloatingElements(),

            // Responsive layout for center content
            Center(
              child: isLargeScreen 
                ? _buildLargeScreenLayout(size) 
                : _buildMobileLayout(size),
            ),

            // Version and copyright - anchored at bottom center for all screen sizes
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "v1.0.0",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      height: 4,
                      width: 4,
                      margin: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text(
                      "© Beggar Online 2025",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget for mobile layout (vertical stack)
  Widget _buildMobileLayout(Size size) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoWithAnimations(size),
        
        FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              "Card Game Legacy Meets Modern Fun",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        const SizedBox(height: 50),

        _buildProgressBar(size.width * 0.7),
      ],
    );
  }

  // Widget for large screen layout (logo left, content right)
  Widget _buildLargeScreenLayout(Size size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo section on left
        SizedBox(
          width: size.width * 0.45,
          child: _buildLogoWithAnimations(size),
        ),
        
        // Right content section
        SizedBox(
          width: size.width * 0.45,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.5, 0.8, curve: Curves.easeIn),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    "Card Game Legacy Meets Modern Fun",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 50),

              _buildProgressBar(size.width * 0.35),
            ],
          ),
        ),
      ],
    );
  }

  // Logo with animations - extracted from original code
  Widget _buildLogoWithAnimations(Size size) {
    double logoSize = size.width > 800 ? size.width * 0.3 : size.width * 0.8;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: logoSize * 0.75,
              height: logoSize * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3 * _fadeAnimation.value),
                    blurRadius: 30 * _fadeAnimation.value,
                    spreadRadius: 10 * _fadeAnimation.value,
                  ),
                ],
              ),
            ),

            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_rotateAnimation.value)
                ..rotateX(_rotateAnimation.value * 0.5),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/beggarlogo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            ..._buildCardSuitDecorations(logoSize * 0.5),
          ],
        );
      },
    );
  }

  // Progress bar - extracted from original code and made responsive
  Widget _buildProgressBar(double width) {
    return SizedBox(
      width: width,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Column(
            children: [
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24, width: 0.5),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: width * _progressAnimation.value,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.blue.shade300, Colors.blue.shade100],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Shuffling Cards",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${(_progressAnimation.value * 100).toInt()}%",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildFloatingElements() {
    return _floatingElements.map((element) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final dy = element['position'].dy + (element['speed'] * progress * 100);
          final newPosition = Offset(element['position'].dx, dy);

          return Positioned(
            left: MediaQuery.of(context).size.width / 2 + newPosition.dx,
            top: MediaQuery.of(context).size.height / 2 + newPosition.dy,
            child: Transform.rotate(
              angle: element['angle'] + (progress * pi * element['speed'] / 2),
              child: Opacity(
                opacity: element['opacity'] * _fadeAnimation.value,
                child: Text(
                  element['icon'],
                  style: TextStyle(
                    fontSize: element['size'],
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildCardSuitDecorations(double radius) {
    final List<Widget> decorations = [];
    final int count = 4;

    for (int i = 0; i < count; i++) {
      final double angle = (i * 2 * pi / count);
      final double x = radius * cos(angle);
      final double y = radius * sin(angle);

      decorations.add(
        Transform.translate(
          offset: Offset(x, y),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 0.8).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(0.3 + (i * 0.1), 0.7 + (i * 0.1), curve: Curves.easeOut),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.rotate(
                  angle: angle + (_controller.value * pi / 4),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white10,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _cardSuits[i],
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return decorations;
  }
}
