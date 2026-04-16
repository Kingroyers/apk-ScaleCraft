import 'package:flutter/material.dart';
import '../core/helpers/chord_helper.dart';
import '../core/helpers/chord_helper.dart' as ChordHelper;

class ChordPickerSheet extends StatefulWidget {
  final String? currentChord;
  final String syllable;
  final void Function(String chord) onSelected;
  final VoidCallback onRemove;

  const ChordPickerSheet({
    super.key,
    this.currentChord,
    required this.syllable,
    required this.onSelected,
    required this.onRemove,
  });

  static Future<void> show({
    required BuildContext context,
    String? currentChord,
    required String syllable,
    required void Function(String chord) onSelected,
    required VoidCallback onRemove,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChordPickerSheet(
        currentChord: currentChord,
        syllable: syllable,
        onSelected: (chord) {
          Navigator.pop(context);
          onSelected(chord);
        },
        onRemove: () {
          Navigator.pop(context);
          onRemove();
        },
      ),
    );
  }

  @override
  State<ChordPickerSheet> createState() => _ChordPickerSheetState();
}

class _ChordPickerSheetState extends State<ChordPickerSheet> {
  String _activeGroup = 'Mayor';
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentChord;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ChordHelper.pickerGroups;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  'Acorde para: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '"${widget.syllable}"',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tabs de grupos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: groups.keys.map((group) {
                final isActive = group == _activeGroup;
                return GestureDetector(
                  onTap: () => setState(() => _activeGroup = group),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      group,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Grid de acordes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (groups[_activeGroup] ?? []).map((chord) {
                final isSelected = chord == _selected;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selected = chord);
                    widget.onSelected(chord);
                  },
                  child: Container(
                    width: 58,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      chord,
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

          // Botón eliminar acorde
          if (widget.currentChord != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Eliminar acorde'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error, width: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}