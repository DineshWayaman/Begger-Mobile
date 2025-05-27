import 'package:flutter/material.dart';

void showTermsAndConditionsBottomSheet(BuildContext context) {
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
                  'Terms & Conditions',
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
                        _buildEnhancedSection('1. Introduction', Icons.info_outline),
                        _buildEnhancedParagraph(
                            'By using this game, you agree to be bound by these Terms and Conditions. If you do not accept these terms, do not use the app.'
                        ),

                        _buildEnhancedSection('2. Eligibility', Icons.verified_user),
                        _buildEnhancedBulletPoint('You must be at least 13 years old to play this game.'),
                        _buildEnhancedBulletPoint('If under 18, you must have parental or guardian consent.'),

                        _buildEnhancedSection('3. Game Rules & Fair Play', Icons.rule),
                        _buildEnhancedBulletPoint('No cheating or using unfair means.'),
                        _buildEnhancedBulletPoint('Respect other players. Abusive behavior is not tolerated.'),
                        _buildEnhancedBulletPoint('Users found violating rules may be banned without notice.'),

                        _buildEnhancedSection('4. User Responsibilities', Icons.person_outline),
                        _buildEnhancedBulletPoint('Keep your account secure and confidential.'),
                        _buildEnhancedBulletPoint('You are responsible for all activity under your account.'),

                        _buildEnhancedSection('5. Data & Privacy', Icons.privacy_tip),
                        _buildEnhancedBulletPoint('We may collect limited data to improve user experience.'),
                        _buildEnhancedBulletPoint('We do not share your personal data with third parties without consent.'),

                        _buildEnhancedSection('6. Liability Disclaimer', Icons.warning_amber),
                        _buildEnhancedBulletPoint('We are not liable for damages resulting from use of the app.'),
                        _buildEnhancedBulletPoint('This app is provided "as is" without warranties of any kind.'),

                        _buildEnhancedSection('7. Amendments', Icons.edit_note),
                        _buildEnhancedBulletPoint('Terms may be updated from time to time.'),
                        _buildEnhancedBulletPoint('Users will be notified of significant changes via app notifications.'),

                        _buildEnhancedSection('8. Contact Us', Icons.email_outlined),
                        _buildEnhancedParagraph(
                            'If you have any questions about these Terms, contact us at support@playbeggar.online.'
                        ),

                        const SizedBox(height: 32),
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

Widget _buildEnhancedParagraph(String text) {
  return Container(
    margin: const EdgeInsets.only(left: 8, bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.grey.withOpacity(0.1),
        width: 1,
      ),
    ),
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