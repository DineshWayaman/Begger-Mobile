import 'package:flutter/material.dart';

void showAboutGameBottomSheet(BuildContext context) {
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'About Beggar',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(thickness: 1.2, color: Colors.grey),

            // Scrollable content
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                controller: scrollController,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Overview', Icons.info_outline),
                        _buildParagraph(
                            'Beggar is a fun and strategic card game for 3 or more players. The goal is to be the first to play all your cards to become the "King," while avoiding being the last player, known as the "Beggar."'),

                        _buildSectionTitle('Requirements', Icons.check_circle_outline),
                        _buildBulletPoint('Minimum of 3 players.'),
                        _buildBulletPoint('Standard card deck with 2 jokers and a details card.'),

                        _buildSectionTitle('Serving', Icons.send),
                        _buildBulletPoint('Cards are dealt in clockwise order.'),
                        _buildBulletPoint('Each player receives one card per round.'),

                        _buildSectionTitle('Card Values (Ascending)', Icons.filter_list),
                        _buildBulletPoint('3, 4, 5, 6, 7, 8, 9, 10, J, Q, K, A, 2, Details Card (Rank 1).'),
                        _buildBulletPoint('Joker: Can represent any card (except Details Card) of any suit.'),
                        _buildBulletPoint('Suits are irrelevant except for specific patterns.'),

                        _buildSectionTitle('Card Patterns', Icons.grid_view),
                        _buildSubSection('1. Singles'),
                        _buildBulletPoint('Play any single card. Others must play a higher value single.'),
                        _buildSubSection('2. Consecutive'),
                        _buildBulletPoint('2–13 consecutive cards (e.g., 3, 4, 5, 6). Suits must match.'),
                        _buildBulletPoint('Others must play a longer or higher sequence.'),
                        _buildSubSection('3. Groups'),
                        _buildBulletPoint('2–4 cards of same value and suit (e.g., three Jacks of clubs).'),
                        _buildBulletPoint('Others: same count of cards, same value. Suit can differ.'),

                        _buildSectionTitle('How to Play', Icons.play_arrow),
                        _buildBulletPoint('Choose first player randomly or by method.'),
                        _buildBulletPoint('Deal cards clockwise.'),
                        _buildBulletPoint('First player plays any pattern. Others may:'),
                        _buildSubBulletPoint('Pass: Skip turn.'),
                        _buildSubBulletPoint('Play higher pattern of same type.'),
                        _buildSubBulletPoint(
                            'Take the Chance: Play unbeatable pattern. If beaten, next player takes chance.'),
                        _buildBulletPoint('Player who wins chance starts new pattern.'),

                        _buildSectionTitle('Titles', Icons.emoji_events),
                        _buildSubSection('King (1st to finish)'),
                        _buildBulletPoint('Takes Beggar’s highest card (excluding Joker/Detail).'),
                        _buildBulletPoint('Gives any unwanted card to Beggar.'),
                        _buildSubSection('Wise (2nd to finish)'),
                        _buildBulletPoint('Starts the next round.'),
                        _buildSubSection('Beggar (Last to finish)'),
                        _buildBulletPoint('Gives highest-value card to King.'),
                        _buildBulletPoint('Accepts King’s unwanted card.'),
                        _buildBulletPoint('Deals cards next round.'),
                        _buildSubSection('Civilians'),
                        _buildBulletPoint('Finishers between Wise and Beggar, no title.'),
                        Center(
                          child: Text(
                            '©2025 Beggar Game by Globevik',
                            style: TextStyle(
                              fontFamily: "Poppins",
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,

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

Widget _buildSectionTitle(String title, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSubSection(String subtitle) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 4, left: 8),
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

Widget _buildParagraph(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
    ),
  );
}

Widget _buildBulletPoint(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 12, bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSubBulletPoint(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 28, bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('◦ ', style: TextStyle(fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
