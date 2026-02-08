import 'dart:math';
import 'package:flutter/material.dart';
import '../../../rules_engine/data/models/rule_system_model.dart';

class StatInputWidget extends StatefulWidget {
  final StatDefinition definition;
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
  // IDs reconnus pour afficher le bouton dé
  final List<String> _attributes = ['str', 'dex', 'con', 'int', 'wis', 'cha'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue?.toString() ?? "");
  }

  @override
  void didUpdateWidget(covariant StatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue != widget.currentValue) {
       if (_controller.text != widget.currentValue.toString()) {
         _controller.text = widget.currentValue?.toString() ?? "";
       }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _calculateModifier(int score) => ((score - 10) / 2).floor();

  void _rollDice(int modifier) {
    final d20 = Random().nextInt(20) + 1;
    final total = d20 + modifier;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.definition.name.toUpperCase(), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text("$total", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: d20 == 20 ? Colors.green : (d20 == 1 ? Colors.red : Colors.white))),
            Text("d20 ($d20) + $modifier", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNumber = widget.definition.type == 'integer';
    final isAttribute = _attributes.contains(widget.definition.id);
    
    int? modifierVal;
    String? modifierText;
    
    if (isAttribute && widget.currentValue is int) {
      modifierVal = _calculateModifier(widget.currentValue as int);
      modifierText = modifierVal >= 0 ? "+$modifierVal" : "$modifierVal";
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              labelText: widget.definition.name,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              if (isNumber) {
                final intVal = int.tryParse(value);
                if (intVal != null) widget.onChanged(intVal);
              } else {
                widget.onChanged(value);
              }
            },
          ),
        ),
        if (modifierText != null) ...[
          const SizedBox(width: 8),
          Text(modifierText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          IconButton(
            icon: const Icon(Icons.casino),
            color: Colors.blueAccent,
            onPressed: () => _rollDice(modifierVal!),
          ),
        ]
      ],
    );
  }
}