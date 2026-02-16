import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../data/models/map_config_model.dart';
import '../../data/models/world_object_model.dart';
import '/core/utils/hex_utils.dart';

class ObjectPainter extends CustomPainter {
  final MapConfig config;
  final Map<String, WorldObject> objects;
  final Map<String, ui.Image> assets;
  final double radius;
  final Offset offset;

  ObjectPainter({
    required this.config,
    required this.objects,
    required this.assets,
    required this.radius,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (var obj in objects.values) {
      final center = HexUtils.gridToPixel(obj.position.x, obj.position.y, radius);
      
      // On choisit l'image ou la couleur selon le type
      ui.Image? img;
      Color fallbackColor = Colors.transparent;
      
      switch (obj.type) {
        case ObjectType.door:
          // Si ouvert : transparent ou porte ouverte. Si fermé : porte fermée
          img = obj.state ? assets['door_open'] : assets['door_closed'];
          fallbackColor = obj.state ? Colors.brown.withValues(alpha: 0.3) : Colors.brown;
          break;
        case ObjectType.chest:
          img = obj.state ? assets['chest_open'] : assets['chest_closed'];
          fallbackColor = Colors.amber;
          break;
        case ObjectType.torch:
          img = assets['torch'];
          fallbackColor = Colors.orangeAccent;
          break;
      }
      
      if (obj.rotation > 0) {
        canvas.rotate(obj.rotation * (pi / 3));
      }

    
      canvas.save();
      canvas.translate(center.dx, center.dy);

      if (img != null) {
        // Dessin de l'image (centrée, taille ajustée)
        final double size = radius * 1.5; 
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = Rect.fromCenter(center: Offset.zero, width: size, height: size);
        canvas.drawImageRect(img, src, dst, Paint());
      } else {
        // Fallback (Carré de couleur)
        canvas.drawRect( 
          Rect.fromCenter(center: Offset.zero, width: radius, height: radius),
          Paint()..color = fallbackColor
        );
        
        // Petit texte pour debug (D = Door, C = Chest)
        final textPainter = TextPainter(
          text: TextSpan(
            text: obj.type.name[0].toUpperCase(), 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          textDirection: TextDirection.ltr
        )..layout();
        textPainter.paint(canvas, Offset(-textPainter.width/2, -textPainter.height/2));
      }
      
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ObjectPainter oldDelegate) => true;
}