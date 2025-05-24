import 'dart:async';
import 'dart:io';
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

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _playerName = 'Player'; // Default name
  late StreamSubscription<List<ConnectivityResult>>
  subscription; // Update the type here
  var isDeviceConnected = false;
  bool isAlertSet = false;

  @override
  void initState() {
    super.initState();
    _loadName();
    _checkAndPromptForName();
    listenToConnectionChanges();
    // disableRightClick();
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
  void _shareInviteWithImage() async {
    try {
      // Share message
      final String message =
          "Join me in this amazing card game! Download it now!\nhttps://play.google.com/store/apps/details?id=com.beggar.cardgame\nor Play online \nhttps://playbeggar.online";

      if (kIsWeb) {
        // Web-specific sharing (text only)
        await Share.share(
          message,
          subject: "Check out this game!",
        );
      } else {
        // Mobile-specific sharing (text and image)
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
      // Handle the error (e.g., show a snackbar to the user)
    }
  }

  void listenToConnectionChanges() {
    subscription = Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) async {
        // Updated to handle List<ConnectivityResult>
        // Handle the first result (you can also handle other results if needed)
        isDeviceConnected =
        await InternetConnectionChecker.createInstance().hasConnection;
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

                  // Check if the widget is still mounted before calling setState
                  if (!mounted) return;

                  bool isDeviceConnected =
                  await InternetConnectionChecker.createInstance()
                      .hasConnection;

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
  //disable right click
  // void disableRightClick() {
  //   if (kIsWeb) {
  //     html.document.addEventListener('contextmenu', (event) {
  //       event.preventDefault();
  //     });
  //   }
  // }



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
        //Appbar with Welcome and editable Name
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: SizedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Welcome $_playerName",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,

                  ),
                ),
                const SizedBox(width: 4),
                AnimateIcon(
                  onTap:() => _showNameDialog(initialName: _playerName),
                  iconType: IconType.continueAnimation,
                  animateIcon: AnimateIcons.edit,
                  width: 25,
                  height: 25,
                  toolTip: "Edit Name",
                  color: Colors.white,
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

            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Player Name with Edit Icon


                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Blurred image for the glow effect
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0), // Adjust blur for glow intensity
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.lightBlueAccent, // Glow color and opacity
                              BlendMode.srcATop,
                            ),
                            child: Image.asset(
                              "assets/images/beggarlogo.png",
                              width: 310, // Slightly larger to show glow
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
                          onTap: (){
                            _shareInviteWithImage();
                          }
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