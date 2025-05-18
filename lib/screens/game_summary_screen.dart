import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class GameSummaryScreen extends StatelessWidget {
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

  final ScreenshotController screenshotController = ScreenshotController();
  final GlobalKey _screenshotKey = GlobalKey();

  String _generateUniqueImageName() {
    return 'game_summary_${gameId}_${playerId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<Uint8List?> _captureScreenshot() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Wait for the frame to be rendered
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify widget size
        final RenderBox? renderBox = _screenshotKey.currentContext?.findRenderObject() as RenderBox?;
        print('Attempt $attempt: Screenshot size: ${renderBox?.size}');
        if (renderBox == null || renderBox.size.isEmpty) {
          print('Attempt $attempt: Invalid widget size');
          continue;
        }

        // Try primary screenshot method
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

    // Fallback to RenderRepaintBoundary
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

      // Share both image and text
      final shareText = 'Check out my game summary from the Beggar card game!\n\n$summaryMessage';
      final result = await Share.shareXFiles(
        [XFile(imagePath.path, mimeType: 'image/png')],
        text: shareText,
        subject: 'Beggar Card Game Summary', // Optional subject for emails
      );

      // Check share result
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
      // Clean up temporary file
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  // Screenshot only this part (excluding buttons)
                  Screenshot(
                    controller: screenshotController,
                    child: RepaintBoundary(
                      key: _screenshotKey,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 200,
                          minHeight: 100,
                          maxWidth: double.infinity,
                        ),
                        color: Colors.white, // Ensure solid background
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.orangeAccent, size: 50),
                            const SizedBox(height: 12),
                            const Text(
                              'Game Summary',
                              style: TextStyle(
                                fontFamily: "Poppins",
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // Replaced SingleChildScrollView with fixed-height Text
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: Text(
                                summaryMessage,
                                style: const TextStyle(
                                  fontFamily: "Poppins",
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 8, // Adjust based on your needs
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Buttons outside screenshot
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _ClassicButton(
                        onPressed: onHomePressed,
                        icon: Icons.home,
                        color: Colors.blue,
                      ),
                      _ClassicButton(
                        onPressed: onReplayPressed,
                        icon: Icons.replay,
                        color: Colors.green,
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
      width: 60, // Reduced width for icon-only buttons
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.all(12), // Square padding for icon
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          minimumSize: const Size(48, 48), // Square button
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }
}