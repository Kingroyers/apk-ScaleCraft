import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
// MUSIC THEORY HELPERS (compartido entre pantallas)
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
  bool _isMinor = false;  // ← toggle Mayor / Menor

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

  // ── LÓGICA ──
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

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        centerTitle: true,
        title: const Text("🎸 ACOUSTIC GUITAR",
          style: TextStyle(color: Color(0xFFE8C547), fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16)),
        // ── SONG BOOK BUTTON ──
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
        // ── BADGE MODO ──
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

      // ── Toggle Mayor / Menor ──
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

  List<Song> get filteredSongs => songs.where((s) {
    final mq = searchQuery.isEmpty || s.title.toLowerCase().contains(searchQuery.toLowerCase())
        || s.artist.toLowerCase().contains(searchQuery.toLowerCase());
    final mt = filterTone.isEmpty || s.tone == filterTone;
    return mq && mt;
  }).toList();

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
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _openForm(null),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8C547),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(child: Text("+", style: TextStyle(color: Color(0xFF0D0D0D), fontSize: 22, fontWeight: FontWeight.bold))),
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
        // Search + filter bar
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
        // Count bar
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
        // List
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
          // Left accent bar + header
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
                  // Tone badge
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
                  // Info
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
                  // Actions
                  Column(children: [
                    _actionBtn(Icons.edit_outlined, const Color(0xFFE8C547), () => _openForm(song)),
                    const SizedBox(height: 4),
                    _actionBtn(Icons.close, const Color(0xFFE05252), () => _confirmDelete(song)),
                  ]),
                ]),
              )),
            ]),
          ),
          // Expanded sections
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
  bool   selectedMinor = false;   // ← NUEVO
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
      selectedMinor    = s.isMinor;   // ← NUEVO
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

          // Título y artista
          _fieldLabel("Título"),
          _textField(_titleCtrl, "Nombre de la canción"),
          const SizedBox(height: 12),
          _fieldLabel("Artista / Banda"),
          _textField(_artistCtrl, "Opcional"),
          const SizedBox(height: 12),

          // Tonalidad
          _fieldLabel("Tonalidad"),
          const SizedBox(height: 6),
          _toneGrid(),
          const SizedBox(height: 10),

          // Toggle Mayor / Menor
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

          // BPM
          _fieldLabel("BPM"),
          _textField(_bpmCtrl, "Ej: 120", keyboardType: TextInputType.number),
          const SizedBox(height: 20),

          // Secciones
          Row(children: [
            Text("ESTRUCTURA", style: TextStyle(color: Colors.grey[600], fontSize: 9, letterSpacing: 3)),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: const Color(0xFF2A2A2A))),
          ]),
          const SizedBox(height: 10),

          // Quick add buttons
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

          // Section blocks
          ...List.generate(sections.length, (i) => _sectionBlock(i)),

          // Add custom section
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

          // Save button
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
        // Header
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

        // Chord pills
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Added chords
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

            // Scale chord picker
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

            // Free chord input
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

            // Lyrics
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
