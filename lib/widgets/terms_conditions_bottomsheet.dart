import 'package:flutter/material.dart';

void showTermsAndConditionsBottomSheet(BuildContext context) {
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
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
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
                        _buildSectionTitle('1. Introduction', Icons.info_outline),
                        _buildParagraph(
                            'By using this game, you agree to be bound by these Terms and Conditions. If you do not accept these terms, do not use the app.'),

                        _buildSectionTitle('2. Eligibility', Icons.verified_user),
                        _buildBulletPoint('You must be at least 13 years old to play this game.'),
                        _buildBulletPoint('If under 18, you must have parental or guardian consent.'),

                        _buildSectionTitle('3. Game Rules & Fair Play', Icons.rule),
                        _buildBulletPoint('No cheating or using unfair means.'),
                        _buildBulletPoint('Respect other players. Abusive behavior is not tolerated.'),
                        _buildBulletPoint('Users found violating rules may be banned without notice.'),

                        _buildSectionTitle('4. User Responsibilities', Icons.person_outline),
                        _buildBulletPoint('Keep your account secure and confidential.'),
                        _buildBulletPoint('You are responsible for all activity under your account.'),

                        _buildSectionTitle('5. Data & Privacy', Icons.privacy_tip),
                        _buildBulletPoint('We may collect limited data to improve user experience.'),
                        _buildBulletPoint('We do not share your personal data with third parties without consent.'),

                        _buildSectionTitle('6. Liability Disclaimer', Icons.warning_amber),
                        _buildBulletPoint('We are not liable for damages resulting from use of the app.'),
                        _buildBulletPoint('This app is provided "as is" without warranties of any kind.'),

                        _buildSectionTitle('7. Amendments', Icons.edit_note),
                        _buildBulletPoint('Terms may be updated from time to time.'),
                        _buildBulletPoint('Users will be notified of significant changes via app notifications.'),

                        _buildSectionTitle('8. Contact Us', Icons.email_outlined),
                        _buildParagraph(
                            'If you have any questions about these Terms, contact us at support@playbeggar.online.'),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
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
