import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:begger_card_game/widgets/about_game_bottomsheet.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_button.dart';
import '../widgets/terms_conditions_bottomsheet.dart';
import 'lobby.dart';
import 'package:universal_html/html.dart' as html;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  String _playerName = 'BO${List.generate(4, (index) => String.fromCharCode((65 + Random().nextInt(26)))).join()}';
  late StreamSubscription<List<ConnectivityResult>> subscription;
  var isDeviceConnected = false;
  bool isAlertSet = false;
  late AnimationController _particleAnimationController;
  late Animation<double> _particleAnimation;
  late AnimationController _buttonAnimationController;
  late AnimationController _logoAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  List<Animation<Offset>> _buttonSlideAnimations = [];
  List<Animation<double>> _buttonFadeAnimations = [];
  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadName();
    _checkAndPromptForName();
    listenToConnectionChanges();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Particle animation
    _particleAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(_particleAnimationController);

    // Logo animation
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    ));

    _logoRotation = Tween<double>(
      begin: -0.2,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOutBack,
    ));

    // Button animations
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create staggered animations for 5 buttons
    for (int i = 0; i < 5; i++) {
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Interval(
          i * 0.1,
          0.5 + (i * 0.1),
          curve: Curves.easeOutBack,
        ),
      ));

      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Interval(
          i * 0.1,
          0.5 + (i * 0.1),
          curve: Curves.easeOut,
        ),
      ));

      _buttonSlideAnimations.add(slideAnimation);
      _buttonFadeAnimations.add(fadeAnimation);
    }

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logoAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 800), () {
        _buttonAnimationController.forward();
      });
    });

    _animationsInitialized = true;
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        return Stack(
          children: List.generate(6, (index) {
            final angle = (index * pi / 3) + _particleAnimation.value;
            final radius = 150.0 + (sin(_particleAnimation.value + index) * 30);
            final x = cos(angle) * radius;
            final y = sin(angle) * radius;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: MediaQuery.of(context).size.height / 2 + y,
              child: Container(
                width: 4 + (sin(_particleAnimation.value + index) * 2),
                height: 4 + (sin(_particleAnimation.value + index) * 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3 + sin(_particleAnimation.value + index) * 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.shade200.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerName = prefs.getString('player_name') ?? 'BO${List.generate(4, (index) => String.fromCharCode((65 + Random().nextInt(26)))).join()}';
    });
  }

  Future<void> _checkAndPromptForName() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString('player_name');

    if (storedName == null || storedName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNameDialog();
      });
    }
  }

  Future<void> _saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
    setState(() {
      _playerName = name;
    });
  }

  void _showNameDialog({String? initialName}) {
    _nameController.text = initialName ?? _playerName;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 20,
        backgroundColor: Colors.white.withOpacity(0.98),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
          initialName == null ? 'Enter Your Name' : 'Edit Your Name',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w900,
            fontSize: 26,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Your Name',
                  counterText: '',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: Colors.blue.shade600,
                      size: 22,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2.5),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLength: 10,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Container(
            width: double.infinity,
            height: 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade300.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Please enter a name (up to 9 characters)',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      backgroundColor: Colors.red.shade400,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                } else {
                  _saveName(name);
                  Navigator.of(context).pop();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _shareInviteWithImage() async {
    try {
      final String message =
          "Join me in this amazing card game! Download it now!\nhttps://play.google.com/store/apps/details?id=com.beggar.cardgame\nor Play online \nhttps://playbeggar.online";

      if (kIsWeb) {
        await Share.share(
          message,
          subject: "Check out this game!",
        );
      } else {
        final ByteData bytes = await rootBundle.load('assets/images/invite_card.png');
        final Uint8List imageBytes = bytes.buffer.asUint8List();

        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/beggar_invite.png').writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: message,
          subject: "Check out this game!",
        );
      }
    } catch (e) {
      print("Error sharing: $e");
    }
  }

  void listenToConnectionChanges() {
    subscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) async {
        isDeviceConnected = await InternetConnectionChecker.createInstance().hasConnection;
        if (!isDeviceConnected && !isAlertSet) {
          showCupertinoDialogBox();
          setState(() => isAlertSet = true);
        }
      },
    );
  }

  void showCupertinoDialogBox() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false,
          child: CupertinoAlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/internet.png',
                  height: 100,
                ),
                const Text(
                  'Oops!',
                  style: TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 25,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: const Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 18,
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context, 'Cancel');
                  setState(() => isAlertSet = false);

                  if (!mounted) return;

                  bool isDeviceConnected = await InternetConnectionChecker.createInstance().hasConnection;

                  if (!isDeviceConnected && !isAlertSet) {
                    showCupertinoDialogBox();
                    setState(() => isAlertSet = true);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedButton(int index, String label, VoidCallback onTap) {
    if (!_animationsInitialized || index >= _buttonSlideAnimations.length) {
      return AnimatedMenuButton(label: label, onTap: onTap);
    }

    return SlideTransition(
      position: _buttonSlideAnimations[index],
      child: FadeTransition(
        opacity: _buttonFadeAnimations[index],
        child: AnimatedMenuButton(label: label, onTap: onTap),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        showCupertinoDialog(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text("Exit Game"),
              content: const Text("Are you sure you want to exit the game?"),
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
                  child: const Text("Exit"),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else if (Platform.isIOS) {
                      exit(0);
                    }
                  },
                ),
              ],
            );
          },
        );
        return false;
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _playerName,
                    style: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showNameDialog(initialName: _playerName),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            // Background
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
            _buildFloatingParticles(),

            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Animated Logo
                    if (_animationsInitialized) ...[
                      AnimatedBuilder(
                        animation: _logoAnimationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Transform.rotate(
                              angle: _logoRotation.value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Blurred image for the glow effect
                                  ImageFiltered(
                                    imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Colors.lightBlueAccent,
                                        BlendMode.srcATop,
                                      ),
                                      child: Image.asset(
                                        "assets/images/beggarlogo.png",
                                        width: 310,
                                        height: 310,
                                      ),
                                    ),
                                  ),
                                  // Original image
                                  Image.asset(
                                    "assets/images/beggarlogo.png",
                                    width: 300,
                                    height: 300,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                Colors.lightBlueAccent,
                                BlendMode.srcATop,
                              ),
                              child: Image.asset(
                                "assets/images/beggarlogo.png",
                                width: 310,
                                height: 310,
                              ),
                            ),
                          ),
                          Image.asset(
                            "assets/images/beggarlogo.png",
                            width: 300,
                            height: 300,
                          ),
                        ],
                      ),
                    ],



                    // Animated Buttons
                    Column(
                      spacing: 10,
                      children: [
                        _buildAnimatedButton(
                          0,
                          'Play',
                              () async {
                            // Super smooth transition
                            final prefs = await SharedPreferences.getInstance();
                            final playerName = prefs.getString('player_name') ?? 'Player';

                            Navigator.of(context).push(
                              PageRouteBuilder(
                                transitionDuration: const Duration(milliseconds: 800),
                                reverseTransitionDuration: const Duration(milliseconds: 600),
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    LobbyScreen(playerName: playerName),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  // Curved animation
                                  final curvedAnimation = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOutCubic,
                                  );

                                  // Scale and fade transition
                                  final scaleAnimation = Tween<double>(
                                    begin: 0.8,
                                    end: 1.0,
                                  ).animate(curvedAnimation);

                                  final fadeAnimation = Tween<double>(
                                    begin: 0.0,
                                    end: 1.0,
                                  ).animate(curvedAnimation);

                                  // Slide from bottom
                                  final slideAnimation = Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(curvedAnimation);

                                  return SlideTransition(
                                    position: slideAnimation,
                                    child: ScaleTransition(
                                      scale: scaleAnimation,
                                      child: FadeTransition(
                                        opacity: fadeAnimation,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        _buildAnimatedButton(
                          1,
                          'About Game',
                              () {
                            showAboutGameBottomSheet(context);
                          },
                        ),
                        _buildAnimatedButton(
                          2,
                          'Terms & Conditions',
                              () {
                            showTermsAndConditionsBottomSheet(context);
                          },
                        ),
                        _buildAnimatedButton(
                          3,
                          'Invite Friends',
                              () {
                            _shareInviteWithImage();
                          },
                        ),
                        _buildAnimatedButton(
                          4,
                          'Quit',
                              () {
                            showCupertinoDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return CupertinoAlertDialog(
                                  title: const Text("Exit Game"),
                                  content: const Text("Are you sure you want to exit the game?"),
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
                                      child: const Text("Exit"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        if (Platform.isAndroid) {
                                          SystemNavigator.pop();
                                        } else if (Platform.isIOS) {
                                          exit(0);
                                        }
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Footer
            SafeArea(
              minimum: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text(
                  '©2025 Beggar Game. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: MediaQuery.of(context).size.width < 360 ? 13 : 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    subscription.cancel();
    _particleAnimationController.dispose();
    _buttonAnimationController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }
}