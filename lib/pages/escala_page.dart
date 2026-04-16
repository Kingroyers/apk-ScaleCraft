import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/helpers/chord_helper.dart';
import '../core/helpers/scale_helper.dart';
import 'songbook_page.dart';

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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SongbookPage())),
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
