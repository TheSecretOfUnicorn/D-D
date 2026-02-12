import 'package:flutter/material.dart';

class MapConfig {
  final int widthInCells;
  final int heightInCells;
  final double cellSize;
  final Color backgroundColor;
  final Color gridColor;

  const MapConfig({
    required this.widthInCells,
    required this.heightInCells,
    required this.cellSize,
    this.backgroundColor = const Color(0xFF121212),
    this.gridColor = const Color(0x40FFFFFF), // Blanc à 25% d'opacité
  });

  // Getters utilitaires
  double get totalWidth => widthInCells * cellSize;
  double get totalHeight => heightInCells * cellSize;
}