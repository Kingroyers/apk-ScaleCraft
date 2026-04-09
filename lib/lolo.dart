import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Acoustic Guitar System',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8C547),
          secondary: Color(0xFFC4893A),
          surface: Color(0xFF161616),
        ),
      ),
      home: const EscalaPage(),
    );
  }
}

// ═══════════════════════════════════════════════
// MUSIC THEORY HELPERS
// ═══════════════════════════════════════════════
const List<String> kNotas   = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"];
const List<int>    kFormula      = [2,2,1,2,2,2,1];
const List<int>    kFormulaMinor = [2,1,2,2,1,2,2];
const List<String> kGrados  = ["I","II","III","IV","V","VI","VII"];
const List<String> kQualities      = ["maj","min","min","maj","maj","min","dim"];
const List<String> kQualitiesMinor = ["min","dim","maj","min","min","maj","maj"];

List<String> generarEscala(String tono, {bool minor = false}) {
  int pos = kNotas.indexOf(tono);
  List<String> esc = [kNotas[pos]];
  final formula = minor ? kFormulaMinor : kFormula;
  for (int paso in formula) { pos = (pos + paso) % 12; esc.add(kNotas[pos]); }
  return esc;
}

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

List<Map<String, String>> getScaleChords(String tono, {bool minor = false}) {
  final esc = generarEscala(tono, minor: minor);
  final qualities = minor ? kQualitiesMinor : kQualities;
  return List.generate(7, (i) => {
    "label": esc[i] + sufijoTipo(qualities[i]),
    "note":  esc[i],
    "type":  qualities[i],
    "degree": kGrados[i],
  });
}

// ═══════════════════════════════════════════════
// TRANSPOSITION HELPER
// ═══════════════════════════════════════════════

/// Transposes a single chord label (e.g. "Am", "C#", "F°") from one key to another.
/// Returns null if the chord cannot be mapped (e.g. non-diatonic).
String? transposeChord(String chord, String fromTone, String toTone, {bool minor = false}) {
  final qualities = minor ? kQualitiesMinor : kQualities;
  final escFrom = generarEscala(fromTone, minor: minor).sublist(0, 7);
  final escTo   = generarEscala(toTone,   minor: minor).sublist(0, 7);

  // Parse chord into root + quality suffix
  final reg = RegExp(r'^([A-G][#]?)(m|°)?$');
  final match = reg.firstMatch(chord.trim());
  if (match == null) return null;

  final root = match.group(1)!;
  final suffix = match.group(2) ?? '';

  final idx = escFrom.indexOf(root);
  if (idx == -1) return null; // not diatonic

  return escTo[idx] + suffix;
}

/// Transposes an entire song (all chords in all sections) to a new key.
/// Chords that can't be mapped are kept as-is.
Song transposeSong(Song song, String toTone) {
  final newSections = song.sections.map((sec) {
    final newChords = sec.chords.map((chord) {
      final result = transposeChord(chord, song.tone, toTone, minor: song.isMinor);
      return result ?? chord;
    }).toList();
    return SongSection(name: sec.name, chords: newChords, lyrics: sec.lyrics);
  }).toList();

  final now = DateTime.now();
  return Song(
    id: now.millisecondsSinceEpoch,
    title: song.title,
    artist: song.artist,
    tone: toTone,
    bpm: song.bpm,
    isMinor: song.isMinor,
    sections: newSections,
    date: "${now.day.toString().padLeft(2,'0')} ${_mesStr(now.month)} ${now.year}",
  );
}

String _mesStr(int m) => ["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"][m-1];

// ═══════════════════════════════════════════════
// MAIN PAGE — ESCALA
// ═══════════════════════════════════════════════
class EscalaPage extends StatefulWidget {
  const EscalaPage({super.key});
  @override
  State<EscalaPage> createState() => _EscalaPageState();
}

class _EscalaPageState extends State<EscalaPage> {
  final List<Map<String,String>> presets = [
    {"label": "I–V–VI–IV", "value": "1-5-6-4"},
    {"label": "I–IV–V–I",  "value": "1-4-5-1"},
    {"label": "II–V–I",    "value": "2-5-1"},
    {"label": "I–VI–IV–V", "value": "1-6-4-5"},
  ];

  String tono = "C";
  int _tab = 0;
  bool _isMinor = false;

  List<Map<String,String>> escalaActual    = [];
  List<Map<String,String>> progresionActual = [];
  bool escalaVisible    = false;
  bool progresionVisible = false;

  final TextEditingController detectarController = TextEditingController();
  List<Map<String,String>> deteccionActual = [];
  bool deteccionVisible = false;
  String deteccionError = "";

  String tonoOrigen  = "C";
  String tonoDestino = "G";
  final TextEditingController transpController  = TextEditingController();
  final TextEditingController gradosController  = TextEditingController();
  List<Map<String,String>> transpResultado = [];
  bool   transpVisible = false;
  String transpError   = "";

  void mostrarEscala() {
    final qualities = _isMinor ? kQualitiesMinor : kQualities;
    final esc = generarEscala(tono, minor: _isMinor);
    setState(() {
      escalaActual = List.generate(7, (i) => {
        "nota":  esc[i] + sufijoTipo(qualities[i]),
        "grado": kGrados[i],
        "tipo":  qualities[i],
      });
      escalaVisible = true;
    });
  }

  void transportarGrados() {
    final input = gradosController.text.trim();
    if (input.isEmpty) return;
    final qualities = _isMinor ? kQualitiesMinor : kQualities;
    final esc = generarEscala(tono, minor: _isMinor);
    final res = <Map<String,String>>[];
    for (String t in input.split("-")) {
      final g = int.tryParse(t.trim()) ?? 0;
      if (g < 1 || g > 7) continue;
      final tipo = qualities[g - 1];
      res.add({"nota": esc[g-1] + sufijoTipo(tipo), "grado": kGrados[g-1], "tipo": tipo});
    }
    setState(() { progresionActual = res; progresionVisible = res.isNotEmpty; });
  }

  void detectarGrados() {
    final input = detectarController.text.trim().toUpperCase();
    if (input.isEmpty) { setState(() { deteccionError = "Escribe notas como: C-E-G"; deteccionVisible = false; }); return; }
    final partes = input.split(RegExp(r'[-,\s]+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final qualities = _isMinor ? kQualitiesMinor : kQualities;
    final esc = generarEscala(tono, minor: _isMinor);
    final modeLabel = _isMinor ? "menor" : "mayor";
    final res = <Map<String,String>>[];
    for (String nota in partes) {
      final norm = _normalizarNota(nota);
      if (norm == null) { setState(() { deteccionError = "Nota no reconocida: $nota"; deteccionVisible = false; }); return; }
      int idx = esc.sublist(0, 7).indexOf(norm);
      if (idx == -1) {
        res.add({"nota": nota, "grado": "—", "tipo": "out", "info": "No pertenece a $tono $modeLabel"});
      } else {
        final tipo = qualities[idx];
        res.add({"nota": nota, "grado": kGrados[idx], "tipo": tipo,
          "info": "Grado ${idx+1} (${kGrados[idx]}) — ${_nombreTipo(tipo)}"});
      }
    }
    setState(() { deteccionActual = res; deteccionVisible = true; deteccionError = ""; });
  }

  void transportarEntreTonos() {
    final input = transpController.text.trim();
    if (input.isEmpty) { setState(() { transpError = "Escribe acordes o grados"; transpVisible = false; }); return; }
    final partes = input.split("-").map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final qualities = _isMinor ? kQualitiesMinor : kQualities;
    final modeLabel = _isMinor ? "menor" : "mayor";
    final escO = generarEscala(tonoOrigen, minor: _isMinor);
    final escD = generarEscala(tonoDestino, minor: _isMinor);
    final res  = <Map<String,String>>[];
    for (String token in partes) {
      final num = int.tryParse(token);
      if (num != null) {
        if (num < 1 || num > 7) continue;
        final tipo = qualities[num - 1];
        res.add({"origen": escO[num-1]+sufijoTipo(tipo), "destino": escD[num-1]+sufijoTipo(tipo),
          "grado": kGrados[num-1], "tipo": tipo});
        continue;
      }
      final parsed = _parsearAcorde(token);
      if (parsed == null) { setState(() { transpError = "No reconozco: $token"; transpVisible = false; }); return; }
      final notaRaiz = parsed["nota"]!;
      final idxO = escO.sublist(0, 7).indexOf(notaRaiz);
      if (idxO == -1) {
        res.add({"origen": token, "destino": "?", "grado": "?", "tipo": parsed["tipo"]!, "warning": "No está en $tonoOrigen $modeLabel"});
        continue;
      }
      res.add({"origen": token, "destino": escD[idxO]+sufijoTipo(qualities[idxO]),
        "grado": kGrados[idxO], "tipo": qualities[idxO]});
    }
    setState(() { transpResultado = res; transpVisible = res.isNotEmpty; transpError = ""; });
  }

  String _nombreTipo(String tipo) => tipo == "min" ? "menor" : tipo == "dim" ? "disminuido" : "mayor";

  String? _normalizarNota(String nota) {
    const enarm = {"DB":"C#","EB":"D#","FB":"E","GB":"F#","AB":"G#","BB":"A#","CB":"B"};
    final up = nota.toUpperCase().replaceAll('♭','B').replaceAll('♯','#');
    if (kNotas.contains(up)) return up;
    if (enarm.containsKey(up)) return enarm[up];
    return null;
  }

  Map<String,String>? _parsearAcorde(String token) {
    final reg = RegExp(r'^([A-Ga-g][#b]?)(m|°|dim|maj|min)?$');
    final m = reg.firstMatch(token.trim());
    if (m == null) return null;
    final nota = _normalizarNota(m.group(1)!);
    if (nota == null) return null;
    final cal = m.group(2) ?? "";
    String tipo = "maj";
    if (cal == "m" || cal == "min") tipo = "min";
    if (cal == "°" || cal == "dim") tipo = "dim";
    return {"nota": nota, "tipo": tipo};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        centerTitle: true,
        title: const Text("🎸 ACOUSTIC GUITAR",
          style: TextStyle(color: Color(0xFFE8C547), fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SongBookPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE8C547)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text("♪", style: TextStyle(color: Color(0xFFE8C547), fontSize: 13)),
                  SizedBox(width: 5),
                  Text("SONGS", style: TextStyle(color: Color(0xFFE8C547), fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 2)),
                ]),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1,
            decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xFFE8C547), Colors.transparent]))),
        ),
      ),
      body: Column(children: [
        _tonalidadGlobal(),
        _tabBar(),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _tabContent())),
      ]),
    );
  }

  Widget _tonalidadGlobal() => Container(
    color: const Color(0xFF111111),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text("TONALIDAD", style: TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 3)),
        const SizedBox(width: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _isMinor ? const Color(0x33C4893A) : const Color(0x33E8C547),
            border: Border.all(color: _isMinor ? const Color(0xFFC4893A) : const Color(0xFFE8C547)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.music_note, size: 9, color: _isMinor ? const Color(0xFFC4893A) : const Color(0xFFE8C547)),
            const SizedBox(width: 4),
            Text(_isMinor ? "MENOR" : "MAYOR",
              style: TextStyle(
                color: _isMinor ? const Color(0xFFC4893A) : const Color(0xFFE8C547),
                fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 5, runSpacing: 5,
        children: kNotas.map((a) {
          final sel = a == tono;
          return GestureDetector(
            onTap: () => setState(() { tono = a; if (escalaVisible) mostrarEscala(); }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFE8C547) : const Color(0xFF1E1E1E),
                border: Border.all(color: sel ? const Color(0xFFE8C547) : const Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(4),
                boxShadow: sel ? [const BoxShadow(color: Color(0x44E8C547), blurRadius: 8)] : [],
              ),
              child: Center(child: Text(a, style: TextStyle(
                color: sel ? const Color(0xFF0D0D0D) : Colors.grey[500],
                fontWeight: FontWeight.bold, fontSize: a.contains('#') ? 9 : 11))),
            ),
          );
        }).toList()),
    ]),
  );

  Widget _tabBar() {
    final tabs = ["Escala", "Progresión", "Detectar", "Transportar"];
    return Container(
      color: const Color(0xFF161616),
      child: Row(children: List.generate(tabs.length, (i) {
        final sel = _tab == i;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _tab = i),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(
              color: sel ? const Color(0xFFE8C547) : Colors.transparent, width: 2))),
            child: Text(tabs[i], textAlign: TextAlign.center,
              style: TextStyle(color: sel ? const Color(0xFFE8C547) : Colors.grey[600],
                fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ));
      })),
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case 0: return _tabEscala();
      case 1: return _tabProgresion();
      case 2: return _tabDetectar();
      case 3: return _tabTransportar();
      default: return const SizedBox();
    }
  }

  Widget _tabEscala() {
    final modeName = _isMinor ? "MENOR" : "MAYOR";
    final modeLabel = _isMinor ? "menor" : "mayor";
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() { _isMinor = false; if (escalaVisible) mostrarEscala(); }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_isMinor ? const Color(0xFFE8C547) : Colors.transparent,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
              ),
              child: Center(child: Text("MAYOR",
                style: TextStyle(
                  color: !_isMinor ? const Color(0xFF0D0D0D) : Colors.grey[600],
                  fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2))),
            ),
          )),
          Expanded(child: GestureDetector(
            onTap: () => setState(() { _isMinor = true; if (escalaVisible) mostrarEscala(); }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isMinor ? const Color(0xFFC4893A) : Colors.transparent,
                borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
              ),
              child: Center(child: Text("MENOR",
                style: TextStyle(
                  color: _isMinor ? const Color(0xFF0D0D0D) : Colors.grey[600],
                  fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2))),
            ),
          )),
        ]),
      ),
      const SizedBox(height: 12),
      _boton("GENERAR ESCALA $modeName DE $tono", mostrarEscala, primary: !_isMinor),
      if (escalaVisible) ...[
        const SizedBox(height: 20),
        _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Escala $modeLabel de $tono",
            style: const TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 10, children: escalaActual.map(_notaChip).toList()),
          const SizedBox(height: 14),
          _leyenda(),
        ])),
      ],
    ]);
  }

  Widget _tabProgresion() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _inputField(gradosController, "Ej: 1-5-6-4", onSubmit: transportarGrados),
    const SizedBox(height: 6),
    const Text("Grados del 1 al 7 separados por guión",
      style: TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 1)),
    const SizedBox(height: 12),
    const Text("CLÁSICAS", style: TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 2)),
    const SizedBox(height: 6),
    Wrap(spacing: 6, runSpacing: 6,
      children: presets.map((p) => _presetBtn(p["label"]!, () => setState(() => gradosController.text = p["value"]!))).toList()),
    const SizedBox(height: 14),
    _boton("TRANSPORTAR", transportarGrados, primary: false),
    if (progresionVisible) ...[
      const SizedBox(height: 20),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Progresión en $tono ${_isMinor ? 'menor' : 'mayor'}", style: const TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 2)),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < progresionActual.length; i++) ...[
              _acordeChip(progresionActual[i]),
              if (i < progresionActual.length - 1)
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text("→", style: TextStyle(color: Color(0xFF7A7568), fontSize: 16))),
            ],
          ])),
      ])),
    ],
  ]);

  Widget _tabDetectar() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("DETECTOR DE GRADOS", style: TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 3)),
      const SizedBox(height: 4),
      Text("Escribe notas y te digo qué grado son en $tono ${_isMinor ? 'menor' : 'mayor'}",
        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
    ])),
    const SizedBox(height: 12),
    _inputField(detectarController, "Ej: C-E-G  o  D, F#, A", onSubmit: detectarGrados),
    const SizedBox(height: 6),
    const Text("Acepta guión, coma o espacio. Acepta bemoles (Bb, Eb...)",
      style: TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 1)),
    const SizedBox(height: 14),
    _boton("DETECTAR GRADOS EN $tono ${_isMinor ? 'MENOR' : 'MAYOR'}", detectarGrados, primary: true),
    if (deteccionError.isNotEmpty)
      Padding(padding: const EdgeInsets.only(top: 10),
        child: Text(deteccionError, style: const TextStyle(color: Color(0xFFE05252), fontSize: 11))),
    if (deteccionVisible) ...[
      const SizedBox(height: 16),
      ...deteccionActual.map(_deteccionRow),
    ],
  ]);

  Widget _deteccionRow(Map<String,String> item) {
    final isOut = item["tipo"] == "out";
    final color = isOut ? Colors.grey[600]! : colorTipo(item["tipo"]!);
    final bg    = isOut ? const Color(0x0AFFFFFF) : bgTipo(item["tipo"]!);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.15),
            border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
          child: Center(child: Text(item["nota"]!,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isOut ? "Fuera de escala" : "Grado ${item["grado"]}",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(item["info"]!, style: TextStyle(color: Colors.grey[600], fontSize: 10, letterSpacing: 1)),
        ])),
        if (!isOut) Text(item["grado"]!,
          style: TextStyle(color: color.withOpacity(0.4), fontSize: 28, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _tabTransportar() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("TRANSPORTAR ENTRE TONALIDADES", style: TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 3)),
      const SizedBox(height: 4),
      Text("Convierte acordes o grados · Modo: ${_isMinor ? 'MENOR' : 'MAYOR'}",
        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
    ])),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("ORIGEN", style: TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 6),
        _tonoSelector(tonoOrigen, (v) => setState(() => tonoOrigen = v)),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Text("→", style: TextStyle(color: Color(0xFF7A7568), fontSize: 22))),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("DESTINO", style: TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 6),
        _tonoSelector(tonoDestino, (v) => setState(() => tonoDestino = v)),
      ])),
    ]),
    const SizedBox(height: 12),
    _inputField(transpController, "Ej: C-Em-Am-F  o  1-5-6-4", onSubmit: transportarEntreTonos),
    const SizedBox(height: 6),
    Text("Modo ${_isMinor ? 'menor' : 'mayor'} · Puedes escribir acordes o grados (1-5-6-4)",
      style: const TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 1)),
    const SizedBox(height: 12),
    Wrap(spacing: 6, runSpacing: 6,
      children: presets.map((p) => _presetBtn(p["label"]!, () => setState(() => transpController.text = p["value"]!))).toList()),
    const SizedBox(height: 14),
    _boton("TRANSPORTAR  $tonoOrigen → $tonoDestino  (${_isMinor ? 'menor' : 'mayor'})", transportarEntreTonos, primary: true),
    if (transpError.isNotEmpty)
      Padding(padding: const EdgeInsets.only(top: 10),
        child: Text(transpError, style: const TextStyle(color: Color(0xFFE05252), fontSize: 11))),
    if (transpVisible) ...[
      const SizedBox(height: 16),
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("$tonoOrigen ${_isMinor ? 'm' : ''}  →  $tonoDestino${_isMinor ? 'm' : ''}",
          style: const TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...transpResultado.map(_transpRow),
      ])),
    ],
  ]);

  Widget _tonoSelector(String valor, ValueChanged<String> onChange) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
      border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(4)),
    child: DropdownButton<String>(
      value: valor, isExpanded: true,
      dropdownColor: const Color(0xFF1E1E1E), underline: const SizedBox(),
      style: const TextStyle(color: Color(0xFFE8C547), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
      items: kNotas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
      onChanged: (v) { if (v != null) onChange(v); },
    ),
  );

  Widget _transpRow(Map<String,String> item) {
    final color = colorTipo(item["tipo"]!);
    final bg    = bgTipo(item["tipo"]!);
    final hasWarning = item.containsKey("warning");
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)),
      child: Row(children: [
        _miniAcorde(item["origen"]!, color),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text("→", style: TextStyle(color: Color(0xFF7A7568), fontSize: 18))),
        if (hasWarning) Text(item["warning"]!, style: TextStyle(color: Colors.grey[600], fontSize: 11))
        else _miniAcorde(item["destino"]!, color),
        const Spacer(),
        Text(item["grado"]!, style: TextStyle(color: color.withOpacity(0.35), fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _miniAcorde(String nota, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
      border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(4)),
    child: Text(nota, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _notaChip(Map<String,String> item) {
    final color = colorTipo(item["tipo"]!);
    final bg    = bgTipo(item["tipo"]!);
    return Column(children: [
      Text(item["grado"]!, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
        child: Text(item["nota"]!, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _acordeChip(Map<String,String> item) {
    final color = colorTipo(item["tipo"]!);
    final bg    = bgTipo(item["tipo"]!);
    return Column(children: [
      Text(item["grado"]!, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)),
        child: Text(item["nota"]!, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF161616),
      border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(4)),
    child: child,
  );

  Widget _boton(String label, VoidCallback onTap, {required bool primary}) {
    final color = primary
        ? (_isMinor ? const Color(0xFFC4893A) : const Color(0xFFE8C547))
        : const Color(0xFFC4893A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(3)),
        child: Center(child: Text(label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2))),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, {required VoidCallback onSubmit}) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Color(0xFFF0ECE0), letterSpacing: 2),
    onSubmitted: (_) => onSubmit(),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      filled: true, fillColor: const Color(0xFF1E1E1E),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(4)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x88E8C547)), borderRadius: BorderRadius.circular(4)),
    ),
  );

  Widget _presetBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
        border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(3)),
      child: Text(label, style: const TextStyle(color: Color(0xFFC4893A), fontSize: 11, letterSpacing: 1)),
    ),
  );

  Widget _leyenda() => Wrap(spacing: 16, children: [
    _legendaItem(const Color(0xFFE8C547), "Mayor"),
    _legendaItem(const Color(0xFFC4893A), "Menor"),
    _legendaItem(const Color(0xFFE05252), "Disminuido"),
  ]);

  Widget _legendaItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
  ]);
}

// ═══════════════════════════════════════════════
// SONG BOOK PAGE
// ═══════════════════════════════════════════════
class SongBookPage extends StatefulWidget {
  const SongBookPage({super.key});
  @override
  State<SongBookPage> createState() => _SongBookPageState();
}

class SongSection {
  String name;
  List<String> chords;
  String lyrics;
  SongSection({required this.name, List<String>? chords, this.lyrics = ''})
      : chords = chords ?? [];

  Map<String, dynamic> toJson() => {'name': name, 'chords': chords, 'lyrics': lyrics};
  factory SongSection.fromJson(Map<String, dynamic> j) =>
      SongSection(name: j['name'] ?? '', chords: List<String>.from(j['chords'] ?? []), lyrics: j['lyrics'] ?? '');
}

class Song {
  int id;
  String title, artist, tone, bpm, date;
  bool isMinor;
  List<SongSection> sections;
  Song({required this.id, required this.title, this.artist = '', this.tone = 'C',
    this.bpm = '', this.date = '', this.isMinor = false, List<SongSection>? sections})
      : sections = sections ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'artist': artist, 'tone': tone,
    'bpm': bpm, 'date': date, 'isMinor': isMinor,
    'sections': sections.map((s) => s.toJson()).toList(),
  };
  factory Song.fromJson(Map<String, dynamic> j) => Song(
    id: j['id'] ?? 0, title: j['title'] ?? '', artist: j['artist'] ?? '',
    tone: j['tone'] ?? 'C', bpm: j['bpm'] ?? '', date: j['date'] ?? '',
    isMinor: j['isMinor'] ?? false,
    sections: (j['sections'] as List? ?? []).map((s) => SongSection.fromJson(s)).toList(),
  );
}

const List<String> kSectionNames = ['Intro','Verso','Pre-Verso','Precoro','Coro','Post-Coro','Puente','Solo','Outro','Personalizado'];

class _SongBookPageState extends State<SongBookPage> {
  List<Song> songs = [];
  String searchQuery = '';
  String filterTone  = '';
  int? expandedId;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() { super.initState(); _loadSongs(); }

  Future<void> _loadSongs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('songbook_flutter') ?? '[]';
    final List decoded = jsonDecode(raw);
    setState(() => songs = decoded.map((j) => Song.fromJson(j)).toList());
  }

  Future<void> _saveSongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('songbook_flutter', jsonEncode(songs.map((s) => s.toJson()).toList()));
  }

  void _deleteSong(int id) {
    setState(() => songs.removeWhere((s) => s.id == id));
    _saveSongs();
    _showSnack('Canción eliminada');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1)),
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFE8C547), width: 1), borderRadius: BorderRadius.circular(4)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ════════════════════════════════
  // EXPORTAR
  // ════════════════════════════════
  Future<void> _exportSongs() async {
    if (songs.isEmpty) {
      _showSnack('⚠ No hay canciones para exportar');
      return;
    }
    setState(() => _isExporting = true);
    try {
      final now = DateTime.now();
      final timestamp = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}";
      final fileName = 'acoustic_songbook_$timestamp.json';

      final exportData = {
        'version': 1,
        'exported_at': now.toIso8601String(),
        'song_count': songs.length,
        'songs': songs.map((s) => s.toJson()).toList(),
      };
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      bool savedToDownloads = false;
      try {
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (status.isGranted || await Permission.manageExternalStorage.isGranted) {
            final downloadsDir = Directory('/storage/emulated/0/Download');
            if (await downloadsDir.exists()) {
              final file = File('${downloadsDir.path}/$fileName');
              await file.writeAsString(jsonString, encoding: utf8);
              savedToDownloads = true;
              _showSnack('✓ Guardado en Descargas: $fileName');
            }
          }
        }
      } catch (_) {}

      if (!savedToDownloads) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(jsonString, encoding: utf8);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/json')],
          subject: 'Acoustic Guitar – Song Book Backup',
          text: '🎸 Backup de ${songs.length} canciones',
        );
        _showSnack('✓ ${songs.length} canciones exportadas');
      }
    } catch (e) {
      _showSnack('Error al exportar: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ════════════════════════════════
  // IMPORTAR
  // ════════════════════════════════
  Future<void> _importSongs() async {
    setState(() => _isImporting = true);
    try {
      List<FileSystemEntity> backupFiles = [];

      if (Platform.isAndroid) {
        await Permission.storage.request();
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          backupFiles = downloadsDir
              .listSync()
              .where((f) =>
                  f is File &&
                  f.path.contains('acoustic_songbook') &&
                  f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => b.path.compareTo(a.path));
        }
      }

      setState(() => _isImporting = false);

      if (!mounted) return;

      if (backupFiles.isEmpty) {
        _showNoBackupDialog();
      } else {
        _showBackupFileList(backupFiles.cast<File>());
      }
    } catch (e) {
      setState(() => _isImporting = false);
      _showSnack('Error: $e');
    }
  }

  void _showNoBackupDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
        ),
        title: const Text("Sin backups",
          style: TextStyle(color: Color(0xFFE8C547), fontSize: 14, letterSpacing: 1)),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("No se encontró ningún archivo\nacoustic_songbook_*.json\nen tu carpeta Descargas.",
            style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              "1. Exporta primero desde otro dispositivo\n"
              "2. Copia el archivo .json a tu carpeta Descargas\n"
              "3. Vuelve a intentar importar",
              style: TextStyle(color: Colors.grey[600], fontSize: 10, height: 1.6),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido", style: TextStyle(color: Color(0xFFE8C547))),
          ),
        ],
      ),
    );
  }

  void _showBackupFileList(List<File> files) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.folder_open, color: Color(0xFFC4893A), size: 16),
            const SizedBox(width: 8),
            const Text("BACKUPS ENCONTRADOS",
              style: TextStyle(color: Color(0xFFC4893A), fontSize: 12,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Color(0xFF7A7568), size: 18)),
          ]),
          const SizedBox(height: 4),
          Text("en carpeta Descargas",
            style: TextStyle(color: Colors.grey[700], fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 14),
          ...files.map((file) {
            final name = file.path.split('/').last;
            final stat = file.statSync();
            final modified = stat.modified;
            final dateStr = "${modified.day.toString().padLeft(2,'0')}/"
                "${modified.month.toString().padLeft(2,'0')}/"
                "${modified.year}  "
                "${modified.hour.toString().padLeft(2,'0')}:"
                "${modified.minute.toString().padLeft(2,'0')}";
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _loadBackupFile(file);
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border.all(color: const Color(0x44C4893A)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(children: [
                  const Icon(Icons.description_outlined,
                    color: Color(0xFFC4893A), size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(
                        color: Color(0xFFE8E0CC), fontSize: 12,
                        fontFamily: 'monospace')),
                      const SizedBox(height: 2),
                      Text(dateStr, style: TextStyle(
                        color: Colors.grey[600], fontSize: 10)),
                    ])),
                  const Icon(Icons.chevron_right,
                    color: Color(0xFF7A7568), size: 18),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  void _loadBackupFile(File file) {
    try {
      final jsonString = file.readAsStringSync(encoding: utf8);
      final Map<String, dynamic> data = jsonDecode(jsonString);
      if (!data.containsKey('songs') || data['songs'] is! List) {
        _showSnack('⚠ Archivo inválido o corrupto');
        return;
      }
      final importedSongs = (data['songs'] as List)
          .map((j) => Song.fromJson(j)).toList();
      if (importedSongs.isEmpty) {
        _showSnack('⚠ El backup no contiene canciones');
        return;
      }
      _showImportDialog(importedSongs);
    } catch (e) {
      _showSnack('Error al leer el archivo: $e');
    }
  }

  void _showImportDialog(List<Song> importedSongs) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
        ),
        title: Row(children: [
          const Text("⬇", style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text("IMPORTAR", style: TextStyle(
            color: Color(0xFFE8C547), fontSize: 14,
            fontWeight: FontWeight.bold, letterSpacing: 2)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Se encontraron ${importedSongs.length} canción(es).",
            style: const TextStyle(color: Color(0xFFE8E0CC), fontSize: 13)),
          const SizedBox(height: 8),
          Text("Tienes ${songs.length} canción(es) actualmente.",
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 14),
          const Text("¿Cómo importar?",
            style: TextStyle(color: Color(0xFF7A7568), fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _doImport(importedSongs, replace: false);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0x1AE8C547),
                border: Border.all(color: const Color(0x55E8C547)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("COMBINAR", style: TextStyle(
                  color: Color(0xFFE8C547), fontSize: 12,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text("Agrega las canciones importadas a las existentes",
                  style: TextStyle(color: Colors.grey[600], fontSize: 10)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _doImport(importedSongs, replace: true);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0x1AE05252),
                border: Border.all(color: const Color(0x55E05252)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("REEMPLAZAR", style: TextStyle(
                  color: Color(0xFFE05252), fontSize: 12,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text("Borra las canciones actuales y carga las importadas",
                  style: TextStyle(color: Colors.grey[600], fontSize: 10)),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Color(0xFF7A7568))),
          ),
        ],
      ),
    );
  }

  void _doImport(List<Song> importedSongs, {required bool replace}) {
    setState(() {
      if (replace) {
        songs = importedSongs;
      } else {
        final existingIds = songs.map((s) => s.id).toSet();
        final newSongs = importedSongs.where((s) => !existingIds.contains(s.id)).toList();
        songs = [...songs, ...newSongs];
        final skipped = importedSongs.length - newSongs.length;
        if (skipped > 0) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _showSnack('$skipped canción(es) ya existían y se omitieron');
          });
        }
      }
    });
    _saveSongs();
    _showSnack('✓ ${importedSongs.length} canciones importadas');
  }

  List<Song> get filteredSongs => songs.where((s) {
    final mq = searchQuery.isEmpty || s.title.toLowerCase().contains(searchQuery.toLowerCase())
        || s.artist.toLowerCase().contains(searchQuery.toLowerCase());
    final mt = filterTone.isEmpty || s.tone == filterTone;
    return mq && mt;
  }).toList();

  // ════════════════════════════════════════════════════════
  // ★ NUEVO: MODAL DE TRANSPOSICIÓN DE CANCIÓN
  // ════════════════════════════════════════════════════════
  void _showTransposeModal(Song song) {
    String targetTone = kNotas.firstWhere(
      (n) => n != song.tone,
      orElse: () => 'G',
    );
    // Previsualización reactiva
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransposeSongSheet(
        song: song,
        initialTone: targetTone,
        onSaveNew: (transposed) {
          setState(() => songs.insert(0, transposed));
          _saveSongs();
          _showSnack('✓ Nueva versión guardada: ${transposed.title} en ${transposed.tone}');
        },
        onReplace: (transposed) {
          setState(() {
            final idx = songs.indexWhere((s) => s.id == song.id);
            if (idx != -1) {
              songs[idx] = Song(
                id: song.id,
                title: transposed.title,
                artist: transposed.artist,
                tone: transposed.tone,
                bpm: transposed.bpm,
                isMinor: transposed.isMinor,
                sections: transposed.sections,
                date: transposed.date,
              );
            }
          });
          _saveSongs();
          _showSnack('✓ Canción actualizada a tono ${transposed.tone}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFE8C547), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("♪ SONG BOOK",
          style: TextStyle(color: Color(0xFFE8C547), fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _showBackupMenu(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.sync_alt,
                    color: (_isExporting || _isImporting)
                        ? Colors.grey[600]!
                        : const Color(0xFFC4893A),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "BACKUP",
                    style: TextStyle(
                      color: (_isExporting || _isImporting)
                          ? Colors.grey[600]!
                          : const Color(0xFFC4893A),
                      fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _openForm(null),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8C547),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(child: Text("+",
                  style: TextStyle(color: Color(0xFF0D0D0D), fontSize: 22, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, Color(0xFFE8C547), Colors.transparent]))),
        ),
      ),
      body: Column(children: [
        Container(
          color: const Color(0xFF111111),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: TextField(
              style: const TextStyle(color: Color(0xFFF0ECE0), fontSize: 13),
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: "Buscar canción o artista...",
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7A7568), size: 18),
                filled: true, fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(4)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x55E8C547)), borderRadius: BorderRadius.circular(4)),
              ),
            )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
                border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(4)),
              child: DropdownButton<String>(
                value: filterTone.isEmpty ? null : filterTone,
                hint: const Text("Tono", style: TextStyle(color: Color(0xFF7A7568), fontSize: 12)),
                dropdownColor: const Color(0xFF1E1E1E), underline: const SizedBox(),
                style: const TextStyle(color: Color(0xFFE8C547), fontSize: 12, letterSpacing: 1),
                items: [
                  const DropdownMenuItem(value: '', child: Text("Todos", style: TextStyle(color: Color(0xFF7A7568)))),
                  ...kNotas.map((n) => DropdownMenuItem(value: n, child: Text(n))),
                ],
                onChanged: (v) => setState(() => filterTone = v ?? ''),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(children: [
            Text("CANCIONES", style: TextStyle(color: Colors.grey[700], fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0x22E8C547),
                border: Border.all(color: const Color(0x33E8C547)), borderRadius: BorderRadius.circular(20)),
              child: Text("${filteredSongs.length}", style: const TextStyle(color: Color(0xFFE8C547), fontSize: 11)),
            ),
            const Spacer(),
            Expanded(child: Container(height: 1, color: const Color(0xFF2A2A2A))),
          ]),
        ),
        Expanded(child: filteredSongs.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("𝄞", style: TextStyle(fontSize: 48, color: Color(0xFF2A2A2A))),
              const SizedBox(height: 12),
              Text("No hay canciones", style: TextStyle(color: Colors.grey[700], fontSize: 11, letterSpacing: 2)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              itemCount: filteredSongs.length,
              itemBuilder: (ctx, i) {
                final song = filteredSongs[i];
                final isExp = expandedId == song.id;
                return _songCard(song, isExp);
              },
            ),
        ),
      ]),
    );
  }

  void _showBackupMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.sync_alt, color: Color(0xFFC4893A), size: 16),
            const SizedBox(width: 8),
            const Text("BACKUP DE CANCIONES",
              style: TextStyle(color: Color(0xFFC4893A), fontSize: 12,
                fontWeight: FontWeight.bold, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Color(0xFF7A7568), size: 18),
            ),
          ]),
          const SizedBox(height: 6),
          Text("${songs.length} canción(es) guardadas actualmente",
            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _exportSongs();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0x55E8C547)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0x22E8C547),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(child: Icon(Icons.upload_file, color: Color(0xFFE8C547), size: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("EXPORTAR",
                    style: TextStyle(color: Color(0xFFE8C547), fontSize: 13,
                      fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 2),
                  Text("Guarda tus canciones como archivo .json\nCompartir por WhatsApp, Drive, correo...",
                    style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.4)),
                ])),
                const Icon(Icons.chevron_right, color: Color(0xFF7A7568), size: 18),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _importSongs();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0x55C4893A)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0x22C4893A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(child: Icon(Icons.download_for_offline_outlined, color: Color(0xFFC4893A), size: 20)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("IMPORTAR",
                    style: TextStyle(color: Color(0xFFC4893A), fontSize: 13,
                      fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 2),
                  Text("Carga un archivo .json exportado previamente\nCombinar o reemplazar canciones actuales",
                    style: TextStyle(color: Colors.grey[600], fontSize: 11, height: 1.4)),
                ])),
                const Icon(Icons.chevron_right, color: Color(0xFF7A7568), size: 18),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFF7A7568), size: 12),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "El backup incluye todas tus canciones, secciones, acordes y letra. Úsalo antes de desinstalar la app.",
                style: TextStyle(color: Colors.grey[700], fontSize: 10, height: 1.4),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _songCard(Song song, bool isExpanded) {
    final totalChords = {...song.sections.expand((s) => s.chords)}.toList();
    return GestureDetector(
      onTap: () => setState(() => expandedId = isExpanded ? null : song.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          border: Border.all(color: isExpanded ? const Color(0x55E8C547) : const Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IntrinsicHeight(
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 2,
                decoration: BoxDecoration(
                  color: isExpanded ? const Color(0xFFE8C547) : Colors.transparent,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                ),
              ),
              Expanded(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0x1AE8C547),
                      border: Border.all(color: const Color(0x44E8C547)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(child: Text(song.tone,
                      style: const TextStyle(color: Color(0xFFE8C547), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(song.title, style: const TextStyle(color: Color(0xFFE8E0CC), fontSize: 16, fontWeight: FontWeight.w400),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (song.artist.isNotEmpty)
                      Text(song.artist, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, children: [
                      if (song.bpm.isNotEmpty) _metaTag("♩ ${song.bpm} BPM"),
                      _metaTag(song.isMinor ? "● menor" : "● mayor"),
                      if (song.sections.isNotEmpty) _metaTag("${song.sections.length} secciones"),
                      if (totalChords.isNotEmpty) _metaTag("${totalChords.length} acordes"),
                    ]),
                  ])),
                  // ★ Botones de acción: transponer + editar + eliminar
                  Column(children: [
                    _actionBtn(Icons.swap_horiz, const Color(0xFF5BB8E8), () => _showTransposeModal(song)),
                    const SizedBox(height: 4),
                    _actionBtn(Icons.edit_outlined, const Color(0xFFE8C547), () => _openForm(song)),
                    const SizedBox(height: 4),
                    _actionBtn(Icons.close, const Color(0xFFE05252), () => _confirmDelete(song)),
                  ]),
                ]),
              )),
            ]),
          ),
          if (isExpanded && song.sections.isNotEmpty) ...[
            Container(height: 1, color: const Color(0xFF2A2A2A)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("ESTRUCTURA", style: TextStyle(color: Colors.grey[700], fontSize: 9, letterSpacing: 3)),
                const SizedBox(height: 10),
                ...song.sections.map((sec) => _dispSection(sec)),
                Text("Guardada el ${song.date}", style: TextStyle(color: Colors.grey[700], fontSize: 10, letterSpacing: 1)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _metaTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
      border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(2)),
    child: Text(text, style: const TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 1)),
  );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2A2A2A)),
        color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(3)),
      child: Icon(icon, color: color.withOpacity(0.7), size: 14),
    ),
  );

  Widget _dispSection(SongSection sec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(sec.name.toUpperCase(), style: const TextStyle(color: Color(0xFFE8C547), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: const Color(0x22E8C547))),
        ]),
        if (sec.chords.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4,
            children: sec.chords.map((c) {
              final isMin = c.endsWith('m') && !c.endsWith('#m');
              final isDim = c.contains('°');
              final color = isDim ? const Color(0xFFE05252) : isMin ? const Color(0xFFC4893A) : const Color(0xFFE8C547);
              final bg    = isDim ? const Color(0x12E05252) : isMin ? const Color(0x12C4893A) : const Color(0x12E8C547);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: bg, border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(2)),
                child: Text(c, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              );
            }).toList()),
        ],
        if (sec.lyrics.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(sec.lyrics, style: const TextStyle(color: Color(0xFF8A806A), fontSize: 13, fontStyle: FontStyle.italic, height: 1.6)),
        ],
      ]),
    );
  }

  void _confirmDelete(Song song) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(4)),
      title: const Text("Eliminar canción", style: TextStyle(color: Color(0xFFE8C547), fontSize: 15, letterSpacing: 1)),
      content: Text('¿Eliminar "${song.title}"?', style: const TextStyle(color: Color(0xFF8A8070), fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Color(0xFF7A7568)))),
        TextButton(
          onPressed: () { Navigator.pop(context); _deleteSong(song.id); },
          child: const Text("Eliminar", style: TextStyle(color: Color(0xFFE05252))),
        ),
      ],
    ));
  }

  void _openForm(Song? existing) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => SongFormPage(existing: existing, onSave: (song) {
        setState(() {
          if (existing == null) {
            songs.insert(0, song);
          } else {
            final idx = songs.indexWhere((s) => s.id == song.id);
            if (idx != -1) songs[idx] = song;
          }
        });
        _saveSongs();
        _showSnack(existing == null ? '✓ Canción guardada' : '✓ Cambios guardados');
      }),
    ));
  }
}

// ═══════════════════════════════════════════════
// ★ NUEVO: WIDGET DE TRANSPOSICIÓN DE CANCIÓN
// ═══════════════════════════════════════════════
class _TransposeSongSheet extends StatefulWidget {
  final Song song;
  final String initialTone;
  final void Function(Song) onSaveNew;
  final void Function(Song) onReplace;

  const _TransposeSongSheet({
    required this.song,
    required this.initialTone,
    required this.onSaveNew,
    required this.onReplace,
  });

  @override
  State<_TransposeSongSheet> createState() => _TransposeSongSheetState();
}

class _TransposeSongSheetState extends State<_TransposeSongSheet> {
  late String _targetTone;
  late Song _preview;

  @override
  void initState() {
    super.initState();
    _targetTone = widget.initialTone;
    _preview = transposeSong(widget.song, _targetTone);
  }

  void _updateTone(String tone) {
    setState(() {
      _targetTone = tone;
      _preview = transposeSong(widget.song, tone);
    });
  }

  /// Returns how many semitones apart (interval label)
  String _intervalLabel(String from, String to) {
    final fromIdx = kNotas.indexOf(from);
    final toIdx   = kNotas.indexOf(to);
    if (fromIdx == -1 || toIdx == -1) return '';
    final diff = (toIdx - fromIdx + 12) % 12;
    if (diff == 0) return 'mismo tono';
    const names = ['','½ tono','1 tono','1½','2 tonos','2½','3 tonos','3½','4 tonos','4½','5 tonos','5½'];
    return '↑ ${names[diff]}';
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final isSame = _targetTone == song.tone;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(children: [
              const Icon(Icons.swap_horiz, color: Color(0xFF5BB8E8), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("TRANSPORTAR CANCIÓN",
                  style: TextStyle(color: Color(0xFF5BB8E8), fontSize: 12,
                    fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text(song.title, style: const TextStyle(color: Color(0xFFE8E0CC), fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Color(0xFF7A7568), size: 20),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // Tono origen → destino
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                border: Border.all(color: const Color(0xFF2A2A2A)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                // Origen
                Column(children: [
                  const Text("ORIGEN", style: TextStyle(color: Color(0xFF7A7568), fontSize: 8, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x22E8C547),
                      border: Border.all(color: const Color(0xFFE8C547)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text(song.tone,
                      style: const TextStyle(color: Color(0xFFE8C547), fontSize: 20,
                        fontWeight: FontWeight.bold, letterSpacing: 1))),
                  ),
                  const SizedBox(height: 4),
                  Text(song.isMinor ? "menor" : "mayor",
                    style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                ]),

                // Flecha + intervalo
                Expanded(child: Column(children: [
                  const Icon(Icons.arrow_forward, color: Color(0xFF5BB8E8), size: 20),
                  const SizedBox(height: 4),
                  Text(_intervalLabel(song.tone, _targetTone),
                    style: const TextStyle(color: Color(0xFF5BB8E8), fontSize: 9, letterSpacing: 1),
                    textAlign: TextAlign.center),
                ])),

                // Destino
                Column(children: [
                  const Text("DESTINO", style: TextStyle(color: Color(0xFF7A7568), fontSize: 8, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: isSame ? const Color(0x11FFFFFF) : const Color(0x225BB8E8),
                      border: Border.all(
                        color: isSame ? const Color(0xFF3A3A3A) : const Color(0xFF5BB8E8)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text(_targetTone,
                      style: TextStyle(
                        color: isSame ? Colors.grey[600]! : const Color(0xFF5BB8E8),
                        fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1))),
                  ),
                  const SizedBox(height: 4),
                  Text(song.isMinor ? "menor" : "mayor",
                    style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                ]),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          // Selector de tono
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("SELECCIONA EL TONO DESTINO",
                style: TextStyle(color: Color(0xFF7A7568), fontSize: 8, letterSpacing: 2)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6,
                children: kNotas.map((n) {
                  final isCurrent = n == song.tone;
                  final isSel     = n == _targetTone;
                  return GestureDetector(
                    onTap: () => _updateTone(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: isSel
                            ? (isCurrent ? const Color(0xFF3A3A3A) : const Color(0xFF5BB8E8))
                            : (isCurrent ? const Color(0x22E8C547) : const Color(0xFF1E1E1E)),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFE8C547)
                              : isSel
                                  ? const Color(0xFF5BB8E8)
                                  : const Color(0xFF2A2A2A)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(child: Text(n,
                        style: TextStyle(
                          color: isSel
                              ? (isCurrent ? Colors.grey[500]! : const Color(0xFF0D0D0D))
                              : (isCurrent ? const Color(0xFFE8C547) : Colors.grey[500]!),
                          fontWeight: FontWeight.bold,
                          fontSize: n.contains('#') ? 9 : 11))),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFF2A2A2A)),

          // Preview de acordes transpuestos
          Expanded(child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            children: [
              if (isSame)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text("Selecciona un tono diferente para ver la transposición",
                    style: TextStyle(color: Color(0xFF7A7568), fontSize: 12),
                    textAlign: TextAlign.center),
                )
              else ...[
                const Text("VISTA PREVIA",
                  style: TextStyle(color: Color(0xFF7A7568), fontSize: 8, letterSpacing: 3)),
                const SizedBox(height: 10),
                ..._preview.sections.map((sec) => _previewSection(song, sec)),
              ],
            ],
          )),

          // Botones de acción
          if (!isSame) Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF161616),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(children: [
              // Guardar como nueva versión
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onSaveNew(_preview);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF5BB8E8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Column(children: [
                    Text("GUARDAR COPIA", style: TextStyle(
                      color: Color(0xFF5BB8E8), fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
                    SizedBox(height: 2),
                    Text("nueva versión", style: TextStyle(
                      color: Color(0xFF3A6A80), fontSize: 9)),
                  ]),
                ),
              )),
              const SizedBox(width: 10),
              // Reemplazar tono actual
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onReplace(_preview);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0x225BB8E8),
                    border: Border.all(color: const Color(0xFF5BB8E8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(children: [
                    const Text("REEMPLAZAR", style: TextStyle(
                      color: Color(0xFF5BB8E8), fontSize: 11,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text("sobreescribir en ${song.tone}",
                      style: const TextStyle(color: Color(0xFF3A6A80), fontSize: 9)),
                  ]),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // Vista previa de una sección comparando original vs transpuesto
  Widget _previewSection(Song original, SongSection transposed) {
    // Encontrar la sección original correspondiente
    final origSec = original.sections.firstWhere(
      (s) => s.name == transposed.name,
      orElse: () => SongSection(name: transposed.name),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera sección
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(
            color: Color(0x0A5BB8E8),
            border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
          ),
          child: Text(transposed.name.toUpperCase(),
            style: const TextStyle(color: Color(0xFF5BB8E8), fontSize: 9,
              letterSpacing: 2, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (transposed.chords.isNotEmpty) ...[
              // Fila original
              Row(children: [
                Container(
                  width: 40,
                  child: Text(original.tone,
                    style: const TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 1)),
                ),
                Expanded(child: Wrap(spacing: 4, runSpacing: 4,
                  children: origSec.chords.map((c) => _chordPill(c, dimmed: true)).toList())),
              ]),
              const SizedBox(height: 6),
              // Fila transpuesta
              Row(children: [
                Container(
                  width: 40,
                  child: Text(_targetTone,
                    style: const TextStyle(color: Color(0xFF5BB8E8), fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                Expanded(child: Wrap(spacing: 4, runSpacing: 4,
                  children: transposed.chords.map((c) => _chordPill(c, dimmed: false)).toList())),
              ]),
            ],
            if (transposed.lyrics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(transposed.lyrics,
                style: const TextStyle(color: Color(0xFF6A6050), fontSize: 12,
                  fontStyle: FontStyle.italic, height: 1.5)),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _chordPill(String chord, {required bool dimmed}) {
    final isMin = chord.endsWith('m') && !chord.endsWith('#m');
    final isDim = chord.contains('°');
    Color color;
    if (dimmed) {
      color = Colors.grey[700]!;
    } else {
      color = isDim ? const Color(0xFFE05252) : isMin ? const Color(0xFFC4893A) : const Color(0xFFE8C547);
    }
    final bg = dimmed ? const Color(0x08FFFFFF) : color.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: color.withOpacity(dimmed ? 0.2 : 0.45)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(chord, style: TextStyle(
        color: color, fontSize: 11,
        fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    );
  }
}

// ═══════════════════════════════════════════════
// SONG FORM PAGE (Agregar / Editar)
// ═══════════════════════════════════════════════
class SongFormPage extends StatefulWidget {
  final Song? existing;
  final void Function(Song) onSave;
  const SongFormPage({super.key, this.existing, required this.onSave});
  @override
  State<SongFormPage> createState() => _SongFormPageState();
}

class _SongFormPageState extends State<SongFormPage> {
  final _titleCtrl  = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _bpmCtrl    = TextEditingController();
  String selectedTone = 'C';
  bool   selectedMinor = false;
  List<SongSection> sections = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _titleCtrl.text  = s.title;
      _artistCtrl.text = s.artist;
      _bpmCtrl.text    = s.bpm;
      selectedTone     = s.tone;
      selectedMinor    = s.isMinor;
      sections = s.sections.map((sec) => SongSection(name: sec.name, chords: List.from(sec.chords), lyrics: sec.lyrics)).toList();
    }
  }

  void _addSection(String name) {
    setState(() => sections.add(SongSection(name: name.isEmpty ? 'Sección' : name)));
  }

  void _removeSection(int idx) => setState(() => sections.removeAt(idx));

  void _addChordToSection(int idx, String chord) {
    setState(() => sections[idx].chords.add(chord));
  }

  void _removeChordFromSection(int idx, int ci) {
    setState(() => sections[idx].chords.removeAt(ci));
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠ Escribe el título")));
      return;
    }
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠ Agrega al menos una sección")));
      return;
    }
    final now = DateTime.now();
    final song = Song(
      id: widget.existing?.id ?? now.millisecondsSinceEpoch,
      title: title,
      artist: _artistCtrl.text.trim(),
      tone: selectedTone,
      bpm: _bpmCtrl.text.trim(),
      isMinor: selectedMinor,
      sections: sections,
      date: "${now.day.toString().padLeft(2,'0')} ${_mes(now.month)} ${now.year}",
    );
    widget.onSave(song);
    Navigator.pop(context);
  }

  String _mes(int m) => ["ene","feb","mar","abr","may","jun","jul","ago","sep","oct","nov","dic"][m-1];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFE8C547), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(widget.existing == null ? "NUEVA CANCIÓN" : "EDITAR CANCIÓN",
          style: const TextStyle(color: Color(0xFFE8C547), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, Color(0xFFE8C547), Colors.transparent]))),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _fieldLabel("Título"),
          _textField(_titleCtrl, "Nombre de la canción"),
          const SizedBox(height: 12),
          _fieldLabel("Artista / Banda"),
          _textField(_artistCtrl, "Opcional"),
          const SizedBox(height: 12),
          _fieldLabel("Tonalidad"),
          const SizedBox(height: 6),
          _toneGrid(),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF2A2A2A)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() { selectedMinor = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: !selectedMinor ? const Color(0xFFE8C547) : Colors.transparent,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)),
                  ),
                  child: Center(child: Text("MAYOR", style: TextStyle(
                    color: !selectedMinor ? const Color(0xFF0D0D0D) : Colors.grey[600],
                    fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2))),
                ),
              )),
              Expanded(child: GestureDetector(
                onTap: () => setState(() { selectedMinor = true; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selectedMinor ? const Color(0xFFC4893A) : Colors.transparent,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
                  ),
                  child: Center(child: Text("MENOR", style: TextStyle(
                    color: selectedMinor ? const Color(0xFF0D0D0D) : Colors.grey[600],
                    fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2))),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          _fieldLabel("BPM"),
          _textField(_bpmCtrl, "Ej: 120", keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          Row(children: [
            Text("ESTRUCTURA", style: TextStyle(color: Colors.grey[600], fontSize: 9, letterSpacing: 3)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: const Color(0xFF2A2A2A))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6,
            children: ['Intro','Verso','Precoro','Coro','Puente','Outro'].map((name) =>
              GestureDetector(
                onTap: () => _addSection(name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
                    border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(2)),
                  child: Text("+ $name", style: const TextStyle(color: Color(0xFFC4893A), fontSize: 11, letterSpacing: 1)),
                ),
              )
            ).toList(),
          ),
          const SizedBox(height: 10),
          ...List.generate(sections.length, (i) => _sectionBlock(i)),
          GestureDetector(
            onTap: () => _addSection(''),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2A2A2A), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(3)),
              child: const Center(child: Text("+ Sección personalizada",
                style: TextStyle(color: Color(0xFF7A7568), fontSize: 11, letterSpacing: 1))),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: const Color(0xFFE8C547), borderRadius: BorderRadius.circular(4),
                boxShadow: [const BoxShadow(color: Color(0x33E8C547), blurRadius: 16, offset: Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("💾  ", style: TextStyle(fontSize: 16)),
                Text("GUARDAR CANCIÓN", style: TextStyle(color: Color(0xFF0D0D0D),
                  fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 3)),
              ]),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sectionBlock(int idx) {
    final sec = sections[idx];
    final scaleChords = getScaleChords(selectedTone, minor: selectedMinor);
    final modeLabel = selectedMinor ? "MENOR" : "MAYOR";
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: const Color(0xFF161616),
        border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(color: Color(0x0AE8C547),
            border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A)))),
          child: Row(children: [
            const Icon(Icons.drag_indicator, color: Color(0xFF7A7568), size: 16),
            const SizedBox(width: 6),
            Expanded(child: DropdownButton<String>(
              value: kSectionNames.contains(sec.name) ? sec.name : kSectionNames.last,
              dropdownColor: const Color(0xFF1E1E1E), underline: const SizedBox(),
              style: const TextStyle(color: Color(0xFFE8C547), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
              items: kSectionNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
              onChanged: (v) => setState(() => sec.name = v ?? sec.name),
            )),
            GestureDetector(
              onTap: () => _removeSection(idx),
              child: Container(width: 24, height: 24,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(2)),
                child: const Icon(Icons.close, color: Color(0xFF7A7568), size: 12)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (sec.chords.isNotEmpty) Wrap(
              spacing: 4, runSpacing: 4,
              children: List.generate(sec.chords.length, (ci) {
                final c = sec.chords[ci];
                final isMin = c.endsWith('m') && !c.endsWith('#m');
                final isDim = c.contains('°');
                final color = isDim ? const Color(0xFFE05252) : isMin ? const Color(0xFFC4893A) : const Color(0xFFE8C547);
                return GestureDetector(
                  onTap: () => _removeChordFromSection(idx, ci),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withOpacity(0.12),
                      border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(2)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(c, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const SizedBox(width: 4),
                      Icon(Icons.close, color: color.withOpacity(0.5), size: 10),
                    ]),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text("ESCALA $modeLabel DE $selectedTone", style: TextStyle(color: Colors.grey[700], fontSize: 8, letterSpacing: 2)),
            const SizedBox(height: 5),
            Wrap(
              spacing: 4, runSpacing: 4,
              children: scaleChords.map((chord) {
                final color = colorTipo(chord["type"]!);
                return GestureDetector(
                  onTap: () => _addChordToSection(idx, chord["label"]!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(chord["label"]!,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Color(0xFFF0ECE0), fontSize: 12, fontFamily: 'monospace', letterSpacing: 1),
              decoration: InputDecoration(
                hintText: "Otro acorde (Enter para agregar)...",
                hintStyle: TextStyle(color: Colors.grey[700], fontSize: 11, fontStyle: FontStyle.italic),
                filled: true, fillColor: const Color(0xFF0D0D0D),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(3)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x44E8C547)), borderRadius: BorderRadius.circular(3)),
              ),
              onSubmitted: (v) {
                final chord = v.trim();
                if (chord.isNotEmpty) _addChordToSection(idx, chord);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: sec.lyrics),
              style: const TextStyle(color: Color(0xFFA09880), fontSize: 13, fontStyle: FontStyle.italic, height: 1.6),
              maxLines: null, minLines: 2,
              onChanged: (v) => sec.lyrics = v,
              decoration: InputDecoration(
                hintText: "Letra de esta sección (opcional)...",
                hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic),
                filled: true, fillColor: const Color(0xFF0D0D0D),
                contentPadding: const EdgeInsets.all(10),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0x22E8C547), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(3)),
                focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x44E8C547)), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ]),
    );
  }

  Widget _toneGrid() => Wrap(
    spacing: 5, runSpacing: 5,
    children: kNotas.map((n) {
      final sel = n == selectedTone;
      return GestureDetector(
        onTap: () => setState(() => selectedTone = n),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: sel ? const Color(0xFFE8C547) : const Color(0xFF1E1E1E),
            border: Border.all(color: sel ? const Color(0xFFE8C547) : const Color(0xFF2A2A2A)),
            borderRadius: BorderRadius.circular(3),
            boxShadow: sel ? [const BoxShadow(color: Color(0x44E8C547), blurRadius: 8)] : [],
          ),
          child: Center(child: Text(n, style: TextStyle(
            color: sel ? const Color(0xFF0D0D0D) : Colors.grey[500],
            fontWeight: FontWeight.bold, fontSize: n.contains('#') ? 9 : 11))),
        ),
      );
    }).toList(),
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(color: Color(0xFF7A7568), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)),
  );

  Widget _textField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    style: const TextStyle(color: Color(0xFFF0ECE0), fontSize: 14),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
      filled: true, fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF2A2A2A)), borderRadius: BorderRadius.circular(3)),
      focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0x88E8C547)), borderRadius: BorderRadius.circular(3)),
    ),
  );
}