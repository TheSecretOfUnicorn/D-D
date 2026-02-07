import 'dart:io';
import 'package:flutter/material.dart';

class CharacterAvatar extends StatelessWidget {
  final String? imagePath;
  final double size;
  final VoidCallback? onTap; // Pour changer l'image au clic

  const CharacterAvatar({
    super.key,
    this.imagePath,
    this.size = 40,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    
    // Si on a un chemin, on essaie de charger le fichier
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        img = FileImage(file);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size,
        backgroundColor: Colors.grey.shade800,
        backgroundImage: img, // Affiche l'image si elle existe
        child: img == null
            ? Icon(Icons.person, size: size, color: Colors.white54)
            : null,
      ),
    );
  }
}