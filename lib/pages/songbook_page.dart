import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../models/song.dart';
import 'song_view_page.dart';
import 'song_editor_page.dart';

class SongbookPage extends ConsumerWidget {
  const SongbookPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final filtered = ref.watch(filteredSongsProvider);
    final query = ref.watch(searchQueryProvider);
    final selectedTag = ref.watch(selectedTagProvider);
    final theme = Theme.of(context);

    // Tags disponibles de todas las canciones
    final allTags = songsAsync.value
            ?.expand((s) => s.tags)
            .toSet()
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Songbook'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(songsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar canción o artista...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),

          // Filtros por tag
          if (allTags.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _TagChip(
                    label: 'Todas',
                    selected: selectedTag == null,
                    onTap: () =>
                        ref.read(selectedTagProvider.notifier).state = null,
                  ),
                  ...allTags.map((tag) => _TagChip(
                        label: tag,
                        selected: selectedTag == tag,
                        onTap: () =>
                            ref.read(selectedTagProvider.notifier).state = tag,
                      )),
                ],
              ),
            ),

          // Lista
          Expanded(
            child: songsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 12),
                    Text('No se pudo cargar: $e'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(songsProvider.notifier).refresh(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (_) {
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty
                          ? 'No hay canciones aún.\nAgrega la primera con el botón +'
                          : 'Sin resultados para "$query"',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(songsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    itemBuilder: (ctx, i) =>
                        _SongCard(song: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongEditorPage(song: Song.empty()),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nueva canción'),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SongCard extends ConsumerWidget {
  final Song song;
  const _SongCard({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        song.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Text(
            song.artist,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          _KeyBadge(songKey: song.originalKey),
          if (song.capo > 0) ...[
            const SizedBox(width: 4),
            Text(
              'capo ${song.capo}',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SongViewPage(song: song)),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'edit') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SongEditorPage(song: song),
              ),
            );
          } else if (action == 'delete') {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Eliminar canción'),
                content: Text('¿Eliminar "${song.title}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Eliminar'),
                  ),
                ],
              ),
            );
            if (confirm == true && song.id != null) {
              ref.read(songsProvider.notifier).deleteSong(song.id!);
            }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String songKey;
  const _KeyBadge({required this.songKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        songKey,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}