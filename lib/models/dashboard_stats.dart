import 'scan_record.dart';
import 'server_scan.dart';

// The few things the farmer dashboard needs from one scan. It can come from
// this phone's SQLite database or from the server, so both are turned into
// this same shape and the charts don't care where the data came from.
class DashboardScan {
  // The condition that is counted: the corrected one when there is one,
  // otherwise what the model said
  final String label;
  final DateTime scannedAt;

  // 0.0, 0.0 means no GPS fix, same as in ScanRecord
  final double latitude;
  final double longitude;

  const DashboardScan({
    required this.label,
    required this.scannedAt,
    required this.latitude,
    required this.longitude,
  });

  bool get hasGps => latitude != 0.0 || longitude != 0.0;

  // On the phone, the farmer's own answer ("it is actually ...") wins
  factory DashboardScan.fromRecord(ScanRecord scan) {
    return DashboardScan(
      label: scan.verifiedLabel ?? scan.predictedLabel,
      scannedAt: scan.scannedAt,
      latitude: scan.latitude,
      longitude: scan.longitude,
    );
  }

  // From the server. It already picked the label: the officer's correction,
  // then the farmer's, then the model's.
  factory DashboardScan.fromServer(ServerScan scan) {
    return DashboardScan(
      label: scan.label,
      scannedAt: scan.scannedAt,
      latitude: scan.latitude,
      longitude: scan.longitude,
    );
  }
}

// One bar of the weekly chart
class WeekCount {
  final DateTime start; // Monday of that week
  final int healthy;
  final int diseased;

  const WeekCount(this.start, this.healthy, this.diseased);

  int get total => healthy + diseased;
}

// How one condition changed: the last 30 days against the 30 days before
class LabelChange {
  final String label;
  final int now;
  final int before;

  const LabelChange(this.label, this.now, this.before);

  int get difference => now - before;
}

// All the numbers on the dashboard, worked out from a list of scans.
// Kept apart from the screen so it can be tested without a phone.
class DashboardStats {
  static const healthyLabel = 'No_Disease';

  final List<DashboardScan> scans;
  final DateTime today;

  DashboardStats(this.scans, {DateTime? now})
    : today = _dateOnly(now ?? DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get total => scans.length;
  int get healthy => scans.where((s) => s.label == healthyLabel).length;
  int get diseased => total - healthy;

  // Scans that can go on the map
  List<DashboardScan> get withGps => scans.where((s) => s.hasGps).toList();

  // How many scans per condition, in the order of [labels] (labels.txt), so
  // the list never jumps around. A label missing from [labels] goes at the end.
  Map<String, int> countsByLabel(List<String> labels) {
    final counts = {for (final label in labels) label: 0};
    for (final scan in scans) {
      counts[scan.label] = (counts[scan.label] ?? 0) + 1;
    }
    return counts;
  }

  // The last [weeks] weeks (Monday to Sunday), oldest first, this week last
  List<WeekCount> weekly({int weeks = 8}) {
    final thisMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - DateTime.monday),
    );

    final result = <WeekCount>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final start = DateTime(
        thisMonday.year,
        thisMonday.month,
        thisMonday.day - 7 * i,
      );
      final end = DateTime(start.year, start.month, start.day + 7);
      var healthy = 0;
      var diseased = 0;
      for (final scan in scans) {
        if (scan.scannedAt.isBefore(start) || !scan.scannedAt.isBefore(end)) {
          continue;
        }
        scan.label == healthyLabel ? healthy++ : diseased++;
      }
      result.add(WeekCount(start, healthy, diseased));
    }
    return result;
  }

  // Diseases and disorders that went up or down: the last 30 days (today
  // included) against the 30 days before. Biggest change first, at most [max].
  List<LabelChange> changes({int max = 3}) {
    final start = DateTime(today.year, today.month, today.day - 29);
    final previousStart = DateTime(start.year, start.month, start.day - 30);

    final now = <String, int>{};
    final before = <String, int>{};
    for (final scan in scans) {
      if (scan.label == healthyLabel) continue;
      if (!scan.scannedAt.isBefore(start)) {
        now[scan.label] = (now[scan.label] ?? 0) + 1;
      } else if (!scan.scannedAt.isBefore(previousStart)) {
        before[scan.label] = (before[scan.label] ?? 0) + 1;
      }
    }

    final list = {...now.keys, ...before.keys}
        .map((label) => LabelChange(label, now[label] ?? 0, before[label] ?? 0))
        .where((change) => change.difference != 0)
        .toList();
    // biggest change first; the same change goes by name, so the order
    // never shuffles between refreshes
    list.sort((a, b) {
      final bySize = b.difference.abs().compareTo(a.difference.abs());
      return bySize != 0 ? bySize : a.label.compareTo(b.label);
    });
    return list.take(max).toList();
  }
}
