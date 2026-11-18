import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/dashboard_stats.dart';
import '../models/remediation_protocol.dart';
import '../models/scan_record.dart';
import '../services/classifier_service.dart';
import '../services/database_helper.dart';
import '../services/label_service.dart';
import '../services/protocol_service.dart';
import '../services/server_scans.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../utils/map_area.dart';
import '../utils/image_size.dart';
import '../widgets/confidence_bar.dart';
import '../widgets/protocol_cards.dart';
import '../widgets/scan_heat_map.dart';
import '../widgets/section_card.dart';
import 'edit_scan_screen.dart';
import '../widgets/pinepal_loader.dart';

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
    _protocol = ProtocolService.getProtocolForDisease(_scan.shownLabel);
    _addOfficerCheck();
  }

  // Opened from Home or the result sheet, a phone scan has no officer check
  // yet: take it from the server's saved copy (History keeps it up to date)
  Future<void> _addOfficerCheck() async {
    if (!_scan.onPhone || _scan.isOfficerVerified) return;
    try {
      final saved = await ServerScans().saved();
      final copy = saved?.scans
          .where((s) => s.scanUuid == _scan.scanUuid)
          .firstOrNull;
      if (copy == null || copy.officerLabel == null || !mounted) return;
      _setScan(_scan.withServer(copy));
    } catch (_) {
      // no saved copy: shown without the officer's check
    }
  }

  // The guide follows the officer's answer, so load it again if that changed
  void _setScan(ScanRecord scan) {
    final newLabel = scan.shownLabel != _scan.shownLabel;
    setState(() {
      _scan = scan;
      if (newLabel) {
        _protocol = ProtocolService.getProtocolForDisease(scan.shownLabel);
      }
    });
  }

  Future<void> _openEditor() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EditScanScreen(scan: _scan)),
    );
    if (saved != true) return;

    // Show the new verification and notes right away
    // (the officer's check is not in the database, so it is carried over)
    final fresh = await DatabaseHelper.instance.getScan(_scan.scanUuid);
    if (!mounted || fresh == null) return;
    _setScan(fresh.withOfficerOf(_scan));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostic Report')),
      body: FutureBuilder<RemediationProtocol>(
        future: _protocol,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: PinePalLoader(label: 'Loading report...'),
            );
          }
          final protocol =
              snapshot.data ?? RemediationProtocol.fallback(_scan.shownLabel);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageCard(protocol),
                if (_scan.confidence < ClassifierService.minConfidence) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildLowConfidenceNotice(),
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildSummaryCard(protocol),
                const SizedBox(height: AppSpacing.md),
                _buildOfficerCard(),
                if (_scan.hasGps) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildMapCard(),
                ],
                const SizedBox(height: AppSpacing.lg),
                PathogenCard(protocol: protocol),
                const SizedBox(height: AppSpacing.md),
                RemediationCard(protocol: protocol),
                const SizedBox(height: AppSpacing.section),
                // a scan from the web or another phone is changed there
                if (_scan.onPhone) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(
                      _scan.hasFeedback ? 'Edit Feedback' : 'Give Feedback',
                    ),
                    onPressed: _openEditor,
                  ),
                  const SizedBox(height: 8),
                ],
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
          const SizedBox(width: AppSpacing.sm),
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

  Widget _photo() {
    if (!_scan.onPhone) {
      final url = _scan.imageUrl;
      if (url == null) return _placeholder();
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: screenWidthPixels(context),
        errorBuilder: (context, error, stack) => _placeholder(),
      );
    }
    final file = File(_scan.imagePath);
    if (!file.existsSync()) return _placeholder();
    return Image.file(
      file,
      fit: BoxFit.cover,
      // as wide as the screen, not the full camera size
      cacheWidth: screenWidthPixels(context),
      errorBuilder: (context, error, stack) => _placeholder(),
    );
  }

  // Where the scan was taken, like the map on the web's scan detail. A still
  // preview, so dragging scrolls the report; tapping opens the full map.
  // Uses the same saved map tiles as the dashboard, so places seen before
  // show offline.
  Widget _buildMapCard() {
    final scan = _scan;
    final spot = DashboardScan(
      label: scan.shownLabel,
      scannedAt: scan.scannedAt,
      latitude: scan.latitude,
      longitude: scan.longitude,
    );
    final point = LatLng(scan.latitude, scan.longitude);
    final inTown = isInLockedArea(scan.latitude, scan.longitude);

    return SectionCard(
      title: 'Where It Was Scanned',
      children: [
        if (!inTown)
          Text(
            'This scan was taken outside $lockedAreaName, so it is not on the '
            'map. GPS: ${scan.latitude.toStringAsFixed(4)}, '
            '${scan.longitude.toStringAsFixed(4)}',
            style: TextStyle(color: context.colors.textMuted, fontSize: 13),
          )
        else
          Stack(
            children: [
              ScanHeatMap(
                scans: [spot],
                height: 200,
                interactive: false,
                focus: point,
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanHeatMapScreen(
                          scans: [spot],
                          title: 'Where It Was Scanned',
                          focus: point,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // What the agricultural officer said about the scan on the web dashboard
  Widget _buildOfficerCard() {
    final scan = _scan;
    final String title;
    final String text;
    final IconData icon;
    final Color color;
    if (scan.isOfficerVerified) {
      final who = scan.officerBy ?? 'an agricultural officer';
      final when = scan.officerAt == null
          ? ''
          : ' on ${formatDateTime(scan.officerAt!)}';
      if (scan.isOfficerCorrected) {
        title = 'Corrected by an officer';
        text =
            'Checked by $who$when. The model said '
            '${LabelService.pretty(scan.predictedLabel)}, the officer says it '
            "is ${LabelService.pretty(scan.officerLabel!)}. The guide below "
            "is for the officer's answer.";
        icon = Icons.edit_note;
        color = context.colors.warning;
      } else {
        title = 'Checked by an officer';
        text = 'Checked by $who$when. The result is correct.';
        icon = Icons.verified_outlined;
        color = context.colors.success;
      }
    } else {
      title = 'Not checked by an officer yet';
      text = scan.synced
          ? "An agricultural officer hasn't checked this scan yet. Their "
                'answer shows here once they do.'
          : 'Sync this scan so an agricultural officer can check it.';
      icon = Icons.schedule;
      color = context.colors.textMuted;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
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
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(RemediationProtocol protocol) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Stack(
        children: [
          SizedBox(height: 240, width: double.infinity, child: _photo()),
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
              'Image Unavailable',
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
              color: context.colors.textMuted,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ConfidenceBar(value: scan.confidence),
          const Divider(height: 28),
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
            switch (scan.imageSource) {
              'Camera' => Icons.camera_alt_outlined,
              'Web' => Icons.language,
              _ => Icons.photo_library_outlined,
            },
            scan.onPhone
                ? 'Source: ${scan.imageSource}'
                : scan.imageSource == 'Web'
                ? 'Saved on the PinePal website'
                : 'Taken on another phone (${scan.imageSource})',
          ),
          _row(feedbackIcon, feedback),
          if (scan.notes != null) _row(Icons.notes, scan.notes!),
        ],
      ),
    );
  }
}
