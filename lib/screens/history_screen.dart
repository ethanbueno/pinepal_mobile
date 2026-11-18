import 'dart:io';

import 'package:flutter/material.dart';

import '../models/history_list.dart';
import '../models/scan_record.dart';
import '../models/server_scan.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';
import '../services/label_service.dart';
import '../services/server_scans.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/tile_card.dart';
import '../widgets/disease_badge.dart';
import '../widgets/empty_state.dart';
import '../utils/format.dart';
import '../utils/image_size.dart';
import 'edit_scan_screen.dart';
import 'result_detail_screen.dart';
import '../widgets/pinepal_loader.dart';

// List of the farmer's scans: this phone's, plus the ones taken on the web or
// another phone (from the server, once it has been reached). Shows the
// officer's check on each, and can be filtered by condition and date. Tap a
// scan for the full report; this phone's scans can also be given feedback,
// deleted, cleared or exported to CSV.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.server});

  // Leave empty to use the shared one (tests pass their own)
  final ServerScans? server;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final _server = widget.server ?? ServerScans();

  late Future<List<ScanRecord>> _phoneScans;
  // The server's copy: the saved one first, then the fresh one. Empty when
  // there is nobody to ask for or it was never reached.
  List<ServerScan> _serverScans = const [];
  Map<String, int> _summary = const {'total': 0, 'checked': 0, 'correct': 0};
  List<String> _labels = const [];
  HistoryFilter _filter = const HistoryFilter();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _phoneScans = DatabaseHelper.instance.getAllScans();
    _loadSummary();
    _loadServer();
    LabelService.load().then((labels) {
      if (mounted) setState(() => _labels = labels);
    }, onError: (_) {});
  }

  Future<void> _loadSummary() async {
    final summary = await DatabaseHelper.instance.getSummary();
    if (mounted) setState(() => _summary = summary);
  }

  // The saved copy right away, then the server's (stale-while-revalidate).
  // Offline or signed out, the saved copy (or nothing) stays.
  Future<void> _loadServer() async {
    final saved = await _server.saved();
    if (saved != null && mounted) {
      setState(() => _serverScans = saved.scans);
    }
    try {
      final fresh = await _server.fetch();
      if (mounted) setState(() => _serverScans = fresh);
    } catch (_) {
      // keep what is shown
    }
  }

  void _reload() {
    setState(() {
      _phoneScans = DatabaseHelper.instance.getAllScans();
    });
    _loadSummary();
    SyncController.instance.onLocalChange();
  }

  Future<void> _refresh() async {
    _reload();
    await Future.wait([_phoneScans, _loadServer()]);
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
      'Delete This Scan?',
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
      "Clear this phone's history?",
      'Are you sure you want to delete all ${scans.length} scans on this '
          'phone? They and their photos will be removed from the phone '
          'permanently. Scans that were already synced stay on the server.',
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

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _filter.from == null || _filter.to == null
          ? null
          : DateTimeRange(start: _filter.from!, end: _filter.to!),
      helpText: 'Show scans from',
    );
    if (picked == null || !mounted) return;
    setState(() => _filter = _filter.withDates(picked.start, picked.end));
  }

  // Export: what History is showing (its source, condition and date filters),
  // optionally only officer-verified scans, as CSV or Excel. Like the
  // website's Export page. The file goes to the share sheet.
  Future<void> _openExport(List<ScanRecord> all) async {
    if (_exporting) return;
    final filtered = _filter.apply(all);
    if (filtered.isEmpty) {
      _showMessage('Nothing to export with these filters.');
      return;
    }

    var verifiedOnly = false;
    var format = ExportFormat.csv;
    final from = _filter.from;
    final to = _filter.to;
    final summary = [
      switch (_filter.source) {
        HistorySource.all => 'All Scans',
        HistorySource.phone => 'On This Phone',
        HistorySource.online => 'Online',
      },
      _filter.label == null
          ? 'every condition'
          : LabelService.pretty(_filter.label!),
      from == null || to == null
          ? 'any date'
          : (from == to
                ? formatDate(from)
                : '${formatDate(from)} – ${formatDate(to)}'),
    ].join(' · ');

    final picked = await showModalBottomSheet<(List<ScanRecord>, ExportFormat)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final records = verifiedOnly
              ? filtered.where((s) => s.isOfficerVerified).toList()
              : filtered;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.page,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Export Scans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Uses the filters on History: $summary',
                    style: TextStyle(
                      color: sheetContext.colors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified by an Officer Only'),
                    value: verifiedOnly,
                    onChanged: (v) => setSheet(() => verifiedOnly = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ExportFormat>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ExportFormat.csv,
                        label: Text('CSV'),
                      ),
                      ButtonSegment(
                        value: ExportFormat.xlsx,
                        label: Text('Excel (XLSX)'),
                      ),
                    ],
                    selected: {format},
                    onSelectionChanged: (v) => setSheet(() => format = v.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: records.isEmpty
                        ? null
                        : () => Navigator.pop(sheetContext, (records, format)),
                    icon: const Icon(Icons.ios_share),
                    label: Text(
                      records.isEmpty
                          ? 'No Scans to Export'
                          : 'Export ${records.length} '
                                '${records.length == 1 ? 'scan' : 'scans'}',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final file = await ExportService.export(picked.$1, picked.$2);
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

  // Synced (green) or Pending (grey), or for a scan that is only on the
  // server, where it was taken
  Widget _statusChip(ScanRecord scan) {
    if (!scan.onPhone) {
      final web = scan.imageSource == 'Web';
      return _chip(
        web ? 'From the web' : 'From another phone',
        context.colors.textMuted,
        icon: web ? Icons.language : Icons.smartphone_outlined,
      );
    }
    return _chip(
      scan.synced ? 'Synced' : 'Pending',
      scan.synced ? context.colors.success : context.colors.textMuted,
    );
  }

  // Checked or corrected by an agricultural officer on the web dashboard
  Widget? _officerChip(ScanRecord scan) {
    if (!scan.isOfficerVerified) return null;
    return scan.isOfficerCorrected
        ? _chip(
            'Corrected by officer',
            context.colors.warning,
            icon: Icons.edit_note,
          )
        : _chip(
            'Checked by officer',
            context.colors.success,
            icon: Icons.verified_outlined,
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
      future: _phoneScans,
      builder: (context, snapshot) {
        final phoneScans = snapshot.data ?? [];
        final all = mergeHistory(phoneScans, _serverScans);
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
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
                  tooltip: 'Export (CSV or Excel)',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _openExport(all),
                ),
              if (phoneScans.isNotEmpty)
                IconButton(
                  tooltip: "Clear this phone's history",
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () => _clearHistory(phoneScans),
                ),
            ],
          ),
          body: Column(
            children: [
              _buildSummaryBar(all),
              if (all.isNotEmpty) _buildSourceBar(),
              if (all.isNotEmpty) _buildFilterBar(),
              Expanded(child: _buildBody(snapshot, all)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryBar(List<ScanRecord> all) {
    final officer = all.where((s) => s.isOfficerVerified).length;
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
          stat('${all.length}', 'scans'),
          stat('$checked', 'checked'),
          stat(accuracy, 'accuracy'),
          stat('$officer', 'by officer'),
        ],
      ),
    );
  }

  // Where the scans are (all, this phone, online), like the Home switch, and
  // the order (newest or oldest first).
  Widget _buildSourceBar() {
    final oldest = _filter.oldestFirst;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<HistorySource>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: HistorySource.all, label: Text('All')),
                ButtonSegment(
                  value: HistorySource.phone,
                  icon: Icon(Icons.phone_android),
                  label: Text('On This Phone'),
                ),
                ButtonSegment(
                  value: HistorySource.online,
                  icon: Icon(Icons.cloud_outlined),
                  label: Text('Online'),
                ),
              ],
              selected: {_filter.source},
              onSelectionChanged: (picked) =>
                  setState(() => _filter = _filter.withSource(picked.first)),
            ),
          ),
          IconButton(
            tooltip: oldest ? 'Oldest First' : 'Newest First',
            icon: Icon(oldest ? Icons.north : Icons.south),
            onPressed: () =>
                setState(() => _filter = _filter.withOldestFirst(!oldest)),
          ),
        ],
      ),
    );
  }

  // The date range, then one chip per condition. Scrolls sideways.
  Widget _buildFilterBar() {
    final from = _filter.from;
    final to = _filter.to;
    final String dates;
    if (from == null || to == null) {
      dates = 'Any date';
    } else if (from == to) {
      dates = formatDate(from);
    } else {
      dates = '${formatDate(from)} – ${formatDate(to)}';
    }

    Widget labelChip(String? label) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label == null ? 'All' : LabelService.pretty(label)),
          selected: _filter.label == label,
          onSelected: (_) => setState(() => _filter = _filter.withLabel(label)),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.sm,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: from == null
                ? ActionChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(dates),
                    onPressed: _pickDates,
                  )
                : InputChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(dates),
                    selected: true,
                    onPressed: _pickDates,
                    deleteButtonTooltipMessage: 'Any date',
                    onDeleted: () =>
                        setState(() => _filter = _filter.withDates(null, null)),
                  ),
          ),
          labelChip(null),
          for (final label in _labels) labelChip(label),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<ScanRecord>> snapshot,
    List<ScanRecord> all,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: PinePalLoader(label: 'Loading scans...'));
    }
    if (snapshot.hasError) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could Not Load Scans',
            text: '${snapshot.error}',
            action: OutlinedButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final scans = _filter.apply(all);
    if (scans.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            if (all.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'No Scans Yet',
                text: 'Scans you take with the camera button are saved here.',
              )
            else
              EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'No Scans Match',
                text: 'Try another source, condition or date.',
                action: OutlinedButton(
                  onPressed: () => setState(() => _filter = _filter.cleared()),
                  child: const Text('Clear Filters'),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.page),
        itemCount: scans.length,
        itemBuilder: (context, index) => _buildTile(scans[index]),
      ),
    );
  }

  Widget _thumbnail(ScanRecord scan) {
    Widget missing(BuildContext context, Object error, StackTrace? stack) =>
        SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            Icons.image_not_supported,
            size: 40,
            color: context.colors.textMuted,
          ),
        );
    // decode a small copy, not the full-size photo
    final pixels = thumbnailPixels(context, 56);
    if (!scan.onPhone) {
      final url = scan.imageUrl;
      if (url == null) return missing(context, 'no photo', null);
      return Image.network(
        url,
        width: 56,
        height: 56,
        cacheWidth: pixels,
        fit: BoxFit.cover,
        errorBuilder: missing,
      );
    }
    return Image.file(
      File(scan.imagePath),
      width: 56,
      height: 56,
      cacheWidth: pixels,
      fit: BoxFit.cover,
      errorBuilder: missing,
    );
  }

  Widget _buildTile(ScanRecord scan) {
    final officer = _officerChip(scan);
    return TileCard(
      child: ListTile(
        onTap: () => _openDetail(scan),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: _thumbnail(scan),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: DiseaseBadge(label: scan.shownLabel),
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
              children: [
                _statusChip(scan),
                ?officer,
                if (scan.onPhone || scan.hasFeedback) _feedbackChip(scan),
              ],
            ),
          ],
        ),
        // only this phone's own scans can be changed here
        trailing: !scan.onPhone
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Verify or Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openEditor(scan),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.colors.danger,
                    ),
                    onPressed: () => _deleteScan(scan),
                  ),
                ],
              ),
      ),
    );
  }
}
