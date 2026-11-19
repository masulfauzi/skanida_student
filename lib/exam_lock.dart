import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Baterai & koneksi perangkat (bar status halaman ujian).
class DeviceStatus {
  const DeviceStatus({
    this.battery,
    this.charging = false,
    this.network = 'other',
    this.validated = true,
  });

  /// Persen 0–100, `null` bila tidak diketahui.
  final int? battery;
  final bool charging;

  /// `wifi` | `cellular` | `ethernet` | `none` | `other`.
  final String network;

  /// `true` bila jaringan benar-benar tersambung ke internet.
  final bool validated;

  factory DeviceStatus.fromMap(Map<Object?, Object?> m) {
    final battery = m['battery'];
    return DeviceStatus(
      battery: battery is int && battery >= 0 ? battery : null,
      charging: m['charging'] == true,
      network: (m['network'] as String?) ?? 'other',
      validated: m['validated'] != false,
    );
  }
}

/// Pembungkus MethodChannel `skanida/exam_lock` (MainActivity.kt) untuk
/// mengunci aplikasi selama Ujian Online. Hanya Android; di platform lain
/// semua pemanggilan tidak melakukan apa-apa.
class ExamLock {
  static const MethodChannel _channel = MethodChannel('skanida/exam_lock');

  static const int stateNone = 0;

  static bool get supported => Platform.isAndroid;

  /// Dipanggil ketika pengguna menekan Home / Recent (`onUserLeaveHint`).
  static VoidCallback? onUserLeave;

  /// Dipanggil saat aplikasi masuk/keluar split-screen, jendela mengambang,
  /// atau picture-in-picture (argumen: sedang multi-window atau tidak).
  static ValueChanged<bool>? onMultiWindowChanged;

  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'userLeaveHint':
          onUserLeave?.call();
        case 'multiWindowChanged':
          onMultiWindowChanged?.call(call.arguments == true);
      }
    });
  }

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!supported) return null;
    _ensureHandler();
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('ExamLock.$method gagal: $e');
      return null;
    }
  }

  /// Minta Android menyematkan aplikasi (screen pinning).
  static Future<bool> start() async =>
      await _invoke<bool>('startLockTask') ?? false;

  static Future<void> stop() => _invoke<void>('stopLockTask');

  /// 0 = tidak disematkan, 1 = locked (device owner), 2 = pinned.
  static Future<int> state() async =>
      await _invoke<int>('lockTaskState') ?? stateNone;

  static Future<void> setSecure(bool secure) =>
      _invoke<void>('setSecure', secure);

  /// `true` bila aplikasi berjalan di split-screen / jendela mengambang / PiP.
  static Future<bool> isMultiWindow() async =>
      await _invoke<bool>('isMultiWindow') ?? false;

  /// Sembunyikan jendela overlay aplikasi lain (Android 12+).
  static Future<void> setHideOverlays(bool hide) =>
      _invoke<void>('setHideOverlays', hide);

  /// Tutup paksa aplikasi.
  static Future<void> forceClose() => _invoke<void>('forceClose');

  /// Baterai & koneksi saat ini, `null` bila tidak tersedia.
  static Future<DeviceStatus?> deviceStatus() async {
    final m = await _invoke<Map<Object?, Object?>>('deviceStatus');
    return m == null ? null : DeviceStatus.fromMap(m);
  }

  /// `false` bila layar sedang mati.
  static Future<bool> isInteractive() async =>
      await _invoke<bool>('isInteractive') ?? true;
}
