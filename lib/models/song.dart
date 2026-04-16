import 'song_section.dart';

class Song {
  final String? id;
  final String title;
  final String artist;
  final String originalKey; // 'Am', 'G', 'C', etc.
  final int capo;
  final List<String> tags; // ['Alabanza', 'Adoración']
  final List<SongSection> sections;
  final DateTime? createdAt;

  const Song({
    this.id,
    required this.title,
    required this.artist,
    required this.originalKey,
    this.capo = 0,
    this.tags = const [],
    this.sections = const [],
    this.createdAt,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? originalKey,
    int? capo,
    List<String>? tags,
    List<SongSection>? sections,
    DateTime? createdAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      originalKey: originalKey ?? this.originalKey,
      capo: capo ?? this.capo,
      tags: tags ?? this.tags,
      sections: sections ?? this.sections,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String?,
      title: json['title'] as String,
      artist: json['artist'] as String? ?? '',
      originalKey: json['original_key'] as String? ?? 'C',
      capo: json['capo'] as int? ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? []),
      sections: (json['sections'] as List<dynamic>? ?? [])
          .map((s) => SongSection.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'artist': artist,
        'original_key': originalKey,
        'capo': capo,
        'tags': tags,
        'sections': sections.map((s) => s.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
      };

  // Canción vacía para el editor
  static Song empty() => const Song(
        title: '',
        artist: '',
        originalKey: 'C',
        sections: [],
      );
}