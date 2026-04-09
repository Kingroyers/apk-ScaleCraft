import 'package:flutter/material.dart';
import 'chord_chip.dart';

class ProgressionChip extends StatelessWidget {
  final List<Map<String,String>> progression;

  const ProgressionChip({super.key, required this.progression});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (int i = 0; i < progression.length; i++) ...[
          ChordChip(
            grado: progression[i]["grado"]!,
            nota: progression[i]["nota"]!,
            tipo: progression[i]["tipo"]!,
          ),
          if (i < progression.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text("→", style: TextStyle(color: Color(0xFF7A7568), fontSize: 16)),
            ),
        ],
      ]),
    );
  }
}
