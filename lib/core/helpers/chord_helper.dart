import 'package:flutter/material.dart';
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
    

    // Acordes más comunes en canciones de iglesia
  const List<String> commonChords = [
    'C', 'Cm', 'C7', 'Cmaj7',
    'D', 'Dm', 'D7',
    'E', 'Em', 'E7',
    'F', 'Fm', 'F7',
    'G', 'Gm', 'G7',
    'A', 'Am', 'A7',
    'B', 'Bm', 'B7',
    'C#', 'C#m', 'Db',
    'Eb', 'Ebm',
    'F#', 'F#m',
    'Ab', 'Abm',
    'Bb', 'Bbm',
  ];
 
  // Valida si un string es un acorde reconocido
  bool isValidChord(String input) {
    return RegExp(
      r'^[A-G][#b]?(m|maj|dim|aug|sus|add)?[0-9]?$',
    ).hasMatch(input.trim());
  }
 
  // Acordes del picker agrupados por tipo
  const Map<String, List<String>> pickerGroups = {
    'Mayor': ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
    'Menor': ['Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm'],
    '7ma': ['C7', 'D7', 'E7', 'F7', 'G7', 'A7', 'B7'],
    'Especiales': ['Cmaj7', 'Gmaj7', 'Fmaj7', 'Dmaj7', 'Cadd9', 'Gadd9'],
    '#/b': ['C#', 'C#m', 'Bb', 'Bbm', 'Eb', 'Ebm', 'Ab', 'Abm', 'F#', 'F#m'],
  };
  

