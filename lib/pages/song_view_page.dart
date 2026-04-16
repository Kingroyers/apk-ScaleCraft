import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../core/helpers/transpose_helper.dart';
import '../widgets/chorded_line_widget.dart';
import '../services/providers.dart';
import 'song_editor_page.dart';

class SongViewPage extends ConsumerStatefulWidget {
  final Song song;
  const SongViewPage({super.key, required this.song});

  @override
  ConsumerState<SongViewPage> createState() => _SongViewPageState();
}

class _SongViewPageState extends ConsumerState<SongViewPage> {
  late String _currentKey;
  double _fontSize = 15;
  bool _autoScroll = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentKey = widget.song.originalKey;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Notas del selector de tono (solo las 12 principales + menores comunes)
  static const _keyOptions = [
    'C', 'C#', 'D', 'Eb', 'E', 'F',
    'F#', 'G', 'Ab', 'A', 'Bb', 'B',
    'Am', 'Bm', 'Cm', 'Dm', 'Em', 'Fm', 'Gm',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.song.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (widget.song.artist.isNotEmpty)
              Text(
                widget.song.artist,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SongEditorPage(song: widget.song),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _shareSong,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de tono
          _KeySelector(
            currentKey: _currentKey,
            originalKey: widget.song.originalKey,
            capo: widget.song.capo,
            onKeySelected: (key) => setState(() => _currentKey = key),
          ),

          // Barra de controles
          _ControlBar(
            fontSize: _fontSize,
            autoScroll: _autoScroll,
            onFontSizeChanged: (v) => setState(() => _fontSize = v),
            onAutoScrollChanged: (v) {
              setState(() => _autoScroll = v);
              if (v) _startAutoScroll();
            },
          ),

          const Divider(height: 1),

          // Contenido de la canción
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: widget.song.sections.map((section) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre de sección
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        section.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    // Líneas con acordes
                    ...section.lines.map(
                      (line) => ChordedLineWidget(
                        line: line,
                        originalKey: widget.song.originalKey,
                        currentKey: _currentKey,
                        fontSize: _fontSize,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _startAutoScroll() {
    if (!_autoScroll) return;
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted || !_autoScroll) return;
      if (_scrollController.position.pixels <
          _scrollController.position.maxScrollExtent) {
        _scrollController.animateTo(
          _scrollController.position.pixels + 1,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
        _startAutoScroll();
      } else {
        setState(() => _autoScroll = false);
      }
    });
  }

  void _shareSong() {
    // Generar texto plano de la canción
    final buffer = StringBuffer();
    buffer.writeln(widget.song.title);
    buffer.writeln(widget.song.artist);
    buffer.writeln('Tono: $_currentKey');
    if (widget.song.capo > 0) buffer.writeln('Capo: ${widget.song.capo}');
    buffer.writeln();

    for (final section in widget.song.sections) {
      buffer.writeln('[${section.name}]');
      for (final line in section.lines) {
        // Chords line
        if (line.chords.isNotEmpty) {
          final transposed = TransposeHelper.transposeLine(
            line.chords,
            widget.song.originalKey,
            _currentKey,
          );
          final chordLine = StringBuffer();
          int lastPos = 0;
          for (final entry
              in transposed.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key))) {
            while (lastPos < entry.key) {
              chordLine.write(' ');
              lastPos++;
            }
            chordLine.write(entry.value);
            lastPos += entry.value.length;
          }
          buffer.writeln(chordLine.toString());
        }
        buffer.writeln(line.lyrics);
      }
      buffer.writeln();
    }

    // En producción usa share_plus: Share.share(buffer.toString())
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instala share_plus para compartir')),
    );
  }
}

// ── Selector de tono ──────────────────────────────────────────────────────────

class _KeySelector extends StatelessWidget {
  final String currentKey;
  final String originalKey;
  final int capo;
  final void Function(String) onKeySelected;

  const _KeySelector({
    required this.currentKey,
    required this.originalKey,
    required this.capo,
    required this.onKeySelected,
  });

  static const _keys = [
    'C', 'C#', 'D', 'Eb', 'E', 'F',
    'F#', 'G', 'Ab', 'A', 'Bb', 'B',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TONO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (capo > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Capo $capo',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => onKeySelected(originalKey),
                child: Text(
                  'Original',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _keys.map((key) {
                final isSelected = key == currentKey;
                return GestureDetector(
                  onTap: () => onKeySelected(key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
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
          ),
        ],
      ),
    );
  }
}

// ── Barra de controles ────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final double fontSize;
  final bool autoScroll;
  final void Function(double) onFontSizeChanged;
  final void Function(bool) onAutoScrollChanged;

  const _ControlBar({
    required this.fontSize,
    required this.autoScroll,
    required this.onFontSizeChanged,
    required this.onAutoScrollChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Row(
        children: [
          // Tamaño fuente
          const Icon(Icons.text_fields, size: 16),
          Expanded(
            child: Slider(
              value: fontSize,
              min: 12,
              max: 22,
              divisions: 10,
              onChanged: onFontSizeChanged,
            ),
          ),
          // Auto-scroll
          Text(
            'Auto',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Switch(
            value: autoScroll,
            onChanged: onAutoScrollChanged,
          ),
        ],
      ),
    );
  }
}