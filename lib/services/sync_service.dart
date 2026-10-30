import 'api_client.dart';
import 'app_settings.dart';
import 'database_helper.dart';

// What one sync run did
class SyncResult {
  final int uploaded;
  final int failed;
  final String? error;

  // The token was refused, so the farmer has to sign in again
  final bool sessionExpired;

  const SyncResult({
    this.uploaded = 0,
    this.failed = 0,
    this.error,
    this.sessionExpired = false,
  });

  bool get ok => error == null;

  // One line for the Settings screen
  String get summary {
    if (error != null) {
      return uploaded > 0
          ? 'Synced $uploaded ${_scans(uploaded)}, then stopped: $error'
          : error!;
    }
    if (uploaded == 0) return 'Everything is already synced.';
    return 'Synced $uploaded ${_scans(uploaded)}.';
  }

  static String _scans(int n) => n == 1 ? 'scan' : 'scans';
}

// Uploads the scans that are still Pending, oldest first, one at a time.
// A scan is marked Synced only after the server accepted it, so a dropped
// connection never loses anything: the scan is simply sent again next time.
class SyncService {
  SyncService({required this.api, DatabaseHelper? db, AppSettings? settings})
    : db = db ?? DatabaseHelper.instance,
      settings = settings ?? AppSettings.instance;

  final ApiClient api;
  final DatabaseHelper db;
  final AppSettings settings;

  Future<SyncResult> syncPending({required String token}) async {
    final pending = await db.getUnsyncedScans();
    var uploaded = 0;
    var failed = 0;
    String? firstError;

    for (final scan in pending) {
      try {
        await api.uploadScan(
          scan,
          token: token,
          // Scans taken before the farm details existed get the current ones
          farmName: scan.farmName ?? _nonEmpty(settings.farmName),
          municipality: scan.municipality ?? settings.municipality,
        );
        await db.markSynced(scan.scanUuid);
        uploaded++;
      } on ApiException catch (e) {
        if (e.unauthorized) {
          return SyncResult(
            uploaded: uploaded,
            failed: failed,
            error: 'Your session expired. Sign in again.',
            sessionExpired: true,
          );
        }
        if (e.offline) {
          // The next scans would fail the same way, so stop and keep them Pending
          return SyncResult(
            uploaded: uploaded,
            failed: failed,
            error: e.message,
          );
        }
        // The server refused this one scan; the others may still be fine
        failed++;
        firstError ??= e.message;
      }
    }

    return SyncResult(
      uploaded: uploaded,
      failed: failed,
      error: failed > 0
          ? '$failed ${failed == 1 ? 'scan was' : 'scans were'} not accepted'
                ' ($firstError)'
          : null,
    );
  }

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;
}
