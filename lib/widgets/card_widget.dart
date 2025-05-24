import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/card.dart';

class CardWidget extends StatelessWidget {
  final Cards? card;
  final VoidCallback? onTap;
  final bool isSelected;
  final double? cardWidth;
  final double? cardHeight;

  const CardWidget({super.key,
    required this.card,
    this.onTap,
    this.isSelected = false,
    this.cardWidth,
    this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return const SizedBox(); // Handle null case gracefully
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.black,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Image.asset(
                card!.getAssetPath(),
                fit: BoxFit.cover,
                width: cardWidth,
                height: cardHeight,
                errorBuilder: (context, error, stackTrace) {
                  // Null Check Fix: Handle asset errors
                  print('CardWidget: Image error for ${card!.getAssetPath()}: $error');
                  return const Center(child: Text('X', style: TextStyle(color: Colors.red)));
                },

              ),
              if (isSelected)
                Container(
                  color: Colors.blue.withOpacity(0.3),
                  child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 30),
                  ),
                ),
            ],
          ),
        ),

      ),
    );
  }
}