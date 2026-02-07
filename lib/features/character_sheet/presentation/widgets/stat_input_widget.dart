import 'package:flutter/material.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';

class StatInputWidget extends StatefulWidget {
  final StatDefinitionModel definition;
  final dynamic currentValue;
  final Function(dynamic) onChanged;

  const StatInputWidget({
    super.key,
    required this.definition,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  State<StatInputWidget> createState() => _StatInputWidgetState();
}

class _StatInputWidgetState extends State<StatInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // On initialise le contrôleur avec la valeur actuelle
    _controller = TextEditingController(text: widget.currentValue.toString());
  }

  @override
  void didUpdateWidget(covariant StatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la valeur change depuis l'extérieur (ex: reset), on met à jour le champ
    if (widget.currentValue.toString() != _controller.text) {
      _controller.text = widget.currentValue.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LOGIQUE DE SÉLECTION DU WIDGET
    // C'est ici que la modularité opère : on switch sur le "type" du JSON.
    
    switch (widget.definition.type) {
      case 'integer':
        return _buildNumberInput();
      case 'string':
      default:
        return _buildStringInput();
    }
  }

  Widget _buildNumberInput() {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number, // Clavier numérique
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.definition.name,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        suffixText: widget.definition.id.toUpperCase(),
        border: const OutlineInputBorder(),
        isDense: true, // Plus compact
      ),
      onChanged: (value) {
        // Conversion sécurisée en entier
        final intVal = int.tryParse(value);
        if (intVal != null) {
          widget.onChanged(intVal);
        }
      },
    );
  }

  Widget _buildStringInput() {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.multiline,
      maxLines: null,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.definition.name,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) {
        widget.onChanged(value);
      },
    );
  }
}