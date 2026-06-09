import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final String displayName;
  final String displayEmail;
  final bool isAuthenticated;

  const ProfilePage({
    super.key,
    required this.displayName,
    required this.displayEmail,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    final avatarLetter = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';
    final statusLabel = isAuthenticated ? 'Logged in' : 'Guest session';
    final statusColor = isAuthenticated
        ? const Color(0xFF6BCB77)
        : const Color(0xFF888888);
    final statusTextColor = isAuthenticated
        ? const Color(0xFF1B5E20)
        : const Color(0xFF424242);

    return Scaffold(
      backgroundColor: const Color(0xFFB5D2E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF789CE6),
        foregroundColor: Colors.white,
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF789CE6),
                    child: Text(
                      avatarLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayEmail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF5B6B7A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('Profile editing will be available soon.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
