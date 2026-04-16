import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/song_section.dart';
import '../models/chorded_line.dart';
import '../widgets/chord_picker_sheet.dart';
import '../services/providers.dart';

class SongEditorPage extends ConsumerStatefulWidget {
  final Song song;
  const SongEditorPage({super.key, required this.song});

  @override
  ConsumerState<SongEditorPage> createState() => _SongEditorPageState();
}

class _SongEditorPageState extends ConsumerState<SongEditorPage> {
  late Song _song;
  int _tab = 0; // 0=Info, 1=Acordes, 2=Secciones
  bool _saving = false;

  // Controladores del formulario de Info
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
    _titleCtrl = TextEditingController(text: _song.title);
    _artistCtrl = TextEditingController(text: _song.artist);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar canción'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Guardar'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildTab(0, 'Info'),
                _buildTab(1, 'Acordes'),
                _buildTab(2, 'Secciones'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Contenido del tab activo
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _InfoTab(
                  song: _song,
                  titleCtrl: _titleCtrl,
                  artistCtrl: _artistCtrl,
                  onChanged: (s) => setState(() => _song = s),
                ),
                _ChordsTab(
                  song: _song,
                  onChanged: (s) => setState(() => _song = s),
                ),
                _SectionsTab(
                  song: _song,
                  onChanged: (s) => setState(() => _song = s),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final theme = Theme.of(context);
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    // Sincronizar datos del formulario al modelo
    final updated = _song.copyWith(
      title: _titleCtrl.text.trim(),
      artist: _artistCtrl.text.trim(),
    );

    if (updated.title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      if (updated.id == null) {
        await ref.read(songsProvider.notifier).addSong(updated);
      } else {
        await ref.read(songsProvider.notifier).updateSong(updated);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Tab 1: Info básica ────────────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  final Song song;
  final TextEditingController titleCtrl;
  final TextEditingController artistCtrl;
  final void Function(Song) onChanged;

  const _InfoTab({
    required this.song,
    required this.titleCtrl,
    required this.artistCtrl,
    required this.onChanged,
  });

  static const _keys = [
    'C', 'C#', 'D', 'Eb', 'E', 'F',
    'F#', 'G', 'Ab', 'A', 'Bb', 'B',
    'Am', 'Bm', 'Dm', 'Em', 'Gm',
  ];

  static const _commonTags = [
    'Alabanza', 'Adoración', 'Ofertorio', 'Comunión', 'Entrada',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(titleCtrl, 'Título', autofocus: true),
        const SizedBox(height: 12),
        _field(artistCtrl, 'Artista / Autor'),
        const SizedBox(height: 20),

        // Selector de tono original
        Text(
          'Tono original',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _keys.map((key) {
            final isSelected = key == song.originalKey;
            final theme = Theme.of(context);
            return GestureDetector(
              onTap: () => onChanged(song.copyWith(originalKey: key)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Capo
        Row(
          children: [
            Text(
              'Cejilla (capo)',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: song.capo > 0
                  ? () => onChanged(song.copyWith(capo: song.capo - 1))
                  : null,
            ),
            Text(
              '${song.capo}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: song.capo < 11
                  ? () => onChanged(song.copyWith(capo: song.capo + 1))
                  : null,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Tags
        Text(
          'Categoría',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _commonTags.map((tag) {
            final isSelected = song.tags.contains(tag);
            final theme = Theme.of(context);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              onSelected: (v) {
                final tags = List<String>.from(song.tags);
                if (v) {
                  tags.add(tag);
                } else {
                  tags.remove(tag);
                }
                onChanged(song.copyWith(tags: tags));
              },
              selectedColor: theme.colorScheme.primaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

// ── Tab 2: Editor de acordes ──────────────────────────────────────────────────

class _ChordsTab extends StatelessWidget {
  final Song song;
  final void Function(Song) onChanged;

  const _ChordsTab({required this.song, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (song.sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music,
              size: 48,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            const Text('Agrega secciones primero en la pestaña "Secciones"'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Toca una sílaba para agregar o cambiar un acorde. Toca un acorde existente para eliminarlo.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...song.sections.asMap().entries.map((sEntry) {
          final sIdx = sEntry.key;
          final section = sEntry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              ...section.lines.asMap().entries.map((lEntry) {
                final lIdx = lEntry.key;
                final line = lEntry.value;

                return _EditableLine(
                  line: line,
                  onChordChanged: (charPos, chord) {
                    final updatedLine = line.copyWith(
                      chords: Map.from(line.chords)..[charPos] = chord,
                    );
                    _updateLine(sIdx, lIdx, updatedLine);
                  },
                  onChordRemoved: (charPos) {
                    final newChords = Map<int, String>.from(line.chords)
                      ..remove(charPos);
                    final updatedLine = line.copyWith(chords: newChords);
                    _updateLine(sIdx, lIdx, updatedLine);
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }

  void _updateLine(int sIdx, int lIdx, ChordedLine updatedLine) {
    final updatedLines = List<ChordedLine>.from(song.sections[sIdx].lines)
      ..[lIdx] = updatedLine;
    final updatedSection = song.sections[sIdx].copyWith(lines: updatedLines);
    final updatedSections = List<SongSection>.from(song.sections)
      ..[sIdx] = updatedSection;
    onChanged(song.copyWith(sections: updatedSections));
  }
}

class _EditableLine extends StatelessWidget {
  final ChordedLine line;
  final void Function(int charPos, String chord) onChordChanged;
  final void Function(int charPos) onChordRemoved;

  const _EditableLine({
    required this.line,
    required this.onChordChanged,
    required this.onChordRemoved,
  });

  static const double _charWidth = 9.0; // monospace 15px ≈ 9px/char
  static const double _fontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) => _handleTap(context, details.localPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x22000000), width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila de acordes existentes (tocables para eliminar)
            SizedBox(
              height: 16,
              child: Stack(
                children: line.chords.entries.map((e) {
                  return Positioned(
                    left: e.key * _charWidth,
                    child: GestureDetector(
                      onTap: () => onChordRemoved(e.key),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Letra
            Text(
              line.lyrics,
              style: const TextStyle(
                fontSize: _fontSize,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, Offset localPosition) {
    // Calcular posición de carácter a partir del tap en la fila de letra
    // El tap Y dentro de la línea: si está en la fila de letra (>16px desde top)
    final charPos = (localPosition.dx / _charWidth).floor().clamp(
      0,
      line.lyrics.length - 1,
    );

    // Sílaba en esa posición
    final syllable = line.lyrics.isEmpty
        ? ''
        : line.lyrics[charPos.clamp(0, line.lyrics.length - 1)];

    ChordPickerSheet.show(
      context: context,
      currentChord: line.chords[charPos],
      syllable: syllable,
      onSelected: (chord) => onChordChanged(charPos, chord),
      onRemove: () => onChordRemoved(charPos),
    );
  }
}

// ── Tab 3: Gestión de secciones ───────────────────────────────────────────────

class _SectionsTab extends StatelessWidget {
  final Song song;
  final void Function(Song) onChanged;

  const _SectionsTab({required this.song, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView(
            padding: const EdgeInsets.all(16),
            onReorder: (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx--;
              final sections = List<SongSection>.from(song.sections);
              final item = sections.removeAt(oldIdx);
              sections.insert(newIdx, item);
              onChanged(song.copyWith(sections: sections));
            },
            children: song.sections.asMap().entries.map((e) {
              final idx = e.key;
              final section = e.value;
              return _SectionTile(
                key: ValueKey(idx),
                section: section,
                onNameChanged: (name) {
                  final sections = List<SongSection>.from(song.sections)
                    ..[idx] = section.copyWith(name: name);
                  onChanged(song.copyWith(sections: sections));
                },
                onLineAdded: (lyrics) {
                  final newLines = List<ChordedLine>.from(section.lines)
                    ..add(ChordedLine(lyrics: lyrics));
                  final sections = List<SongSection>.from(song.sections)
                    ..[idx] = section.copyWith(lines: newLines);
                  onChanged(song.copyWith(sections: sections));
                },
                onLineRemoved: (lIdx) {
                  final newLines = List<ChordedLine>.from(section.lines)
                    ..removeAt(lIdx);
                  final sections = List<SongSection>.from(song.sections)
                    ..[idx] = section.copyWith(lines: newLines);
                  onChanged(song.copyWith(sections: sections));
                },
                onRemoved: () {
                  final sections = List<SongSection>.from(song.sections)
                    ..removeAt(idx);
                  onChanged(song.copyWith(sections: sections));
                },
              );
            }).toList(),
          ),
        ),

        // Botón agregar sección
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _addSection(context),
              icon: const Icon(Icons.add),
              label: const Text('Agregar sección'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addSection(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva sección'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'ej: Verso 1, Coro...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final sections = List<SongSection>.from(song.sections)
        ..add(SongSection(name: name));
      onChanged(song.copyWith(sections: sections));
    }
  }
}

class _SectionTile extends StatefulWidget {
  final SongSection section;
  final void Function(String) onNameChanged;
  final void Function(String) onLineAdded;
  final void Function(int) onLineRemoved;
  final VoidCallback onRemoved;

  const _SectionTile({
    super.key,
    required this.section,
    required this.onNameChanged,
    required this.onLineAdded,
    required this.onLineRemoved,
    required this.onRemoved,
  });

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Cabecera de sección
          ListTile(
            leading: const Icon(Icons.drag_handle, size: 20),
            title: Text(
              widget.section.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: widget.onRemoved,
                ),
              ],
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            // Líneas
            ...widget.section.lines.asMap().entries.map((e) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  e.value.lyrics,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => widget.onLineRemoved(e.key),
                ),
              );
            }),

            // Campo para agregar línea
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _AddLineField(onAdd: widget.onLineAdded),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddLineField extends StatefulWidget {
  final void Function(String) onAdd;
  const _AddLineField({required this.onAdd});

  @override
  State<_AddLineField> createState() => _AddLineFieldState();
}

class _AddLineFieldState extends State<_AddLineField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Agregar línea de letra...',
              hintStyle: const TextStyle(fontSize: 13),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                widget.onAdd(v.trim());
                _ctrl.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            if (_ctrl.text.trim().isNotEmpty) {
              widget.onAdd(_ctrl.text.trim());
              _ctrl.clear();
            }
          },
        ),
      ],
    );
  }
}