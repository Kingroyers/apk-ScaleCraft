import 'package:flutter/material.dart';
import '../models/chorded_line.dart';
import '../core/helpers/transpose_helper.dart';

class ChordedLineWidget extends StatelessWidget {
  final ChordedLine line;
  final String originalKey;
  final String currentKey;
  final double fontSize;

  const ChordedLineWidget({
    super.key,
    required this.line,
    required this.originalKey,
    required this.currentKey,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chordColor = theme.colorScheme.primary;

    if (line.chords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          line.lyrics,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'monospace',
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    // Transposición
    final transposed = TransposeHelper.transposeLine(
      line.chords,
      originalKey,
      currentKey,
    );

    // Construir la fila de acordes posicionados sobre la letra
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila de acordes
        _ChordRow(
          lyrics: line.lyrics,
          chords: transposed,
          fontSize: fontSize,
          chordColor: chordColor,
        ),
        // Fila de letra
        Text(
          line.lyrics.isEmpty ? ' ' : line.lyrics,
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: 'monospace',
            height: 1.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _ChordRow extends StatelessWidget {
  final String lyrics;
  final Map<int, String> chords;
  final double fontSize;
  final Color chordColor;

  const _ChordRow({
    required this.lyrics,
    required this.chords,
    required this.fontSize,
    required this.chordColor,
  });

  @override
  Widget build(BuildContext context) {
    if (chords.isEmpty) return const SizedBox.shrink();

    // Calculamos el ancho de cada carácter en monospace
    // En monospace cada caracter tiene el mismo ancho
    final charWidth = _estimateCharWidth(fontSize);

    // Altura de la fila de acordes
    final chordRowHeight = fontSize + 2;

    return SizedBox(
      height: chordRowHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: chords.entries.map((entry) {
          final charPos = entry.key;
          final chord = entry.value;
          final leftOffset = charPos * charWidth;

          return Positioned(
            left: leftOffset,
            top: 0,
            child: Text(
              chord,
              style: TextStyle(
                fontSize: fontSize - 2,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: chordColor,
                height: 1,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Aproximación del ancho de carácter monospace
  double _estimateCharWidth(double fontSize) {
    return fontSize * 0.60;
  }
}