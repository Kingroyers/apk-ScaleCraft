class SongSection {
  String title; // Cambiado de 'name' a 'title' para consistencia
  List<String> chords;
  String lyrics;

  SongSection({
    required this.title, 
    List<String>? chords, 
    this.lyrics = '', required String rawContent
  }) : chords = chords ?? [];

  // Actualiza también el JSON
  Map<String, dynamic> toJson() => {
    'title': title, 
    'chords': chords, 
    'lyrics': lyrics
  };

  factory SongSection.fromJson(Map<String, dynamic> j) => SongSection(
    title: j['title'] ?? j['name'] ?? '', // Soporta ambos por si acaso
    chords: List<String>.from(j['chords'] ?? []), 
    lyrics: j['lyrics'] ?? '', rawContent: j['rawContent'] ?? ''
  );

  String? get rawContent => null;
}