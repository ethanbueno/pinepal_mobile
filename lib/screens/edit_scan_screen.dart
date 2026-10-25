import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/database_helper.dart';
import '../services/label_service.dart';
import '../theme/app_colors.dart';

// The "update" screen. The prediction and confidence are read-only because
// they are what the model produced; only the farmer's verification and notes
// can be edited. Pops with true when something was saved.
class EditScanScreen extends StatefulWidget {
  final ScanRecord scan;

  const EditScanScreen({super.key, required this.scan});

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

class _EditScanScreenState extends State<EditScanScreen> {
  static const String _unverified = '__unverified__';

  late final Future<List<String>> _labels = LabelService.load();
  late final TextEditingController _notes =
      TextEditingController(text: widget.scan.notes ?? '');
  late String _selected = widget.scan.verifiedLabel ?? _unverified;

  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notes = _notes.text.trim();

    try {
      await DatabaseHelper.instance.updateVerification(
        widget.scan.scanUuid,
        verifiedLabel: _selected == _unverified ? null : _selected,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final image = File(scan.imagePath);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Scan')),
      body: FutureBuilder<List<String>>(
        future: _labels,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final labels = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image.existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Image.file(image, fit: BoxFit.cover),
                    ),
                  ),
                const SizedBox(height: 16),
                _readOnlyRow(
                  'Model predicted',
                  LabelService.pretty(scan.predictedLabel),
                ),
                _readOnlyRow(
                  'Confidence',
                  '${(scan.confidence * 100).toStringAsFixed(1)}%',
                ),
                const Divider(height: 32),
                const Text(
                  'What was it actually?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Leave this unset if you have not checked the fruit yet. '
                  'Unset scans are left out of the accuracy figure.',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: context.colors.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selected,
                      isExpanded: true,
                      dropdownColor: context.colors.surface,
                      items: [
                        DropdownMenuItem(
                          value: _unverified,
                          child: Text(
                            'Not verified yet',
                            style: TextStyle(color: context.colors.textMuted),
                          ),
                        ),
                        for (final label in labels)
                          DropdownMenuItem(
                            value: label,
                            child: Text(LabelService.pretty(label)),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selected = value);
                              }
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Field notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 4,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    hintText: 'Block number, weather, anything worth recording',
                  ),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: _saving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onAccent,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save changes'),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
