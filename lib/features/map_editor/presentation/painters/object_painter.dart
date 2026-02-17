import 'dart:math'; // Nécessaire pour pi
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
      
      ui.Image? img;
      Color fallbackColor = Colors.transparent;
      
      switch (obj.type) {
        case ObjectType.door:
          img = obj.state ? assets['door_open'] : assets['door_closed'];
          fallbackColor = Colors.brown;
          break;
        case ObjectType.chest:
          img = obj.state ? assets['chest_open'] : assets['chest_closed'];
          fallbackColor = Colors.amber;
          break;
        case ObjectType.torch:
          img = assets['torch'];
          fallbackColor = Colors.orange;
          break;
        case ObjectType.trap:
          // TODO: Handle this case.
          throw UnimplementedError();
        case ObjectType.custom:
          // TODO: Handle this case.
          throw UnimplementedError();
      }

      // --- CORRECTION ROTATION ---
      canvas.save();
      
      // 1. On déplace le point de pivot au CENTRE de l'objet
      canvas.translate(center.dx, center.dy);

      // 2. On applique la rotation
      // Tu as demandé 8 positions : 360° / 8 = 45° = pi / 4 radians
      if (obj.rotation > 0) {
        canvas.rotate(obj.rotation * (pi / 4)); 
      }

      // 3. On dessine l'image centrée sur le point de pivot (0,0 local)
      if (img != null) {
        // Ajuste la taille selon tes besoins (ici 1.5x le rayon pour couvrir un peu plus)
        final double size = radius * 1.5; 
        
        // Rect de destination centré sur (0,0)
        final dst = Rect.fromCenter(center: Offset.zero, width: size, height: size);
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        
        canvas.drawImageRect(img, src, dst, Paint());
      } else {
        // Fallback carré centré
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: radius, height: radius),
          Paint()..color = fallbackColor
        );
      }
      
      canvas.restore(); // Restaure pour le prochain objet
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ObjectPainter oldDelegate) => true;
}