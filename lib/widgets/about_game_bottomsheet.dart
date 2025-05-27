import 'package:flutter/material.dart';

void showAboutGameBottomSheet(BuildContext context) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'About Beggar',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Material(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(thickness: 1.2, height: 32),

            // Scrollable content
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                radius: const Radius.circular(4),
                thickness: 6,
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEnhancedSection('Overview', Icons.info_outline),
                        _buildEnhancedParagraph(
                          'Beggar is a fun and strategic card game for 3 or more players. The goal is to be the first to play all your cards to become the "King," while avoiding being the last player, known as the "Beggar."',
                        ),

                        _buildEnhancedSection('Requirements', Icons.check_circle_outline),
                        _buildEnhancedBulletPoint('Minimum of 3 players.'),
                        _buildEnhancedBulletPoint('Standard card deck with 2 jokers and a details card.'),

                        _buildEnhancedSection('Serving', Icons.send),
                        _buildEnhancedBulletPoint('Cards are dealt in clockwise order.'),
                        _buildEnhancedBulletPoint('Each player receives one card per round.'),

                        _buildEnhancedSection('Card Values (Ascending)', Icons.filter_list),
                        _buildEnhancedBulletPoint('3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, A, 2, Details Card (Rank 1).'),
                        _buildEnhancedBulletPoint('Joker: Can represent any card (except Details Card) of any suit.'),
                        _buildEnhancedBulletPoint('Suits are irrelevant except for specific patterns.'),

                        _buildEnhancedSection('Card Patterns', Icons.grid_view),
                        _buildEnhancedSubSection('1. Singles'),
                        _buildEnhancedBulletPoint('Play any single card. Others must play a higher value single.'),
                        _buildEnhancedSubSection('2. Consecutive'),
                        _buildEnhancedBulletPoint('2–A consecutive cards (e.g., 3, 4, 5, 6,..., J, Q, K, A). Suits must match.'),
                        _buildEnhancedBulletPoint('Others must play a longer or higher sequence.'),
                        _buildEnhancedSubSection('3. Groups'),
                        _buildEnhancedBulletPoint('2–4 cards of same value and suit (e.g., three Jacks of clubs).'),
                        _buildEnhancedBulletPoint('Others: same count of cards, same value. Suit can differ.'),

                        _buildEnhancedSection('How to Play', Icons.play_arrow),
                        _buildEnhancedBulletPoint('Choose first player randomly or by method.'),
                        _buildEnhancedBulletPoint('Deal cards clockwise.'),
                        _buildEnhancedBulletPoint('First player plays any pattern. Others may:'),
                        _buildEnhancedSubBulletPoint('Pass: Skip turn.'),
                        _buildEnhancedSubBulletPoint('Play same pattern with higher value.'),

                        _buildEnhancedSection('Titles', Icons.emoji_events),
                        _buildEnhancedSubSection('King (1st to finish)'),
                        _buildEnhancedSubSection('Wise (2nd to finish)'),
                        _buildEnhancedBulletPoint('Starts the next round.'),
                        _buildEnhancedSubSection('Beggar (Last to finish)'),
                        _buildEnhancedSubSection('Civilians'),
                        _buildEnhancedBulletPoint('Finishers between Wise and Beggar'),

                        const SizedBox(height: 32),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.grey.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              '©2025 Beggar Online. All rights reserved.',
                              style: TextStyle(
                                fontFamily: "Poppins",
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildEnhancedSection(String title, IconData icon) {
  return Container(
    margin: const EdgeInsets.only(top: 24, bottom: 16),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.blue),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );
}

Widget _buildEnhancedSubSection(String subtitle) {
  return Container(
    margin: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
    child: Text(
      subtitle,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  );
}

Widget _buildEnhancedParagraph(String text) {
  return Container(
    margin: const EdgeInsets.only(left: 8, bottom: 16),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
        color: Colors.black87,
      ),
    ),
  );
}

Widget _buildEnhancedBulletPoint(String text) {
  return Container(
    margin: const EdgeInsets.only(left: 12, bottom: 8),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEnhancedSubBulletPoint(String text) {
  return Container(
    margin: const EdgeInsets.only(left: 28, bottom: 8),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}