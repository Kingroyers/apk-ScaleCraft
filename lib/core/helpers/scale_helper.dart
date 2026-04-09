import '../constants.dart';

List<String> generarEscala(String tono, {bool minor = false}) {
  int pos = kNotas.indexOf(tono);
  List<String> esc = [kNotas[pos]];
  final formula = minor ? kFormulaMinor : kFormula;
  for (int paso in formula) {
    pos = (pos + paso) % 12;
    esc.add(kNotas[pos]);
  }
  return esc;
}

List<Map<String, String>> getScaleChords(String tono, {bool minor = false}) {
  final esc = generarEscala(tono, minor: minor);
  final qualities = minor ? kQualitiesMinor : kQualities;
  return List.generate(7, (i) => {
    "label": esc[i],
    "note": esc[i],
    "type": qualities[i],
    "degree": kGrados[i],
  });
}
