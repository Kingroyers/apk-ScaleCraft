import 'package:flutter/material.dart';
import '../core/helpers/chord_helper.dart';

class ChordChip extends StatelessWidget {
  final String grado;
  final String nota;
  final String tipo;

  const ChordChip({super.key, required this.grado, required this.nota, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final color = colorTipo(tipo);
    final bg    = bgTipo(tipo);
    return Column(children: [
      Text(grado, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
        child: Text(nota, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}
