import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/websocket.dart';

class GameSummaryScreen extends StatefulWidget {
  final String summaryMessage;
  final String gameId;
  final String playerId;
  final VoidCallback onHomePressed;
  final VoidCallback onReplayPressed;

  GameSummaryScreen({
    super.key,
    required this.summaryMessage,
    required this.gameId,
    required this.playerId,
    required this.onHomePressed,
    required this.onReplayPressed,
  });

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  final GlobalKey _screenshotKey = GlobalKey();
  bool _isRestartEnabled = true;

  String _generateUniqueImageName() {
    return 'game_summary_${widget.gameId}_${widget.playerId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void initState() {
    super.initState();
    // Home leave update: Listen for playerLeft event to disable restart button
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.socket.on('playerLeft', (data) {
      print('Received playerLeft event: $data'); // Debug log
      if (mounted) {
        setState(() {
          _isRestartEnabled = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Home leave update: Clean up socket listener
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.socket.off('playerLeft');
    super.dispose();
  }

  Future<Uint8List?> _captureScreenshot() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        final RenderBox? renderBox = _screenshotKey.currentContext?.findRenderObject() as RenderBox?;
        print('Attempt $attempt: Screenshot size: ${renderBox?.size}');
        if (renderBox == null || renderBox.size.isEmpty) {
          print('Attempt $attempt: Invalid widget size');
          continue;
        }
        final Uint8List? image = await screenshotController.capture();
        if (image != null) {
          print('Attempt $attempt: Screenshot captured successfully');
          return image;
        }
        print('Attempt $attempt: Screenshot capture returned null');
      } catch (e) {
        print('Attempt $attempt: Screenshot capture error: $e');
      }
    }
    print('Falling back to RenderRepaintBoundary capture');
    try {
      final RenderRepaintBoundary? boundary = _screenshotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Failed to find RenderRepaintBoundary');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }
      final Uint8List imageBytes = byteData.buffer.asUint8List();
      print('Fallback capture successful');
      return imageBytes;
    } catch (e) {
      print('Fallback capture error: $e');
      throw Exception('Failed to capture screenshot after fallback: $e');
    }
  }

  Future<void> _captureAndSave(BuildContext context) async {
    try {
      final Uint8List? image = await _captureScreenshot();
      if (image == null) {
        throw Exception('Failed to capture screenshot');
      }
      final result = await ImageGallerySaverPlus.saveImage(
        image,
        quality: 100,
        name: _generateUniqueImageName(),
      );
      if (result['isSuccess']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Gallery!')),
        );
      } else {
        throw Exception('Failed to save image: ${result['error']}');
      }
    } catch (e) {
      print('Error saving image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
    }
  }

  Future<void> _captureAndShare(BuildContext context) async {
    File? imagePath;
    try {
      final Uint8List? image = await _captureScreenshot();
      if (image == null) {
        throw Exception('Failed to capture screenshot');
      }
      final directory = await getTemporaryDirectory();
      final uniqueName = _generateUniqueImageName();
      imagePath = File('${directory.path}/$uniqueName.png');
      await imagePath.writeAsBytes(image);
      final shareText = 'Check out my game summary from the Beggar card game!\n\n${widget.summaryMessage}';
      final result = await Share.shareXFiles(
        [XFile(imagePath.path, mimeType: 'image/png')],
        text: shareText,
        subject: 'Beggar Card Game Summary',
      );
      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared successfully!')),
        );
      } else if (result.status == ShareResultStatus.dismissed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share canceled')),
        );
      } else {
        throw Exception('Share failed with status: ${result.status}');
      }
    } catch (e) {
      print('Error sharing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share image: $e')),
      );
    } finally {
      if (imagePath != null && await imagePath.exists()) {
        try {
          await imagePath.delete();
          print('Temporary file deleted: ${imagePath.path}');
        } catch (e) {
          print('Error deleting temporary file: $e');
        }
      }
    }
  }

  // Home leave update: Handle Home button with confirmation
  void _handleHomeWithConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("Leave Game"),
          content: const Text("Are you sure you want to return to the Home screen?"),
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
              child: const Text("Leave"),
              onPressed: () {
                final ws = Provider.of<WebSocketService>(context, listen: false);
                ws.leaveGameFromSummary(widget.gameId, widget.playerId); // Home leave update: Use new method
                widget.onHomePressed();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  // Parse summary message and group civilians
  List<Map<String, dynamic>> _parseSummaryMessage(String message) {
    final List<Map<String, dynamic>> players = [];
    final List<String> civilianNames = [];
    final lines = message.split('\n');
    for (var line in lines) {
      final parts = line.split(': ');
      if (parts.length == 2) {
        final role = parts[1].trim();
        final name = parts[0].trim();
        if (role == 'Civilian') {
          civilianNames.add(name);
        } else {
          players.add({'role': role, 'names': [name]});
        }
      }
    }
    if (civilianNames.isNotEmpty) {
      players.add({'role': civilianNames.length > 1 ? 'Civilians' : 'Civilian', 'names': civilianNames});
    }
    const roleOrder = ['King', 'Wise', 'Civilian', 'Civilians', 'Beggar'];
    players.sort((a, b) {
      final aIndex = roleOrder.indexOf(a['role']);
      final bIndex = roleOrder.indexOf(b['role']);
      return aIndex.compareTo(bIndex);
    });
    return players;
  }
  // New method to show popup when Restart is attempted after someone leaves
  void _showRestartDisabledPopup() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text("Cannot Restart Game"),
          content: const Text("Can't restart the game because someone left the game."),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final players = _parseSummaryMessage(widget.summaryMessage);

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog before allowing back navigation
        bool? shouldPop = await showCupertinoDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return CupertinoAlertDialog(
              title: const Text("Leave Game"),
              content: const Text("Are you sure you want to return to the Home screen?"),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.blueAccent,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(false); // Return false to prevent pop
                  },
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text("Leave"),
                  onPressed: () {
                    Navigator.of(context).pop(true); // Return true to allow pop
                  },
                ),
              ],
            );
          },
        );

        // If the user confirms, perform the leave game logic
        if (shouldPop == true) {
          final ws = Provider.of<WebSocketService>(context, listen: false);
          ws.leaveGameFromSummary(widget.gameId, widget.playerId); // Notify WebSocket
          widget.onHomePressed(); // Trigger home callback
          return true; // Allow navigation
        }
        return false; // Prevent navigation if canceled
      },
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/beggarbg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.only(left: 16, right: 16,bottom: 24),
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
                    Screenshot(
                      controller: screenshotController,
                      child: RepaintBoundary(
                        key: _screenshotKey,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),

                          ),
                          constraints: const BoxConstraints(
                            minWidth: 200,
                            minHeight: 100,
                            maxWidth: double.infinity,
                          ),

                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              //game logo
                              Image.asset(
                                'assets/images/beggarlogo.png',
                                height: 100,
                                width: 100,
                              ),

                              const Text(
                                'SUMMARY',
                                style: TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              // Beautiful list of players
                              ListView.separated(
                                shrinkWrap: true,
                                physics:  const NeverScrollableScrollPhysics(),
                                itemCount: players.length,
                                separatorBuilder: (context, index) => const Divider(
                                  color: Colors.grey,
                                  thickness: 0.5,
                                  height: 8,
                                ),
                                itemBuilder: (context, index) {
                                  final player = players[index];
                                  final role = player['role'] as String;
                                  final names = player['names'] as List<String>;
                                  final roleColor = {
                                    'King': Colors.amber[700],
                                    'Wise': Colors.blue[700],
                                    'Civilian': Colors.grey[600],
                                    'Civilians': Colors.grey[600],
                                    'Beggar': Colors.brown[600],
                                  }[role] ?? Colors.black87;

                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          role,
                                          style: TextStyle(
                                            fontFamily: "Poppins",
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: roleColor,
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            names.join(', '),
                                            style: const TextStyle(
                                              fontFamily: "Poppins",
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black54,
                                            ),
                                            textAlign: TextAlign.right,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),


                              const SizedBox(height: 5),
                              // All rights reserved Beggar
                              const Text(
                                'All rights reserved Beggar Online',
                                style: TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),

                            ],
                          ),
                        ),
                      ),
                    ),

                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _ClassicButton(
                          onPressed: _handleHomeWithConfirmation,
                          icon: Icons.home,
                          color: Colors.blue,
                        ),
                        _ClassicButton(
                          onPressed: _isRestartEnabled
                              ? widget.onReplayPressed
                              : () => _showRestartDisabledPopup(), // Show popup when disabled
                          icon: Icons.replay,
                          color: _isRestartEnabled ? Colors.green : Colors.grey, // Grey out when disabled
                        ),
                        _ClassicButton(
                          onPressed: () => _captureAndShare(context),
                          icon: Icons.share,
                          color: Colors.purple,
                        ),
                        _ClassicButton(
                          onPressed: () => _captureAndSave(context),
                          icon: Icons.save_alt,
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
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
  final IconData icon;
  final Color color;

  const _ClassicButton({
    required this.onPressed,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          minimumSize: const Size(48, 48),
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }
}