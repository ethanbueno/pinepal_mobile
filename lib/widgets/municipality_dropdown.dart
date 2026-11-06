import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/municipalities.dart';

// The municipality picker of the farm details and of a new scan, with its label
// above it like LabeledField. value is null until one is chosen.
class MunicipalityDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String>? onChanged; // null disables it
  final String label;

  const MunicipalityDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Municipality',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.colors.text,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: context.colors.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: const Text('Choose a municipality'),
              dropdownColor: context.colors.surface,
              items: [
                for (final name in municipalities)
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onChanged == null
                  ? null
                  : (value) {
                      if (value != null) onChanged!(value);
                    },
            ),
          ),
        ),
      ],
    );
  }
}
