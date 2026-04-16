import 'chorded_line.dart';

class SongSection {
  final String name; // "Verso 1", "Coro", "Puente"
  final List<ChordedLine> lines;

  const SongSection({
    required this.name,
    this.lines = const [],
  });

  SongSection copyWith({String? name, List<ChordedLine>? lines}) {
    return SongSection(
      name: name ?? this.name,
      lines: lines ?? this.lines,
    );
  }

  factory SongSection.fromJson(Map<String, dynamic> json) {
    return SongSection(
      name: json['name'] as String,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((l) => ChordedLine.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}