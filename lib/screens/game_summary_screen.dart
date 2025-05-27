import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import '../services/websocket.dart';

class GameSummaryScreen extends StatefulWidget {
  final String summaryMessage;
  final String gameId;
  final String playerId;
  final VoidCallback onHomePressed;
  final VoidCallback onReplayPressed;

  const GameSummaryScreen({
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

class _GameSummaryScreenState extends State<GameSummaryScreen>
    with SingleTickerProviderStateMixin {
  final ScreenshotController screenshotController = ScreenshotController();
  final GlobalKey _screenshotKey = GlobalKey();
  bool _isRestartEnabled = true;
  bool _isLoading = false;
  bool _isHovered = false;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupWebSocketListeners();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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

    _animationController.forward();
  }

  void _setupWebSocketListeners() {
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.socket.on('playerLeft', (data) {
      if (mounted) {
        setState(() {
          _isRestartEnabled = false;
        });
        _showEnhancedSnackBar(
          message: 'A player has left the game',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        );
      }
    });
  }

  String _generateUniqueImageName() {
    return 'beggar_game_summary_${widget.playerId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<Uint8List?> _captureScreenshot() async {
    setState(() => _isLoading = true);

    try {
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await Future.delayed(const Duration(milliseconds: 200));
          final image = await screenshotController.capture();
          if (image != null) {
            return image;
          }
        } catch (e) {
          print('Screenshot attempt $attempt failed: $e');
        }
      }

      // Fallback to RenderRepaintBoundary
      final boundary = _screenshotKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      }
    } catch (e) {
      print('Screenshot capture error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
    return null;
  }

  Future<void> _captureAndSave(BuildContext context) async {
    try {
      final image = await _captureScreenshot();
      if (image == null) throw Exception('Failed to capture screenshot');

      if (kIsWeb) {
        final base64 = base64Encode(image);
        final dataUrl = 'data:image/png;base64,$base64';
        final anchor = html.AnchorElement(href: dataUrl)
          ..setAttribute('download', '${_generateUniqueImageName()}.png')
          ..click();

        _showEnhancedSnackBar(
          message: 'Image downloaded successfully!',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        );
      } else {
        final result = await ImageGallerySaverPlus.saveImage(
          image,
          quality: 100,
          name: _generateUniqueImageName(),
        );

        if (result['isSuccess']) {
          _showEnhancedSnackBar(
            message: 'Saved to Gallery!',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          );
        } else {
          throw Exception(result['error']);
        }
      }
    } catch (e) {
      _showEnhancedSnackBar(
        message: 'Failed to save image: $e',
        icon: Icons.error_outline,
        color: Colors.red,
        isError: true,
      );
    }
  }

  Future<void> _captureAndShare(BuildContext context) async {
    File? tempFile;
    try {
      final image = await _captureScreenshot();
      if (image == null) throw Exception('Failed to capture screenshot');

      final shareText =
          'Check out my game summary from the Beggar card game!\n\n${widget.summaryMessage}';
      final uniqueName = _generateUniqueImageName();

      if (kIsWeb) {
        final blob = html.Blob([image], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName = '$uniqueName.png';

        if (html.window.navigator.share != null) {
          await html.window.navigator.share({
            'title': 'Beggar Card Game Summary',
            'text': shareText,
            'files': [
              html.File([blob], fileName, {'type': 'image/png'}),
            ],
          });
          _showEnhancedSnackBar(
            message: 'Shared successfully!',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          );
        } else {
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
          _showEnhancedSnackBar(
            message: 'Image downloaded (Web Share not supported)',
            icon: Icons.info_outline,
            color: Colors.blue,
          );
        }
      } else {
        final directory = await getTemporaryDirectory();
        tempFile = File('${directory.path}/$uniqueName.png');
        await tempFile.writeAsBytes(image);

        final result = await Share.shareXFiles(
          [XFile(tempFile.path, mimeType: 'image/png')],
          text: shareText,
          subject: 'Beggar Card Game Summary',
        );

        if (result.status == ShareResultStatus.success) {
          _showEnhancedSnackBar(
            message: 'Shared successfully!',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          );
        } else if (result.status == ShareResultStatus.dismissed) {
          _showEnhancedSnackBar(
            message: 'Share canceled',
            icon: Icons.info_outline,
            color: Colors.blue,
          );
        } else {
          throw Exception('Share failed with status: ${result.status}');
        }
      }
    } catch (e) {
      _showEnhancedSnackBar(
        message: 'Failed to share image: $e',
        icon: Icons.error_outline,
        color: Colors.red,
        isError: true,
      );
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete().catchError((e) => print('Error deleting temp file: $e'));
      }
    }
  }

  void _showEnhancedSnackBar({
    required String message,
    required IconData icon,
    required Color color,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: isError ? 4 : 2),
        animation: CurvedAnimation(
          parent: ModalRoute.of(context)!.animation!,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  void _handleHomeWithConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildEnhancedDialog(
          title: 'Leave Game',
          content: 'Are you sure you want to return to the Home screen?',
          onConfirm: () {
            final ws = Provider.of<WebSocketService>(context, listen: false);
            ws.leaveGameFromSummary(widget.gameId, widget.playerId);
            widget.onHomePressed();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        );
      },
    );
  }

  void _showRestartDisabledPopup() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildEnhancedDialog(
          title: 'Cannot Restart Game',
          content: "Can't restart the game because someone left the game.",
          showCancel: false,
        );
      },
    );
  }

  Widget _buildEnhancedDialog({
    required String title,
    required String content,
    VoidCallback? onConfirm,
    bool showCancel = true,
  }) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return CupertinoAlertDialog(
      title: Text(
        title,
        style: TextStyle(
          fontFamily: "Poppins",
          fontSize: isLargeScreen ? 20 : 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          fontFamily: "Poppins",
          fontSize: isLargeScreen ? 16 : 14,
        ),
      ),
      actions: [
        if (showCancel)
          CupertinoDialogAction(
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.blue,
                fontSize: isLargeScreen ? 16 : 14,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        CupertinoDialogAction(
          isDestructiveAction: showCancel,
          child: Text(
            showCancel ? "Leave" : "OK",
            style: TextStyle(
              fontFamily: "Poppins",
              fontSize: isLargeScreen ? 16 : 14,
            ),
          ),
          onPressed: onConfirm ?? () => Navigator.pop(context),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _parseSummaryMessage(String message) {
    final List<Map<String, dynamic>> players = [];
    final List<String> civilianNames = [];

    for (var line in message.split('\n')) {
      final parts = line.split(': ');
      if (parts.length == 2) {
        final role = parts[1].trim();
        final name = parts[0].trim();
        if (role == 'Civilian') {
          civilianNames.add(name);
        } else {
          players.add({
            'role': role,
            'names': [name]
          });
        }
      }
    }

    if (civilianNames.isNotEmpty) {
      players.add({
        'role': civilianNames.length > 1 ? 'Civilians' : 'Civilian',
        'names': civilianNames
      });
    }

    const roleOrder = ['King', 'Wise', 'Civilian', 'Civilians', 'Beggar'];
    players.sort((a, b) {
      final aIndex = roleOrder.indexOf(a['role']);
      final bIndex = roleOrder.indexOf(b['role']);
      return aIndex.compareTo(bIndex);
    });

    return players;
  }

  @override
  Widget build(BuildContext context) {
    final players = _parseSummaryMessage(widget.summaryMessage);
    final screenSize = MediaQuery.of(context).size;
    final isLargeScreen = screenSize.width > 600;
    final containerWidth = isLargeScreen ? 500.0 : screenSize.width * 0.9;

    return WillPopScope(
      onWillPop: () async {
        bool? shouldPop = await showCupertinoDialog<bool>(
          context: context,
          builder: (BuildContext context) => _buildEnhancedDialog(
            title: 'Leave Game',
            content: 'Are you sure you want to return to the Home screen?',
            onConfirm: () => Navigator.pop(context, true),
          ),
        );

        if (shouldPop == true) {
          final ws = Provider.of<WebSocketService>(context, listen: false);
          ws.leaveGameFromSummary(widget.gameId, widget.playerId);
          widget.onHomePressed();
        }
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.teal.shade50,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/beggarbg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 16 :10,
                      vertical: isLargeScreen ? 32 : 16,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: containerWidth),
                            child: _buildMainContent(isLargeScreen, players),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isLargeScreen, List<Map<String, dynamic>> players) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 15 : 0,
        vertical: isLargeScreen ? 32 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildScreenshotContent(isLargeScreen, players),

          _buildActionButtons(isLargeScreen),
        ],
      ),
    );
  }

  Widget _buildScreenshotContent(bool isLargeScreen, List<Map<String, dynamic>> players) {
    return Screenshot(
      controller: screenshotController,
      child: RepaintBoundary(
        key: _screenshotKey,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: BoxConstraints(
            minWidth: 200,
            minHeight: 100,
            maxWidth: isLargeScreen ? 500 : 400,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height:10),
                Image.asset(
                  'assets/images/beggarlogo.png',
                  height: isLargeScreen ? 120 : 100,
                  width: isLargeScreen ? 120 : 100,
                ),
                Text(
                  'SUMMARY',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: isLargeScreen ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                ...players.map((player) => _buildPlayerItem(
                  role: player['role'],
                  names: player['names'],
                  isLargeScreen: isLargeScreen,
                )).toList(),
                const SizedBox(height: 5),
                Text(
                  'All rights reserved Beggar Online',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: isLargeScreen ? 14 : 12,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(height:10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerItem({
    required String role,
    required List<String> names,
    required bool isLargeScreen,
  }) {
    final roleColors = {
      'King': Colors.amber[700]!,
      'Wise': Colors.blue[700]!,
      'Civilian': Colors.grey[600]!,
      'Civilians': Colors.grey[600]!,
      'Beggar': Colors.brown[600]!,
    };
    final roleColor = roleColors[role] ?? Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.symmetric(
        vertical: isLargeScreen ? 12 : 10,
        horizontal: isLargeScreen ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: roleColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _getRoleIcon(role),
                color: roleColor,
                size: isLargeScreen ? 24 : 20,
              ),
              const SizedBox(width: 12),
              Text(
                role,
                style: TextStyle(
                  fontFamily: "Poppins",
                  fontSize: isLargeScreen ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              names.join(', '),
              style: TextStyle(
                fontFamily: "Poppins",
                fontSize: isLargeScreen ? 16 : 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'King':
        return Icons.star; // Alternative: Icons.star, Icons.account_balance
      case 'Wise':
        return Icons.lightbulb; // Alternative: Icons.lightbulb, Icons.book, Icons.school
      case 'Civilian':
      case 'Civilians':
        return Icons.people; // Alternative: Icons.group, Icons.person, Icons.home
      case 'Beggar':
        return Icons.person_outline; // Alternative: Icons.handshake, Icons.volunteer_activism, Icons.broken_image
      default:
        return Icons.person; // Alternative: Icons.question_mark, Icons.account_circle
    }
  }

  Widget _buildActionButtons(bool isLargeScreen) {
    return Wrap(
      spacing: isLargeScreen ? 16 : 12,
      runSpacing: isLargeScreen ? 16 : 12,
      alignment: WrapAlignment.center,
      children: [
        _buildEnhancedButton(
          onPressed: _handleHomeWithConfirmation,
          icon: Icons.home,
          color: Colors.blue,
          tooltip: 'Return Home',
          isLargeScreen: isLargeScreen,
        ),
        _buildEnhancedButton(
          onPressed: _isRestartEnabled
              ? widget.onReplayPressed
              : _showRestartDisabledPopup,
          icon: Icons.replay,
          color: _isRestartEnabled ? Colors.green : Colors.grey,
          tooltip: _isRestartEnabled ? 'Replay Game' : 'Replay Unavailable',
          isLargeScreen: isLargeScreen,
        ),
        _buildEnhancedButton(
          onPressed: () => _captureAndShare(context),
          icon: Icons.share,
          color: Colors.purple,
          tooltip: 'Share Summary',
          isLargeScreen: isLargeScreen,
        ),
        _buildEnhancedButton(
          onPressed: () => _captureAndSave(context),
          icon: Icons.save_alt,
          color: Colors.orange,
          tooltip: 'Save Summary',
          isLargeScreen: isLargeScreen,
        ),
      ],
    );
  }

  Widget _buildEnhancedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool isLargeScreen,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween<double>(
            begin: 1.0,
            end: _isHovered ? 1.05 : 1.0,
          ),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: isLargeScreen ? 60 : 60,
                height: isLargeScreen ? 60 : 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: _isHovered ? 12 : 8,
                      spreadRadius: _isHovered ? 2 : 1,
                      offset: Offset(0, _isHovered ? 4 : 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Icon(
                        icon,
                        size: isLargeScreen ? 28 : 24,
                        color: Colors.white,
                      ),
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

  Widget _buildLoadingOverlay() {
    return AnimatedOpacity(
      opacity: _isLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade900),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Processing...',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    final ws = Provider.of<WebSocketService>(context, listen: false);
    ws.socket.off('playerLeft');
    super.dispose();
  }
}