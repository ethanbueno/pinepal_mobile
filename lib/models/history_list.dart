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

// The filters at the top of History. Empty fields match everything.
class HistoryFilter {
  final String? label; // matched against ScanRecord.shownLabel
  final DateTime? from; // a day, included
  final DateTime? to; // a day, included

  const HistoryFilter({this.label, this.from, this.to});

  bool get isEmpty => label == null && from == null && to == null;

  HistoryFilter withLabel(String? value) =>
      HistoryFilter(label: value, from: from, to: to);

  HistoryFilter withDates(DateTime? start, DateTime? end) =>
      HistoryFilter(label: label, from: start, to: end);

  bool matches(ScanRecord scan) {
    if (label != null && scan.shownLabel != label) return false;
    final day = DateTime(
      scan.scannedAt.year,
      scan.scannedAt.month,
      scan.scannedAt.day,
    );
    if (from != null && day.isBefore(_day(from!))) return false;
    if (to != null && day.isAfter(_day(to!))) return false;
    return true;
  }

  List<ScanRecord> apply(List<ScanRecord> scans) =>
      isEmpty ? scans : scans.where(matches).toList();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
