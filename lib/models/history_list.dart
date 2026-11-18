import 'scan_record.dart';
import 'server_scan.dart';

// History in one list: this phone's scans, each with the officer's check from
// the server's copy, plus the farmer's scans that are only on the server
// (taken on the web or another phone). Newest first. Kept apart from the
// screen so it can be tested without a phone.
List<ScanRecord> mergeHistory(List<ScanRecord> phone, List<ServerScan> server) {
  final byUuid = {
    for (final scan in server)
      if (scan.scanUuid.isNotEmpty) scan.scanUuid: scan,
  };
  final onPhone = <String>{};
  final list = <ScanRecord>[];

  for (final scan in phone) {
    onPhone.add(scan.scanUuid);
    final copy = byUuid[scan.scanUuid];
    list.add(copy == null ? scan : scan.withServer(copy));
  }
  for (final scan in byUuid.values) {
    // an older server sends too little to show the scan on its own
    if (onPhone.contains(scan.scanUuid) || !scan.hasDetails) continue;
    list.add(ScanRecord.fromServer(scan));
  }

  list.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  return list;
}

// Where a scan is: on this phone (synced or not yet), or online (on the server:
// synced from this phone, or taken on the web or another phone). A synced phone
// scan is in both. Same words as the Home dashboard's switch.
enum HistorySource { all, phone, online }

// The filters at the top of History, and the order. Empty fields match everything.
class HistoryFilter {
  final String? label; // matched against ScanRecord.shownLabel
  final DateTime? from; // a day, included
  final DateTime? to; // a day, included
  final HistorySource source;
  final bool oldestFirst; // the list is newest first unless this is set

  const HistoryFilter({
    this.label,
    this.from,
    this.to,
    this.source = HistorySource.all,
    this.oldestFirst = false,
  });

  // no filter (the order does not hide anything)
  bool get isEmpty =>
      label == null &&
      from == null &&
      to == null &&
      source == HistorySource.all;

  HistoryFilter _copy({
    String? Function()? label,
    DateTime? Function()? from,
    DateTime? Function()? to,
    HistorySource? source,
    bool? oldestFirst,
  }) => HistoryFilter(
    label: label == null ? this.label : label(),
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
    source: source ?? this.source,
    oldestFirst: oldestFirst ?? this.oldestFirst,
  );

  HistoryFilter withLabel(String? value) => _copy(label: () => value);

  HistoryFilter withDates(DateTime? start, DateTime? end) =>
      _copy(from: () => start, to: () => end);

  HistoryFilter withSource(HistorySource value) => _copy(source: value);

  HistoryFilter withOldestFirst(bool value) => _copy(oldestFirst: value);

  // the filters cleared, the order kept
  HistoryFilter cleared() => HistoryFilter(oldestFirst: oldestFirst);

  bool matches(ScanRecord scan) {
    if (label != null && scan.shownLabel != label) return false;
    if (source == HistorySource.phone && !scan.onPhone) return false;
    if (source == HistorySource.online && scan.onPhone && !scan.synced) {
      return false;
    }
    final day = DateTime(
      scan.scannedAt.year,
      scan.scannedAt.month,
      scan.scannedAt.day,
    );
    if (from != null && day.isBefore(_day(from!))) return false;
    if (to != null && day.isAfter(_day(to!))) return false;
    return true;
  }

  // scans comes newest first (mergeHistory)
  List<ScanRecord> apply(List<ScanRecord> scans) {
    final shown = isEmpty ? scans : scans.where(matches).toList();
    return oldestFirst ? shown.reversed.toList() : shown;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
