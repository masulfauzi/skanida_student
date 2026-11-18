import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu notifikasi di riwayat lokal.
class NotifikasiItem {
  NotifikasiItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.judul,
    required this.isi,
    required this.receivedAt,
    this.refId,
    this.read = false,
  });

  /// `messageId` FCM, atau `local-...` untuk item hasil impor iOS.
  final String id;

  /// `ijin` | `pengumuman` | `lain`.
  String type;
  String? refId;

  /// Judul & isi notifikasi apa adanya (dipakai untuk mencocokkan duplikat).
  String title;
  String body;

  /// Judul & isi untuk ditampilkan (pengumuman: versi lengkap dari `data`).
  String judul;
  String isi;

  final DateTime receivedAt;
  bool read;

  bool get isLocalImport => id.startsWith('local-');

  /// Data yang dipakai [PushNotificationService.handleTap].
  Map<String, dynamic> get tapData => {
    'type': type,
    if (refId != null) 'id': refId,
    'judul': judul,
    'isi': isi,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'refId': refId,
    'title': title,
    'body': body,
    'judul': judul,
    'isi': isi,
    'receivedAt': receivedAt.toIso8601String(),
    'read': read,
  };

  factory NotifikasiItem.fromJson(Map<String, dynamic> j) => NotifikasiItem(
    id: j['id'] as String,
    type: j['type'] as String? ?? 'lain',
    refId: j['refId'] as String?,
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    judul: j['judul'] as String? ?? '',
    isi: j['isi'] as String? ?? '',
    receivedAt:
        DateTime.tryParse(j['receivedAt'] as String? ?? '') ?? DateTime.now(),
    read: j['read'] as bool? ?? false,
  );

  factory NotifikasiItem.fromMessage(RemoteMessage m, {bool read = false}) {
    final data = m.data;
    final type = (data['type'] as String?) ?? 'lain';
    final title = m.notification?.title ?? data['judul']?.toString() ?? '';
    final body = m.notification?.body ?? data['isi']?.toString() ?? '';
    final isPengumuman = type == 'pengumuman';
    return NotifikasiItem(
      id: m.messageId ?? 'msg-${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      refId: data['id']?.toString(),
      title: title,
      body: body,
      judul: isPengumuman ? (data['judul']?.toString() ?? title) : title,
      isi: isPengumuman ? (data['isi']?.toString() ?? body) : body,
      receivedAt: m.sentTime ?? DateTime.now(),
      read: read,
    );
  }
}

/// Riwayat notifikasi yang disimpan **lokal di perangkat** (tidak ada di
/// server), per siswa. Ditulis juga dari background isolate FCM, karena itu
/// setiap baca/tulis selalu `reload()` dulu.
class NotifikasiStore {
  static const int _maxItems = 100;
  static const String _keyPrefix = 'notif_history_';

  /// Sama dengan key di SessionManager (main.dart); dibaca langsung dari
  /// prefs agar bisa dipakai di background isolate.
  static const String _siswaIdKey = 'siswa_id';

  /// Jumlah belum dibaca untuk badge lonceng di dashboard.
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Antrian tulis agar read-modify-write di isolate ini tidak saling timpa.
  static Future<void> _queue = Future.value();

  static Future<T> _serial<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  static Future<(SharedPreferences, String?)> _open() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final siswaId = prefs.getString(_siswaIdKey);
    return (prefs, siswaId == null ? null : '$_keyPrefix$siswaId');
  }

  static List<NotifikasiItem> _decode(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => NotifikasiItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Riwayat notifikasi rusak, direset: $e');
      return [];
    }
  }

  static Future<void> _save(
    SharedPreferences prefs,
    String key,
    List<NotifikasiItem> items,
  ) async {
    items.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    await prefs.setString(
      key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
    unreadCount.value = items.where((e) => !e.read).length;
  }

  /// Semua notifikasi siswa yang sedang login, terbaru di atas.
  static Future<List<NotifikasiItem>> list() => _serial(() async {
    final (prefs, key) = await _open();
    if (key == null) return <NotifikasiItem>[];
    final items = _decode(prefs, key)
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    unreadCount.value = items.where((e) => !e.read).length;
    return items;
  });

  static Future<void> refreshUnreadCount() async {
    try {
      await list();
    } catch (e) {
      debugPrint('Gagal membaca riwayat notifikasi: $e');
    }
  }

  /// Catat pesan FCM. Aman dipanggil berkali-kali untuk pesan yang sama
  /// (background handler + tap): tidak dobel, status dibaca dipertahankan
  /// kecuali [read] true.
  static Future<void> addFromMessage(
    RemoteMessage message, {
    bool read = false,
  }) => _add(NotifikasiItem.fromMessage(message, read: read));

  /// iOS: catat notifikasi yang masih ada di Notification Center (tanpa
  /// `data`, jadi hanya judul & ringkasan).
  static Future<void> addFromDelivered(String title, String body) {
    final type = title.toLowerCase().startsWith('izin ')
        ? 'ijin'
        : 'pengumuman';
    return _add(
      NotifikasiItem(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        title: title,
        body: body,
        judul: title,
        isi: body,
        receivedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> _add(NotifikasiItem item) => _serial(() async {
    final (prefs, key) = await _open();
    if (key == null) return; // belum login: tidak dicatat
    final items = _decode(prefs, key);

    final sameId = items.where((e) => e.id == item.id).firstOrNull;
    if (sameId != null) {
      if (item.read && !sameId.read) {
        sameId.read = true;
        await _save(prefs, key, items);
      }
      return;
    }

    // Cocokkan dengan item lain yang isinya sama (impor iOS vs pesan FCM).
    // Jendela 14 hari: notifikasi bisa lama tertinggal di Notification Center.
    final cutoff = item.receivedAt.subtract(const Duration(days: 14));
    final twin = items.where((e) {
      return e.title == item.title &&
          e.body == item.body &&
          e.receivedAt.isAfter(cutoff) &&
          (e.isLocalImport || item.isLocalImport);
    }).firstOrNull;

    if (twin != null) {
      if (item.isLocalImport) return; // versi lengkap sudah ada
      // Ganti item impor (data minim) dengan versi lengkap dari FCM.
      items.remove(twin);
      item.read = item.read || twin.read;
    }

    items.add(item);
    await _save(prefs, key, items);
  });

  static Future<void> markRead(String id) => _serial(() async {
    final (prefs, key) = await _open();
    if (key == null) return;
    final items = _decode(prefs, key);
    final item = items.where((e) => e.id == id).firstOrNull;
    if (item == null || item.read) return;
    item.read = true;
    await _save(prefs, key, items);
  });

  static Future<void> markAllRead() => _serial(() async {
    final (prefs, key) = await _open();
    if (key == null) return;
    final items = _decode(prefs, key);
    if (items.every((e) => e.read)) return;
    for (final e in items) {
      e.read = true;
    }
    await _save(prefs, key, items);
  });
}
