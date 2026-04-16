import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/songbook_service.dart';
import '../models/song.dart';

// ── Servicio ─────────────────────────────────────────────────────────────────

final songbookServiceProvider = Provider<SongbookService>((ref) {
  return SongbookService();
});

// ── Lista de canciones ────────────────────────────────────────────────────────

final songsProvider = AsyncNotifierProvider<SongsNotifier, List<Song>>(
  SongsNotifier.new,
);

class SongsNotifier extends AsyncNotifier<List<Song>> {
  @override
  Future<List<Song>> build() async {
    return ref.read(songbookServiceProvider).getSongs();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(songbookServiceProvider).getSongs(),
    );
  }

  Future<void> addSong(Song song) async {
    final service = ref.read(songbookServiceProvider);
    final created = await service.createSong(song);
    state = AsyncData([...state.value ?? [], created]);
  }

  Future<void> updateSong(Song song) async {
    final service = ref.read(songbookServiceProvider);
    final updated = await service.updateSong(song);
    state = AsyncData([
      for (final s in state.value ?? [])
        if (s.id == updated.id) updated else s,
    ]);
  }

  Future<void> deleteSong(String id) async {
    final service = ref.read(songbookServiceProvider);
    await service.deleteSong(id);
    state = AsyncData(
      (state.value ?? []).where((s) => s.id != id).toList(),
    );
  }
}

// ── Búsqueda y filtro ─────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedTagProvider = StateProvider<String?>((ref) => null);

final filteredSongsProvider = Provider<List<Song>>((ref) {
  final songs = ref.watch(songsProvider).value ?? [];
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final tag = ref.watch(selectedTagProvider);

  return songs.where((song) {
    final matchesQuery = query.isEmpty ||
        song.title.toLowerCase().contains(query) ||
        song.artist.toLowerCase().contains(query);
    final matchesTag = tag == null || song.tags.contains(tag);
    return matchesQuery && matchesTag;
  }).toList();
});

// ── Tono activo en la vista de canción ────────────────────────────────────────

final activeSongKeyProvider =
    StateProvider.family<String, String>((ref, songId) => '');
// Se inicializa con el originalKey de la canción al abrir la vista