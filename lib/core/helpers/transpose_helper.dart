import '../../models/song.dart';
import '../../models/song_section.dart';
import '../constants.dart';

class TransposeHelper {
  static Song transposeSong(Song song, String newTone) {
    final oldIdx = kNotas.indexOf(song.tone);
    final newIdx = kNotas.indexOf(newTone);
    
    if (oldIdx == -1 || newIdx == -1) return song;
    int semitones = newIdx - oldIdx;

    final transposedSections = song.sections.map((section) {
      final transposedChords = section.chords.map((chord) {
        return _transposeChordString(chord, semitones);
      }).toList();
      
      return SongSection(
        title: section.title, // Usa 'title' aquí
        chords: transposedChords,
        lyrics: section.lyrics, rawContent: '',
      );
    }).toList();

    return song.copyWith(tone: newTone, sections: transposedSections);
  }

  static String _transposeChordString(String chord, int semitones) {
    final match = RegExp(r'^([A-G][#b]?)([^/]*)(/([A-G][#b]?))?$').firstMatch(chord);
    if (match == null) return chord;

    String root = match.group(1)!;
    String suffix = match.group(2) ?? "";
    String? bassNote = match.group(4);

    String newRoot = _shiftNote(root, semitones);
    String newBass = (bassNote != null) ? "/${_shiftNote(bassNote, semitones)}" : "";

    return newRoot + suffix + newBass;
  }

  static String _shiftNote(String note, int semitones) {
    int idx = kNotas.indexOf(note);
    if (idx == -1) return note;
    int nextIdx = (idx + semitones) % 12;
    if (nextIdx < 0) nextIdx += 12;
    return kNotas[nextIdx];
  }
}