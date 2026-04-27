import 'package:flutter/material.dart';
import '../theme.dart';

class TagSelector extends StatefulWidget {
  final List<String> selectedTags;
  final Function(List<String>) onChanged;

  const TagSelector({super.key, required this.selectedTags, required this.onChanged});

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  static const presetTags = ['Frontend', 'Backend', 'Design', 'Testing', 'Documentation', 'Bug', 'Feature'];
  static const presetColors = {
    'Frontend': Color(0xFF2196F3),
    'Backend': Color(0xFF4CAF50),
    'Design': Color(0xFF9C27B0),
    'Testing': Color(0xFFFF9800),
    'Documentation': Color(0xFF795548),
    'Bug': Color(0xFFF44336),
    'Feature': Color(0xFF00BCD4),
  };

  List<String> get allTags {
    final combined = <String>{...presetTags, ...widget.selectedTags};
    return combined.toList();
  }

  @override
  Widget build(BuildContext context) {
    final tags = allTags;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final isSelected = widget.selectedTags.contains(tag);
        final color = presetColors[tag] ?? AppColors.primary;
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (selected) {
            final newTags = List<String>.from(widget.selectedTags);
            if (selected) {
              if (!newTags.contains(tag)) newTags.add(tag);
            } else {
              newTags.remove(tag);
            }
            widget.onChanged(newTags);
            setState(() {});
          },
          selectedColor: color.withOpacity(0.2),
          checkmarkColor: color,
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(color: isSelected ? color : Colors.transparent),
        );
      }).toList(),
    );
  }
}
