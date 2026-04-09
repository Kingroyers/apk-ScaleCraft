import 'song_section.dart';

class Song {
  final int id;
  final String title;
  final String artist;
  final String tone;
  final int bpm;
  final bool isMinor;
  final List<SongSection> sections;
  final String date;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.tone,
    required this.bpm,
    required this.isMinor,
    required this.sections,
    required this.date,
  });

  Song copyWith({String? tone, List<SongSection>? sections}) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      tone: tone ?? this.tone,
      bpm: bpm,
      isMinor: isMinor,
      sections: sections ?? this.sections,
      date: date,
    );
  }
}