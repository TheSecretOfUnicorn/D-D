import 'package:flutter/material.dart';

enum AppFeedbackTone { info, success, warning, error }

class AppFeedback {
  static void show(
    BuildContext context,
    String message, {
    AppFeedbackTone tone = AppFeedbackTone.info,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: _backgroundFor(tone),
        content: Row(
          children: [
            Icon(_iconFor(tone), color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void info(BuildContext context, String message) {
    show(context, message, tone: AppFeedbackTone.info);
  }

  static void success(BuildContext context, String message) {
    show(context, message, tone: AppFeedbackTone.success);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, tone: AppFeedbackTone.warning);
  }

  static void error(BuildContext context, String message) {
    show(
      context,
      message,
      tone: AppFeedbackTone.error,
      duration: const Duration(milliseconds: 2400),
    );
  }

  static Color _backgroundFor(AppFeedbackTone tone) {
    switch (tone) {
      case AppFeedbackTone.success:
        return const Color(0xFF2E7D32);
      case AppFeedbackTone.warning:
        return const Color(0xFF8D6E63);
      case AppFeedbackTone.error:
        return const Color(0xFFB23A48);
      case AppFeedbackTone.info:
        return const Color(0xFF2C3E50);
    }
  }

  static IconData _iconFor(AppFeedbackTone tone) {
    switch (tone) {
      case AppFeedbackTone.success:
        return Icons.check_circle_outline;
      case AppFeedbackTone.warning:
        return Icons.info_outline;
      case AppFeedbackTone.error:
        return Icons.error_outline;
      case AppFeedbackTone.info:
        return Icons.notifications_outlined;
    }
  }
}
