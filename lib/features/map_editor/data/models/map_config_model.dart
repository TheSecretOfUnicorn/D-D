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
    this.backgroundColor = const Color(0xFFE0D8C0), // Beige par défaut
    this.gridColor = const Color(0x4D5C4033),       // Marron semi-transparent
  });

  /// Méthode utilitaire pour créer une copie modifiée de la config
  MapConfig copyWith({
    int? widthInCells,
    int? heightInCells,
    double? cellSize,
    Color? backgroundColor,
    Color? gridColor,
  }) {
    return MapConfig(
      widthInCells: widthInCells ?? this.widthInCells,
      heightInCells: heightInCells ?? this.heightInCells,
      cellSize: cellSize ?? this.cellSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      gridColor: gridColor ?? this.gridColor,
    );
  }
}