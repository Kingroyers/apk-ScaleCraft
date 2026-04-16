class ChordedLine {
  final String lyrics;

  // key = índice de carácter donde empieza el acorde
  // ej: { 0: 'Am', 8: 'G', 15: 'C' }
  final Map<int, String> chords;

  const ChordedLine({
    required this.lyrics,
    this.chords = const {},
  });

  ChordedLine copyWith({String? lyrics, Map<int, String>? chords}) {
    return ChordedLine(
      lyrics: lyrics ?? this.lyrics,
      chords: chords ?? this.chords,
    );
  }

  factory ChordedLine.fromJson(Map<String, dynamic> json) {
    return ChordedLine(
      lyrics: json['lyrics'] as String,
      chords: (json['chords'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'lyrics': lyrics,
        'chords': chords.map((k, v) => MapEntry(k.toString(), v)),
      };
}