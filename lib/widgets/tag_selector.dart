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
  static const allTags = ['Frontend', 'Backend', 'Design', 'Testing', 'Documentation', 'Bug', 'Feature'];
  static const tagColors = {
    'Frontend': Color(0xFF2196F3),
    'Backend': Color(0xFF4CAF50),
    'Design': Color(0xFF9C27B0),
    'Testing': Color(0xFFFF9800),
    'Documentation': Color(0xFF795548),
    'Bug': Color(0xFFF44336),
    'Feature': Color(0xFF00BCD4),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: allTags.map((tag) {
        final isSelected = widget.selectedTags.contains(tag);
        return FilterChip(
          label: Text(tag),
          selected: isSelected,
          onSelected: (selected) {
            final newTags = List<String>.from(widget.selectedTags);
            if (selected) {
              newTags.add(tag);
            } else {
              newTags.remove(tag);
            }
            widget.onChanged(newTags);
            setState(() {});
          },
          selectedColor: tagColors[tag]?.withOpacity(0.2),
          checkmarkColor: tagColors[tag],
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(color: isSelected ? (tagColors[tag] ?? AppColors.primary) : Colors.transparent),
        );
      }).toList(),
    );
  }
}