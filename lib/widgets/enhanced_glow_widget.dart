import 'package:flutter/material.dart';

class EnhancedGlowWidget extends StatelessWidget {
  final Widget child;
  final double glowOpacity;
  final List<Color> glowColors;
  final double glowSpread;

  const EnhancedGlowWidget({
    Key? key,
    required this.child,
    this.glowOpacity = 0.5,
    this.glowColors = const [Colors.blue, Colors.lightBlueAccent],
    this.glowSpread = 20.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow layers
        ...List.generate(glowColors.length, (index) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColors[index].withOpacity(glowOpacity / (index + 1)),
                  blurRadius: glowSpread * (index + 1),
                  spreadRadius: glowSpread * 0.5 * (index + 1),
                ),
              ],
            ),
            child: child,
          );
        }),
      ],
    );
  }
}