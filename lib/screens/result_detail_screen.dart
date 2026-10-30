import 'dart:io';

import 'package:flutter/material.dart';

import '../models/remediation_protocol.dart';
import '../models/scan_record.dart';
import '../services/classifier_service.dart';
import '../services/database_helper.dart';
import '../services/label_service.dart';
import '../services/protocol_service.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/protocol_cards.dart';
import 'edit_scan_screen.dart';

// Full diagnostic report for one saved scan: photo, what the model found,
// the disease profile and the step-by-step remediation. Opened from the
// result sheet, the History list and the Home tab.
class ResultDetailScreen extends StatefulWidget {
  final ScanRecord scan;

  const ResultDetailScreen({super.key, required this.scan});

  @override
  State<ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<ResultDetailScreen> {
  late ScanRecord _scan;
  late Future<RemediationProtocol> _protocol;

  @override
  void initState() {
    super.initState();
    _scan = widget.scan;
    _protocol = ProtocolService.getProtocolForDisease(_scan.predictedLabel);
  }

  Future<void> _openEditor() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EditScanScreen(scan: _scan)),
    );
    if (saved != true) return;

    // Show the new verification and notes right away
    final fresh = await DatabaseHelper.instance.getScan(_scan.scanUuid);
    if (mounted && fresh != null) setState(() => _scan = fresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic Report')),
      body: FutureBuilder<RemediationProtocol>(
        future: _protocol,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final protocol =
              snapshot.data ??
              RemediationProtocol.fallback(_scan.predictedLabel);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageCard(protocol),
                if (_scan.confidence < ClassifierService.minConfidence) ...[
                  const SizedBox(height: 12),
                  _buildLowConfidenceNotice(),
                ],
                const SizedBox(height: 16),
                _buildSummaryCard(protocol),
                const SizedBox(height: 16),
                PathogenCard(protocol: protocol),
                const SizedBox(height: 16),
                RemediationCard(protocol: protocol),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(
                    _scan.hasFeedback ? 'Edit feedback' : 'Give feedback',
                  ),
                  onPressed: _openEditor,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLowConfidenceNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: context.colors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: context.colors.danger, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Low confidence result. Retake the photo in better lighting, or '
              'have the diagnosis confirmed by an agricultural technician.',
              style: TextStyle(color: context.colors.text, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(RemediationProtocol protocol) {
    final file = File(_scan.imagePath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => _placeholder(),
                  )
                : _placeholder(),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.canvas.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: SeverityChip(severity: protocol.severity),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.canvas.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: context.colors.accent),
                  ),
                  child: Text(
                    '${(_scan.confidence * 100).toStringAsFixed(1)}% confidence',
                    style: TextStyle(
                      color: context.colors.accentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: context.colors.surface2,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: context.colors.textMuted,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: context.colors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(RemediationProtocol protocol) {
    final scan = _scan;

    final actual = scan.verifiedLabel;
    final String feedback;
    final IconData feedbackIcon;
    switch (scan.feedback) {
      case null:
        feedback = 'No feedback yet';
        feedbackIcon = Icons.help_outline;
      case ScanFeedback.correct:
        feedback = 'You marked this result correct';
        feedbackIcon = Icons.check_circle_outline;
      case ScanFeedback.incorrect:
        feedback = actual == null
            ? 'You reported this result as wrong'
            : 'You reported it as wrong: actually ${LabelService.pretty(actual)}';
        feedbackIcon = Icons.flag_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            protocol.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            protocol.scientificName,
            style: TextStyle(
              color: context.colors.accentText,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 24),
          if (scan.secondLabel != null)
            _row(
              Icons.compare_arrows,
              'Second guess: ${LabelService.pretty(scan.secondLabel!)}'
              '${scan.secondConfidence == null ? '' : ' (${(scan.secondConfidence! * 100).toStringAsFixed(1)}%)'}',
            ),
          _row(
            Icons.location_on_outlined,
            scan.hasGps
                ? 'GPS: ${scan.latitude.toStringAsFixed(4)}, '
                      '${scan.longitude.toStringAsFixed(4)}'
                : 'GPS location unavailable',
          ),
          if (scan.farmName != null)
            _row(Icons.home_work_outlined, 'Farm: ${scan.farmName}'),
          if (scan.municipality != null)
            _row(Icons.map_outlined, 'Municipality: ${scan.municipality}'),
          _row(
            Icons.access_time,
            'Scanned on ${formatDateTime(scan.scannedAt)}',
          ),
          _row(
            scan.imageSource == 'Camera'
                ? Icons.camera_alt_outlined
                : Icons.photo_library_outlined,
            'Source: ${scan.imageSource}',
          ),
          _row(feedbackIcon, feedback),
          if (scan.notes != null) _row(Icons.notes, scan.notes!),
        ],
      ),
    );
  }
}
