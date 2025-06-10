import 'dart:async';
import 'dart:io';
import 'dart:math';
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
import '../services/voice_chat_service.dart';
import '../widgets/animated_button.dart';
import '../widgets/enhanced_glow_widget.dart';
import '../widgets/floating_particles.dart';
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
  late AnimationController _buttonAnimationController;
  late AnimationController _logoAnimationController;
  late AnimationController _glowAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _glowAnimation;
  List<Animation<Offset>> _buttonSlideAnimations = [];
  List<Animation<double>> _buttonFadeAnimations = [];
  bool _animationsInitialized = false;
  VoiceChatService? _voiceChatService;

  @override
  void initState() {
    super.initState();
    _loadName();
    _checkAndPromptForName();
    listenToConnectionChanges();
    _initializeAnimations();
    _voiceChatService?.dispose();
  }

  void _initializeAnimations() {
    // Particle animation
    _particleAnimationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

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

    // Glow animation
    _glowAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _glowAnimationController,
      curve: Curves.easeInOut,
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
        if (mounted) {
          _buttonAnimationController.forward();
        }
      });
    });

    _animationsInitialized = true;
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerName = prefs.getString('player_name') ?? _playerName;
    });
  }

  Future<void> _checkAndPromptForName() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString('player_name');

    if (storedName == null || storedName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNameDialog();
        }
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
          "Join me in this amazing card game! Download it now!\nhttps://play.google.com/store/apps/details?id=com.globevik.beggar\nor Play online \nhttps://playbeggar.online";

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
                SizedBox(
                  height: 100,
                  child: AnimatedBuilder(
                    animation: AnimationController(
                      duration: const Duration(seconds: 2),
                      vsync: this,
                    )..repeat(),
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.wifi_slash,
                            size: 50,
                            color: CupertinoColors.systemRed,
                          ),
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                CupertinoColors.systemRed.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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

                  isDeviceConnected =
                  await InternetConnectionChecker.createInstance().hasConnection;

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

  Widget _buildPlayerNameSection(double maxWidth) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth * 0.8),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isLandscape = size.width > size.height;
    final isWebLarge = kIsWeb && size.width > 800;

    // Calculate responsive logo size
    final logoSize = isWebLarge
        ? size.height * 0.8
        : size.width * (isLandscape ? 0.8 : 0.8);
    final constrainedLogoSize = logoSize.clamp(150.0, 400.0);

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
        appBar: isWebLarge
            ? null // No AppBar on web for large screens
            : PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: SafeArea(
            child: AppBar(
              automaticallyImplyLeading: false,
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: _buildPlayerNameSection(size.width),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/images/beggarbg.png'),
                  fit: BoxFit.cover,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
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


            // Main content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final maxHeight = constraints.maxHeight;

                  if (isWebLarge) {
                    // Web layout: Logo on left, buttons and name on right
                    return Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo section
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: maxWidth * 0.05,
                                top: padding.top + 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _logoAnimationController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _logoScale.value,
                                        child: Transform.rotate(
                                          angle: _logoRotation.value,
                                          child: AnimatedBuilder(
                                            animation: _glowAnimation,
                                            builder: (context, child) {
                                              return EnhancedGlowWidget(
                                                glowOpacity: _glowAnimation.value,
                                                glowColors: [
                                                  Colors.blue.withOpacity(0.8),
                                                  Colors.lightBlueAccent.withOpacity(0.6),
                                                  Colors.white.withOpacity(0.4),
                                                ],
                                                glowSpread: 25.0,
                                                child: Image.asset(
                                                  "assets/images/beggarlogo.png",
                                                  width: constrainedLogoSize,
                                                  height: constrainedLogoSize,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Buttons and name section
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal: maxWidth * 0.05,
                                vertical: padding.top + 20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // Buttons
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: 400),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Player name section
                                        _buildPlayerNameSection(maxWidth),
                                        SizedBox(height: maxHeight * 0.05),
                                        _buildAnimatedButton(
                                          0,
                                          'Play',
                                              () async {
                                            final prefs = await SharedPreferences.getInstance();
                                            final playerName = prefs.getString('player_name') ?? 'Player';
                                            Navigator.of(context).push(
                                              PageRouteBuilder(
                                                transitionDuration: const Duration(milliseconds: 800),
                                                reverseTransitionDuration: const Duration(milliseconds: 600),
                                                pageBuilder: (context, animation, secondaryAnimation) =>
                                                    LobbyScreen(playerName: playerName),
                                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                  final curvedAnimation = CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeInOutCubic,
                                                  );
                                                  return SlideTransition(
                                                    position: Tween<Offset>(
                                                      begin: const Offset(0, 0.3),
                                                      end: Offset.zero,
                                                    ).animate(curvedAnimation),
                                                    child: ScaleTransition(
                                                      scale: Tween<double>(
                                                        begin: 0.8,
                                                        end: 1.0,
                                                      ).animate(curvedAnimation),
                                                      child: FadeTransition(
                                                        opacity: curvedAnimation,
                                                        child: child,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildAnimatedButton(
                                          1,
                                          'About Game',
                                              () {
                                            showAboutGameBottomSheet(context);
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildAnimatedButton(
                                          2,
                                          'Terms & Conditions',
                                              () {
                                            showTermsAndConditionsBottomSheet(context);
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildAnimatedButton(
                                          3,
                                          'Invite Friends',
                                              () {
                                            _shareInviteWithImage();
                                          },
                                        ),
                                        const SizedBox(height: 16),
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
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Mobile/Tablet layout: Logo on top, buttons below, name in AppBar or top
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: maxWidth * 0.05,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo section
                            AnimatedBuilder(
                              animation: _logoAnimationController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _logoScale.value,
                                  child: Transform.rotate(
                                    angle: _logoRotation.value,
                                    child: AnimatedBuilder(
                                      animation: _glowAnimation,
                                      builder: (context, child) {
                                        return EnhancedGlowWidget(
                                          glowOpacity: _glowAnimation.value,
                                          glowColors: [
                                            Colors.blue.withOpacity(0.8),
                                            Colors.lightBlueAccent.withOpacity(0.6),
                                            Colors.white.withOpacity(0.4),
                                          ],
                                          glowSpread: 25.0,
                                          child: Image.asset(
                                            "assets/images/beggarlogo.png",
                                            width: constrainedLogoSize,
                                            height: constrainedLogoSize,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            // SizedBox(height: maxHeight * 0.05),
                            // Buttons
                            LayoutBuilder(
                              builder: (context, buttonConstraints) {
                                final buttonWidth = isLandscape
                                    ? buttonConstraints.maxWidth * 0.45
                                    : buttonConstraints.maxWidth * 0.9;
                                return Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: buttonWidth.clamp(200.0, 400.0),
                                      child: Column(
                                        spacing: 10,
                                        children: [
                                          _buildAnimatedButton(
                                            0,
                                            'Play',
                                                () async {
                                              final prefs = await SharedPreferences.getInstance();
                                              final playerName = prefs.getString('player_name') ?? 'Player';
                                              Navigator.of(context).push(
                                                PageRouteBuilder(
                                                  transitionDuration: const Duration(milliseconds: 800),
                                                  reverseTransitionDuration: const Duration(milliseconds: 600),
                                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                                      LobbyScreen(playerName: playerName),
                                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                    final curvedAnimation = CurvedAnimation(
                                                      parent: animation,
                                                      curve: Curves.easeInOutCubic,
                                                    );
                                                    return SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(0, 0.3),
                                                        end: Offset.zero,
                                                      ).animate(curvedAnimation),
                                                      child: ScaleTransition(
                                                        scale: Tween<double>(
                                                          begin: 0.8,
                                                          end: 1.0,
                                                        ).animate(curvedAnimation),
                                                        child: FadeTransition(
                                                          opacity: curvedAnimation,
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
                                          SizedBox(height: 40,),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

            // Footer
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: padding.bottom + 16,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
                child: Text(
                  '©2025 Beggar Game. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: size.width < 360 ? 12 : 14,
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
    _glowAnimationController.dispose();
    super.dispose();
  }
}