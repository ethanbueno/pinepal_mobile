import 'package:flutter/material.dart';

import '../models/dashboard_stats.dart';
import '../services/api_client.dart';
import '../services/auth_controller.dart';
import '../services/database_helper.dart';
import '../services/server_scans.dart';
import '../services/label_service.dart';
import '../services/sync_controller.dart';
import '../theme/app_colors.dart';
import 'disease_badge.dart';
import 'empty_state.dart';
import '../utils/map_area.dart';
import 'scan_heat_map.dart';
import 'section_card.dart';
import 'pinepal_loader.dart';

// Where the dashboard numbers come from
enum DashboardSource {
  phone, // this phone's SQLite database, works offline
  online, // the farmer's scans on the server (MySQL), needs internet
}

// The farmer's own numbers: scans per condition, the last 8 weeks and a map
// of where they scanned. Only this farmer's scans, never other farms'; the
// province-wide map and analytics are on the web dashboard.
// Shown right on the Home tab. It is not scrollable itself: it sits inside the
// Home tab's list. Give it a new key to load the numbers again.
class FarmDashboard extends StatefulWidget {
  const FarmDashboard({super.key, this.api, this.auth, this.loadPhoneScans});

  // Leave empty to use the shared ones (tests pass their own)
  final ApiClient? api;
  final AuthController? auth;
  final Future<List<DashboardScan>> Function()? loadPhoneScans;

  @override
  State<FarmDashboard> createState() => _FarmDashboardState();
}

class _DashboardData {
  final DashboardStats stats;
  final List<String> labels; // labels.txt, the order of the bars
  // Online only: when these numbers are the saved copy, the time it was saved
  final DateTime? savedAt;

  const _DashboardData(this.stats, this.labels, {this.savedAt});
}

class _FarmDashboardState extends State<FarmDashboard> {
  late final _server = ServerScans(api: widget.api, auth: widget.auth);

  DashboardSource _source = DashboardSource.phone;
  late Future<_DashboardData> _data = _load();

  Future<List<DashboardScan>> _phoneScans() async {
    if (widget.loadPhoneScans != null) return widget.loadPhoneScans!();
    final records = await DatabaseHelper.instance.getAllScans();
    return records.map(DashboardScan.fromRecord).toList();
  }

  Future<List<DashboardScan>> _onlineScans() async {
    final scans = await _server.fetch();
    return scans.map(DashboardScan.fromServer).toList();
  }

  Future<_DashboardData> _load() async {
    final labels = await LabelService.load();
    if (_source == DashboardSource.phone) {
      return _DashboardData(DashboardStats(await _phoneScans()), labels);
    }

    // Online: show the saved copy right away when there is one, and fetch the
    // fresh numbers in the background (stale-while-revalidate)
    final saved = await _server.saved();
    if (saved != null) {
      _refreshOnline(labels);
      return _DashboardData(
        DashboardStats(saved.scans.map(DashboardScan.fromServer).toList()),
        labels,
        savedAt: saved.savedAt,
      );
    }
    return _DashboardData(DashboardStats(await _onlineScans()), labels);
  }

  // The background half of _load: swap in the server's numbers once they
  // arrive. If the server cannot be reached the saved copy stays on screen,
  // with its date under the toggle.
  Future<void> _refreshOnline(List<String> labels) async {
    try {
      final scans = await _onlineScans();
      if (!mounted || _source != DashboardSource.online) return;
      setState(() {
        _data = Future.value(_DashboardData(DashboardStats(scans), labels));
      });
    } catch (_) {
      // offline or signed out: keep showing the saved copy
    }
  }

  void _show(DashboardSource source) {
    setState(() {
      _source = source;
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The toggle between the phone's data and the server's data
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DashboardSource>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: DashboardSource.phone,
                icon: Icon(Icons.phone_android),
                label: Text('On This Phone'),
              ),
              ButtonSegment(
                value: DashboardSource.online,
                icon: Icon(Icons.cloud_outlined),
                label: Text('Online'),
              ),
            ],
            selected: {_source},
            onSelectionChanged: (picked) => _show(picked.first),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SourceNote(source: _source),
        const SizedBox(height: AppSpacing.lg),
        FutureBuilder<_DashboardData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.section),
                child: Center(child: PinePalLoader(size: 72)),
              );
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Cannot Show the Online Data',
                text: snapshot.error.toString(),
                action: OutlinedButton(
                  onPressed: () => _show(DashboardSource.phone),
                  child: const Text('Show the Phone Data'),
                ),
              );
            }
            final data = snapshot.data!;
            final savedNote = data.savedAt == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Showing your saved numbers from '
                      '${_savedLabel(data.savedAt!)}. They update when the '
                      'server answers.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted,
                      ),
                    ),
                  );
            if (data.stats.total == 0) {
              return EmptyState(
                icon: Icons.eco_outlined,
                title: 'No Scans Yet',
                text: _source == DashboardSource.phone
                    ? 'Scan a pineapple and your numbers will show up here.'
                    : 'None of your scans are on the server yet. Sync them '
                          'from Settings.',
              );
            }
            if (savedNote == null) return _DashboardBody(data: data);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                savedNote,
                _DashboardBody(data: data),
              ],
            );
          },
        ),
      ],
    );
  }
}

// "17 Nov, 3:05 PM" for the saved-copy note
String _savedLabel(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${months[t.month - 1]}, $hour:$minute '
      '${t.hour < 12 ? 'AM' : 'PM'}';
}

// One line under the toggle that says what the farmer is looking at
class _SourceNote extends StatelessWidget {
  final DashboardSource source;

  const _SourceNote({required this.source});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 13, color: context.colors.textMuted);
    if (source == DashboardSource.phone) {
      return Text(
        'Scans saved on this phone. Works without internet.',
        style: style,
      );
    }
    // Scans still waiting to sync are not on the server yet
    return ListenableBuilder(
      listenable: SyncController.instance,
      builder: (context, _) {
        final pending = SyncController.instance.pending;
        return Text(
          pending == 0
              ? 'Your scans on the PinePal server, with any corrections '
                    'from your agricultural officer.'
              : 'Your scans on the PinePal server. $pending '
                    '${pending == 1 ? 'scan' : 'scans'} on this phone '
                    '${pending == 1 ? 'is' : 'are'} not uploaded yet.',
          style: style,
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final _DashboardData data;

  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    return Column(
      children: [
        Row(
          children: [
            _StatTile(value: stats.total, label: 'Scans'),
            const SizedBox(width: AppSpacing.sm),
            _StatTile(value: stats.diseased, label: 'Problems'),
            const SizedBox(width: AppSpacing.sm),
            _StatTile(value: stats.healthy, label: 'Healthy'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ByConditionCard(counts: stats.countsByLabel(data.labels)),
        const SizedBox(height: AppSpacing.md),
        _TrendCard(stats: stats),
        const SizedBox(height: AppSpacing.md),
        _MapCard(stats: stats),
      ],
    );
  }
}

// A big number with a small label under it
class _StatTile extends StatelessWidget {
  final int value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// Small round color mark, same as the legend dots on the web
class _ColorDot extends StatelessWidget {
  final Color color;

  const _ColorDot(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// One bar per condition, longest bar = most scans
class _ByConditionCard extends StatelessWidget {
  final Map<String, int> counts;

  const _ByConditionCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, n) => sum + n);
    final most = counts.values.fold(0, (a, b) => a > b ? a : b);

    return SectionCard(
      title: 'Scans by Condition',
      children: [
        for (final entry in counts.entries) ...[
          Builder(
            builder: (context) {
              final color =
                  diseaseColors[entry.key] ?? context.colors.textMuted;
              final percent = total == 0 ? 0 : entry.value * 100 / total;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ColorDot(color),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          LabelService.pretty(entry.key),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${entry.value}  (${percent.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: most == 0 ? 0 : entry.value / most,
                      minHeight: 8,
                      color: color,
                      backgroundColor: context.colors.surface2,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

// Scans per week for the last 8 weeks, healthy and with a problem stacked,
// plus the conditions that went up or down this month
class _TrendCard extends StatelessWidget {
  final DashboardStats stats;

  const _TrendCard({required this.stats});

  static const _chartHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final weeks = stats.weekly();
    final most = weeks.fold(0, (a, w) => a > w.total ? a : w.total);
    final healthyColor =
        diseaseColors[DashboardStats.healthyLabel] ?? context.colors.success;
    final problemColor = context.colors.danger;
    final muted = TextStyle(fontSize: 11, color: context.colors.textMuted);

    return SectionCard(
      title: 'Last 8 weeks',
      children: [
        SizedBox(
          height: _chartHeight + 44, // room for the count and the date
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final week in weeks)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          week.total == 0 ? '' : '${week.total}',
                          style: muted,
                        ),
                        const SizedBox(height: 2),
                        // problems on top, healthy at the bottom
                        Container(
                          height: most == 0
                              ? 0
                              : _chartHeight * week.diseased / most,
                          color: problemColor,
                        ),
                        Container(
                          height: most == 0
                              ? 0
                              : _chartHeight * week.healthy / most,
                          color: healthyColor,
                        ),
                        // a thin base line so empty weeks still show
                        Container(height: 1, color: context.colors.line),
                        const SizedBox(height: 4),
                        Text(
                          '${week.start.day}/${week.start.month}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _ColorDot(healthyColor),
            const SizedBox(width: AppSpacing.xs),
            Text('Healthy', style: muted.copyWith(fontSize: 13)),
            const SizedBox(width: AppSpacing.lg),
            _ColorDot(problemColor),
            const SizedBox(width: AppSpacing.xs),
            Text('Disease or disorder', style: muted.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Last 30 days',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._changeLines(context),
      ],
    );
  }

  List<Widget> _changeLines(BuildContext context) {
    final changes = stats.changes();
    if (changes.isEmpty) {
      return [
        Text(
          'No diseases or disorders went up or down compared to the 30 days '
          'before.',
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
      ];
    }
    return [
      for (final change in changes)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              // more of a disease is bad news, fewer is good news
              Icon(
                change.difference > 0 ? Icons.trending_up : Icons.trending_down,
                size: 20,
                color: change.difference > 0
                    ? context.colors.danger
                    : context.colors.success,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${LabelService.pretty(change.label)}: ${change.now} '
                  '${change.difference > 0 ? 'up' : 'down'} from ${change.before}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

class _MapCard extends StatelessWidget {
  final DashboardStats stats;

  const _MapCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final mapped = stats.withGps;
    final missing = stats.total - mapped.length;
    final outside = mapped
        .where((scan) => !isInLockedArea(scan.latitude, scan.longitude))
        .length;
    final muted = TextStyle(fontSize: 13, color: context.colors.textMuted);

    return SectionCard(
      title: 'Scan Heat Map',
      children: [
        if (mapped.isEmpty)
          Text('None of these scans have a GPS location.', style: muted)
        else ...[
          // A still preview, so dragging here scrolls the page. Tapping it
          // opens the full screen map, where it can be moved and zoomed.
          Stack(
            children: [
              // its own layer, so scrolling Home does not redraw the map
              RepaintBoundary(
                child: ScanHeatMap(
                  scans: mapped,
                  height: 240,
                  interactive: false,
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanHeatMapScreen(scans: mapped),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: context.colors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 14,
                          color: context.colors.text,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stronger color means more scans in that area. Tap the map to '
            'open it, then tap a dot to see what was found there.',
            style: muted,
          ),
        ],
        if (outside > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$outside ${outside == 1 ? 'scan is' : 'scans are'} outside '
            '$lockedAreaName and not shown.',
            style: muted,
          ),
        ],
        if (missing > 0 && mapped.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$missing ${missing == 1 ? 'scan has' : 'scans have'} no GPS '
            'location and ${missing == 1 ? 'is' : 'are'} not on the map.',
            style: muted,
          ),
        ],
      ],
    );
  }
}
