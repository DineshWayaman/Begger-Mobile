import 'dart:io';
import 'dart:ui';
import 'package:animated_emoji/animated_emoji.dart';
import 'package:animated_icon/animated_icon.dart';
import 'package:begger_card_game/widgets/about_game_bottomsheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_button.dart';
import '../widgets/terms_conditions_bottomsheet.dart';
import 'lobby.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _playerName = 'Player'; // Default name

  @override
  void initState() {
    super.initState();
    _loadName();
    _checkAndPromptForName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _playerName = prefs.getString('player_name') ?? 'Player';
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
    _nameController.text = initialName ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 12,
        backgroundColor: Colors.white.withOpacity(0.95),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
          initialName == null ? 'Enter Your Name' : 'Edit Your Name',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Colors.black87,

          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Your Name',
                counterText: '',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.person,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              maxLength: 9,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        actionsAlignment: MainAxisAlignment.end,
        actions: [

          TextButton(
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
                      borderRadius: BorderRadius.circular(8),
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
              backgroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Player Name with Edit Icon


                    Image.asset(
                      "assets/images/beggarlogo.png",
                      width: 300,
                      height: 300,
                    ),

                    // Buttons
                    Column(
                      spacing: 10,
                      children: [
                        AnimatedMenuButton(
                          label: 'Play',
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final playerName = prefs.getString('player_name') ?? 'Player';
                            Navigator.of(context).push(
                              createAnimatedRoute(LobbyScreen(playerName: playerName)),
                            );
                          },
                        ),

                        AnimatedMenuButton(
                          label: 'About Game',
                          onTap: () {
                            showAboutGameBottomSheet(context);
                          },
                        ),



                        AnimatedMenuButton(
                          label: 'Terms & Conditions',
                          onTap: () {
                            showTermsAndConditionsBottomSheet(context);
                          },
                        ),
                        AnimatedMenuButton(
                          label: 'Invite Friends',
                          onTap: () {
                            final String message =
                                "Join me in this amazing card game! Download it now!\nhttps://play.google.com/store/apps/details?id=com.beggar.cardgame";
                            Share.share(
                              message,
                              subject: "Check out this game!",
                            );
                          },
                        ),

                        AnimatedMenuButton(
                          label: 'Quit',
                          onTap: () {
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
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '©2025 Beggar Game. All rights reserved.',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                const SizedBox(width: 4),
                Text(
                  "Welcome $_playerName",
                  style:TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showNameDialog(initialName: _playerName),
                  child: AnimatedEmoji(
                    AnimatedEmojis.writingHand,
                    size: 25,


                  ),
                ),

              ],
            ),)
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

Route createAnimatedRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation);
      final fade = Tween<double>(begin: 0, end: 1).animate(animation);
      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: child,
        ),
      );
    },
  );
}