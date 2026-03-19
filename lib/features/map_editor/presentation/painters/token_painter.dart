import 'dart:math';

import 'package:flutter/material.dart';

import '/core/utils/hex_utils.dart';
import '../../data/models/map_config_model.dart';

class TokenPainter extends CustomPainter {
  final MapConfig config;
  final Map<String, Point<int>> tokenPositions;
  final Map<String, dynamic> tokenDetails;
  final Set<String> highlightedTokenIds;
  final String? activeTokenId;
  final String? targetTokenId;
  final double radius;
  final Offset offset;

  TokenPainter({
    required this.config,
    required this.tokenPositions,
    required this.tokenDetails,
    required this.highlightedTokenIds,
    required this.activeTokenId,
    required this.targetTokenId,
    required this.radius,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final entry in tokenPositions.entries) {
      final charId = entry.key;
      final gridPoint = entry.value;
      final details = tokenDetails[charId] ?? {'color': Colors.blue, 'name': '?'};
      final color = details['color'] as Color? ?? Colors.blue;
      final name = details['name']?.toString() ?? "?";
      final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
      final center = HexUtils.gridToPixel(gridPoint.x, gridPoint.y, radius);
      final tokenRadius = radius * 0.8;
      final isActive = activeTokenId == charId;
      final isTarget = targetTokenId == charId;
      final isHighlighted = highlightedTokenIds.contains(charId);

      canvas.drawCircle(
        center + const Offset(2, 2),
        tokenRadius,
        Paint()..color = Colors.black.withValues(alpha: 0.4),
      );

      if (isActive || isHighlighted) {
        canvas.drawCircle(
          center,
          tokenRadius + 7,
          Paint()
            ..color = (isActive
                    ? Colors.amberAccent
                    : isTarget
                        ? Colors.redAccent
                        : Colors.greenAccent)
                .withValues(alpha: isActive ? 0.35 : (isTarget ? 0.28 : 0.22)),
        );
      }

      if (isTarget) {
        final targetRing = Paint()
          ..color = Colors.redAccent.withValues(alpha: 0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(center, tokenRadius + 10, targetRing);
      }

      canvas.drawCircle(center, tokenRadius, Paint()..color = Colors.white);
      canvas.drawCircle(center, tokenRadius - 3, Paint()..color = color);

      textPainter.text = TextSpan(
        text: initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: tokenRadius,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TokenPainter oldDelegate) {
    return tokenPositions != oldDelegate.tokenPositions ||
        tokenDetails != oldDelegate.tokenDetails ||
        highlightedTokenIds != oldDelegate.highlightedTokenIds ||
        activeTokenId != oldDelegate.activeTokenId ||
        targetTokenId != oldDelegate.targetTokenId;
  }
}
