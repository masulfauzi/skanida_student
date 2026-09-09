import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a pending presensi selfie to disk so it survives an Android
/// process death (the OS killing the whole app process while the native
/// camera app is in the foreground), instead of only living in memory.
class PresensiDraft {
  static const _kPendingPath = 'pending_presensi_photo_path';
  static const _kPendingSiswaId = 'pending_presensi_siswa_id';
  static const _kPendingSavedAt = 'pending_presensi_saved_at';

  static const _maxAge = Duration(hours: 6);

  static Future<String> save({
    required Uint8List bytes,
    required String siswaId,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/pending_presensi_selfie.jpg');
    await file.writeAsBytes(bytes, flush: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingPath, file.path);
    await prefs.setString(_kPendingSiswaId, siswaId);
    await prefs.setInt(_kPendingSavedAt, DateTime.now().millisecondsSinceEpoch);

    return file.path;
  }

  /// Returns `{'path': ..., 'siswaId': ...}` if a pending draft exists and
  /// is still fresh, otherwise `null` (and clears any stale/broken draft).
  static Future<Map<String, String>?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kPendingPath);
    final siswaId = prefs.getString(_kPendingSiswaId);
    final savedAt = prefs.getInt(_kPendingSavedAt);

    if (path == null || siswaId == null || savedAt == null) {
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      await clear();
      return null;
    }

    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    if (age > _maxAge.inMilliseconds) {
      await clear();
      return null;
    }

    return {'path': path, 'siswaId': siswaId};
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_kPendingPath);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await prefs.remove(_kPendingPath);
    await prefs.remove(_kPendingSiswaId);
    await prefs.remove(_kPendingSavedAt);
  }
}
