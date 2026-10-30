import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_colors.dart';
import '../utils/municipalities.dart';
import 'labeled_field.dart';

// Opens the sheet where the farmer edits the farm name and municipality.
// They are added to every new scan and sent with it when syncing.
Future<void> showFarmDetailsSheet(BuildContext context, AppSettings settings) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _FarmDetailsSheet(settings: settings),
  );
}

class _FarmDetailsSheet extends StatefulWidget {
  final AppSettings settings;

  const _FarmDetailsSheet({required this.settings});

  @override
  State<_FarmDetailsSheet> createState() => _FarmDetailsSheetState();
}

class _FarmDetailsSheetState extends State<_FarmDetailsSheet> {
  late final TextEditingController _farm = TextEditingController(
    text: widget.settings.farmName,
  );
  late String _municipality = widget.settings.municipality;

  @override
  void dispose() {
    _farm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setFarmName(_farm.text);
    await widget.settings.setMunicipality(_municipality);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Moves up with the keyboard
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Farm details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Added to every new scan, so the web dashboard can place your '
              'scans on its map and filters.',
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Farm name',
              hint: 'For example: Bueno Farm',
              controller: _farm,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 14),
            Text(
              'Municipality',
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
                  value: _municipality,
                  isExpanded: true,
                  dropdownColor: context.colors.surface,
                  items: [
                    for (final name in municipalities)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _municipality = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
