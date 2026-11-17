import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/database_helper.dart';
import '../services/label_service.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../utils/image_size.dart';
import '../widgets/pinepal_loader.dart';

// The feedback screen. The prediction and confidence are read-only because
// they are what the model produced; only the farmer's feedback and notes can
// be edited. Officers verify scans on the web dashboard, so this is only the
// farmer saying whether the result looked right. Pops with true when saved.
class EditScanScreen extends StatefulWidget {
  final ScanRecord scan;

  const EditScanScreen({super.key, required this.scan});

  @override
  State<EditScanScreen> createState() => _EditScanScreenState();
}

class _EditScanScreenState extends State<EditScanScreen> {
  late final Future<List<String>> _labels = LabelService.load();
  late final TextEditingController _notes = TextEditingController(
    text: widget.scan.notes ?? '',
  );

  late ScanFeedback? _feedback = widget.scan.feedback;

  // What the fruit actually is, only asked when the result was wrong.
  // Null means "not sure".
  late String? _actual = widget.scan.feedback == ScanFeedback.incorrect
      ? widget.scan.verifiedLabel
      : null;

  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final notes = _notes.text.trim();

    // A correct result means the farmer agrees with the model's label
    final label = switch (_feedback) {
      ScanFeedback.correct => widget.scan.predictedLabel,
      ScanFeedback.incorrect => _actual,
      null => null,
    };

    try {
      await DatabaseHelper.instance.updateFeedback(
        widget.scan.scanUuid,
        feedback: _feedback,
        verifiedLabel: label,
        notes: notes.isEmpty ? null : notes,
      );
      SyncController.instance.onLocalChange();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
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

  // One of the two answers: a card that lights up in its color when chosen
  Widget _choice({
    required ScanFeedback value,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final selected = _feedback == value;
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: selected ? color : context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _saving ? null : () => setState(() => _feedback = value),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: selected ? color : context.colors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // "What is it actually?" with a "Not sure" first option. The label the
  // model predicted is left out, because that would be the other answer.
  Widget _actualPicker(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is it actually? (optional)',
            style: TextStyle(color: context.colors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: context.colors.line),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _actual,
                isExpanded: true,
                dropdownColor: context.colors.surface,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Not sure',
                      style: TextStyle(color: context.colors.textMuted),
                    ),
                  ),
                  for (final label in labels)
                    if (label != widget.scan.predictedLabel)
                      DropdownMenuItem<String?>(
                        value: label,
                        child: Text(LabelService.pretty(label)),
                      ),
                ],
                onChanged: _saving ? null : (v) => setState(() => _actual = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final image = File(scan.imagePath);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Feedback')),
      body: FutureBuilder<List<String>>(
        future: _labels,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: PinePalLoader());
          }
          final labels = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image.existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: Image.file(
                        image,
                        fit: BoxFit.cover,
                        cacheWidth: screenWidthPixels(context),
                        errorBuilder: (context, error, stack) =>
                            const SizedBox.shrink(),
                      ),
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
                  'Was the result correct?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check the fruit, then tell us. Scans without an answer are '
                  'left out of the accuracy figure.',
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _choice(
                  value: ScanFeedback.correct,
                  icon: Icons.check_circle_outline,
                  color: context.colors.success,
                  title: 'Yes, it is correct',
                  subtitle: 'The result matches what I see on the fruit',
                ),
                const SizedBox(height: 8),
                _choice(
                  value: ScanFeedback.incorrect,
                  icon: Icons.flag_outlined,
                  color: context.colors.warning,
                  title: 'No, the result is wrong',
                  subtitle: 'Report it so the model can be checked',
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.topCenter,
                  child: _feedback == ScanFeedback.incorrect
                      ? _actualPicker(labels)
                      : const SizedBox(width: double.infinity),
                ),
                if (_feedback != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _feedback = null;
                              _actual = null;
                            }),
                      child: const Text('Clear my answer'),
                    ),
                  ),
                const SizedBox(height: 16),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
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
                    label: Text(_saving ? 'Saving...' : 'Save feedback'),
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
