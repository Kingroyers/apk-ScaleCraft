import 'package:flutter/material.dart';
import '../../models/song_section.dart';
import '../constants.dart';

String sufijoTipo(String tipo) {
  if (tipo == "min") return "m";
  if (tipo == "dim") return "°";
  return "";
}

Color colorTipo(String tipo) {
  if (tipo == "min") return const Color(0xFFC4893A);
  if (tipo == "dim") return const Color(0xFFE05252);
  return const Color(0xFFE8C547);
}

Color bgTipo(String tipo) {
  if (tipo == "min") return const Color(0x1AC4893A);
  if (tipo == "dim") return const Color(0x1AE05252);
  return const Color(0x1AE8C547);
}

String? normalizarNota(String nota) {
  const enarm = {"DB":"C#","EB":"D#","FB":"E","GB":"F#","AB":"G#","BB":"A#","CB":"B"};
  final up = nota.toUpperCase().replaceAll('♭','B').replaceAll('♯','#');
  if (kNotas.contains(up)) return up;
  if (enarm.containsKey(up)) return enarm[up];
  return null;
}

Map<String,String>? parsearAcorde(String token) {
  final reg = RegExp(r'^([A-Ga-g][#b]?)(m|°|dim|maj|min)?$');
  final m = reg.firstMatch(token.trim());
  if (m == null) return null;
  final nota = normalizarNota(m.group(1)!);
  if (nota == null) return null;
  final cal = m.group(2) ?? "";
  String tipo = "maj";
  if (cal == "m" || cal == "min") tipo = "min";
  if (cal == "°" || cal == "dim") tipo = "dim";
  return {"nota": nota, "tipo": tipo};
}

List<SongSection> getSectionsFromRawText(String text) {
    List<SongSection> sections = [];
    List<String> lines = text.split('\n');
    
    String currentSectionTitle = "General";
    List<String> currentLines = [];

    final sectionRegExp = RegExp(r'^\[(Intro|Verso|Coro|Bridge|Solo|Outro|Fin).*\]$', caseSensitive: false);

    for (var line in lines) {
      if (sectionRegExp.hasMatch(line.trim())) {
        // Guardar sección anterior si existe
        if (currentLines.isNotEmpty) {
          sections.add(SongSection(title: currentSectionTitle, rawContent: currentLines.join('\n')));
          currentLines = [];
        }
        currentSectionTitle = line.trim().replaceAll('[', '').replaceAll(']', '');
      } else {
        currentLines.add(line);
      }
    }
    
    // Agregar la última sección
    if (currentLines.isNotEmpty) {
      sections.add(SongSection(title: currentSectionTitle, rawContent: currentLines.join('\n')));
    }
    
    return sections;
  }

