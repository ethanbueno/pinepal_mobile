import 'dart:io';

import 'package:flutter/material.dart';

import '../models/scan_record.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../services/label_service.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/tile_card.dart';
import '../widgets/disease_badge.dart';
import '../widgets/empty_state.dart';
import '../utils/format.dart';
import '../utils/image_size.dart';
import 'edit_scan_screen.dart';
import 'result_detail_screen.dart';

// List of saved scans. Tap a scan for the full report, verify it, delete it,
// clear the whole history, or export everything to CSV.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ScanRecord>> _scans;
  Map<String, int> _summary = const {'total': 0, 'checked': 0, 'correct': 0};
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _scans = DatabaseHelper.instance.getAllScans();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final summary = await DatabaseHelper.instance.getSummary();
    if (mounted) setState(() => _summary = summary);
  }

  void _reload() {
    setState(() {
      _scans = DatabaseHelper.instance.getAllScans();
    });
    _loadSummary();
    SyncController.instance.onLocalChange();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: TextStyle(color: context.colors.danger),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  // The photo is copied into the app folder when a scan is saved,
  // so it is removed together with the record.
  Future<void> _deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover photo is not worth failing the delete for
    }
  }

  Future<void> _deleteScan(ScanRecord scan) async {
    final ok = await _confirm(
      'Delete this scan?',
      'Are you sure you want to delete this '
          '${LabelService.pretty(scan.predictedLabel)} scan? Its record and '
          'photo will be removed permanently.',
    );
    if (!ok) return;

    try {
      await DatabaseHelper.instance.deleteScan(scan.scanUuid);
      await _deleteImage(scan.imagePath);
    } catch (e) {
      _showMessage('Could not delete the scan: $e');
      return;
    }
    if (!mounted) return;
    _reload();
    _showMessage('Scan deleted.');
  }

  Future<void> _clearHistory(List<ScanRecord> scans) async {
    final ok = await _confirm(
      'Clear all history?',
      'Are you sure you want to delete all ${scans.length} scans? They and '
          'their photos will be removed permanently.',
    );
    if (!ok) return;

    try {
      await DatabaseHelper.instance.deleteAllScans();
      for (final scan in scans) {
        await _deleteImage(scan.imagePath);
      }
    } catch (e) {
      _showMessage('Could not clear the history: $e');
      return;
    }
    if (!mounted) return;
    _reload();
    _showMessage('History cleared.');
  }

  Future<void> _openDetail(ScanRecord scan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ResultDetailScreen(scan: scan)),
    );
    if (mounted) _reload();
  }

  Future<void> _openEditor(ScanRecord scan) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => EditScanScreen(scan: scan)),
    );
    if (!mounted) return;
    _reload();
    if (saved == true) _showMessage('Scan updated.');
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;

    final records = await DatabaseHelper.instance.getAllScans();
    if (records.isEmpty) {
      _showMessage('Nothing to export yet.');
      return;
    }

    setState(() => _exporting = true);
    try {
      final file = await ExportService.exportCsv(records);
      await ExportService.shareFile(file);
    } catch (e) {
      _showMessage('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // Small rounded label with an icon
  Widget _chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Synced (green) or Pending (grey)
  Widget _statusChip(bool synced) {
    return _chip(
      synced ? 'Synced' : 'Pending',
      synced ? context.colors.success : context.colors.textMuted,
    );
  }

  // No feedback / Marked correct / Actually <label> / Reported wrong
  Widget _feedbackChip(ScanRecord scan) {
    switch (scan.feedback) {
      case null:
        return _chip(
          'No feedback',
          context.colors.textMuted,
          icon: Icons.help_outline,
        );
      case ScanFeedback.correct:
        return _chip(
          'Marked correct',
          context.colors.success,
          icon: Icons.check_circle_outline,
        );
      case ScanFeedback.incorrect:
        final actual = scan.verifiedLabel;
        return actual == null
            ? _chip(
                'Reported wrong',
                context.colors.warning,
                icon: Icons.flag_outlined,
              )
            : _chip(
                'Actually ${LabelService.pretty(actual)}',
                context.colors.warning,
                icon: Icons.cancel_outlined,
              );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ScanRecord>>(
      future: _scans,
      builder: (context, snapshot) {
        final scans = snapshot.data ?? [];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan History'),
            actions: [
              if (_exporting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Export to CSV',
                  icon: const Icon(Icons.ios_share),
                  onPressed: _exportCsv,
                ),
              if (scans.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all',
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () => _clearHistory(scans),
                ),
            ],
          ),
          body: Column(
            children: [
              _buildSummaryBar(),
              Expanded(child: _buildBody(snapshot, scans)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryBar() {
    final total = _summary['total'] ?? 0;
    final checked = _summary['checked'] ?? 0;
    final correct = _summary['correct'] ?? 0;
    final accuracy = checked == 0
        ? '--'
        : '${(correct / checked * 100).round()}%';

    Widget stat(String value, String label) {
      return Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: context.colors.accentText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat('$total', 'scans'),
          stat('$checked', 'checked'),
          stat(accuracy, 'accuracy'),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<ScanRecord>> snapshot,
    List<ScanRecord> scans,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load scans',
            text: '${snapshot.error}',
            action: OutlinedButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (scans.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: const [
          EmptyState(
            icon: Icons.history,
            title: 'No scans yet',
            text: 'Scans you take with the camera button are saved here.',
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.page),
        itemCount: scans.length,
        itemBuilder: (context, index) => _buildTile(scans[index]),
      ),
    );
  }

  Widget _buildTile(ScanRecord scan) {
    return TileCard(
      child: ListTile(
        onTap: () => _openDetail(scan),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Image.file(
            File(scan.imagePath),
            width: 56,
            height: 56,
            // decode a small copy, not the full-size photo
            cacheWidth: thumbnailPixels(context, 56),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Icon(
              Icons.image_not_supported,
              size: 40,
              color: context.colors.textMuted,
            ),
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: DiseaseBadge(label: scan.predictedLabel),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(scan.confidence * 100).toStringAsFixed(0)}% confidence'
              '  ·  ${formatDateTime(scan.scannedAt)}',
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [_statusChip(scan.synced), _feedbackChip(scan)],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Verify or edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEditor(scan),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline, color: context.colors.danger),
              onPressed: () => _deleteScan(scan),
            ),
          ],
        ),
      ),
    );
  }
}
