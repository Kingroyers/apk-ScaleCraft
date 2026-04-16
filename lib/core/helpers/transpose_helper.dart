class TransposeHelper {
  static const List<String> _notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  static const Map<String, String> _enharmonics = {
    'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#',
    'Ab': 'G#', 'Bb': 'A#', 'Cb': 'B',
  };

  // Todas las notas válidas como tono base
  static const List<String> allKeys = [
    'C', 'C#', 'D', 'Eb', 'E', 'F',
    'F#', 'G', 'Ab', 'A', 'Bb', 'B',
    'Cm', 'Dm', 'Em', 'Fm', 'Gm', 'Am', 'Bm',
  ];

  // Transpone un acorde individual de fromKey a toKey
  static String transposeChord(String chord, String fromKey, String toKey) {
    if (fromKey == toKey) return chord;
    final semitones = _semitoneDiff(fromKey, toKey);
    return _shiftChord(chord, semitones);
  }

  // Transpone toda una línea de acordes
  static Map<int, String> transposeLine(
    Map<int, String> chords,
    String fromKey,
    String toKey,
  ) {
    if (fromKey == toKey) return chords;
    return chords.map(
      (pos, chord) => MapEntry(pos, transposeChord(chord, fromKey, toKey)),
    );
  }

  static int _semitoneDiff(String from, String to) {
    final a = _noteIndex(_rootNote(from));
    final b = _noteIndex(_rootNote(to));
    return (b - a + 12) % 12;
  }

  static String _shiftChord(String chord, int semitones) {
    if (semitones == 0) return chord;

    // Extraer la nota raíz (ej: "Am7" → raíz "A", sufijo "m7")
    final match = RegExp(r'^([A-G][#b]?)(.*)$').firstMatch(chord);
    if (match == null) return chord;

    final root = match.group(1)!;
    final suffix = match.group(2)!;

    final normalized = _enharmonics[root] ?? root;
    final idx = _noteIndex(normalized);
    if (idx == -1) return chord;

    final newIdx = (idx + semitones) % 12;
    return '${_notes[newIdx]}$suffix';
  }

  static String _rootNote(String key) {
    // "Am" → "A", "C#" → "C#", "Bb" → "Bb"
    final match = RegExp(r'^([A-G][#b]?)').firstMatch(key);
    return match?.group(1) ?? key;
  }

  static int _noteIndex(String note) {
    final normalized = _enharmonics[note] ?? note;
    return _notes.indexOf(normalized);
  }
}