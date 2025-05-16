import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/animated_button.dart';
import 'lobby.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                children: [
                  // Text(
                  //   'Beggar Game',
                  //   textAlign: TextAlign.center,
                  //   style: GoogleFonts.bungee(
                  //     color: Colors.white,
                  //     fontSize: 46,
                  //     letterSpacing: 1.5,
                  //     shadows: [
                  //       Shadow(
                  //         color: Colors.blueAccent.withOpacity(0.9),
                  //         blurRadius: 20,
                  //         offset: const Offset(0, 4),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  Image.asset("assets/images/beggarlogo.png", width: 280, height: 280),


                  // Buttons
                  Column(
                    spacing: 10,
                    children: [
                      AnimatedMenuButton(
                        label: 'Play',
                        onTap: () {
                          Navigator.of(context).push(createAnimatedRoute(const LobbyScreen()));
                        },
                      ),

                      AnimatedMenuButton(
                        label: 'About Game',
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierColor: Colors.transparent,
                            builder: (context) => GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  children: [
                                    BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ),
                                    Center(
                                      child: GestureDetector(
                                        onTap: () {},
                                        child: SizedBox(
                                          height: 460,
                                          width: 310,
                                          child: Image.asset("assets/cards/info_card.png"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      AnimatedMenuButton(
                        label: 'Credits',
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierColor: Colors.transparent,
                            builder: (context) => GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  children: [
                                    BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ),
                                    Center(
                                      child: GestureDetector(
                                        onTap: () {},
                                        child: SizedBox(
                                          height: 460,
                                          width: 310,
                                          child: Image.asset("assets/cards/info_card.png"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      AnimatedMenuButton(
                        label: 'Terms & Conditions',
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierColor: Colors.transparent,
                            builder: (context) => GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  children: [
                                    BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ),
                                    Center(
                                      child: GestureDetector(
                                        onTap: () {},
                                        child: SizedBox(
                                          height: 460,
                                          width: 310,
                                          child: Image.asset("assets/cards/info_card.png"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                                    child: const Text("Cancel",style: TextStyle(
                                      color: Colors.blueAccent,
                                    ),),
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
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
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


        ],
      ),
    );
  }
}
Route createAnimatedRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 500),
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
