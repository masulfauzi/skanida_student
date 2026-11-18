import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'daftar_ijin_page.dart';
import 'firebase_options.dart';
import 'main.dart';
import 'notifikasi_store.dart';

/// Dipanggil saat pesan FCM datang ketika app di background/terminated.
/// Wajib top-level + `vm:entry-point` (berjalan di isolate terpisah).
/// Pesan bertipe "notification" sudah ditampilkan otomatis oleh sistem; di
/// sini pesan hanya dicatat ke riwayat lokal. JANGAN memakai context /
/// SessionManager di sini.
///
/// Catatan: di iOS handler ini tidak dipanggil untuk pesan "notification"
/// tanpa `content-available`; lihat [PushNotificationService.importDelivered].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await NotifikasiStore.addFromMessage(message);
  } catch (e) {
    debugPrint('Gagal mencatat notifikasi (background): $e');
  }
}

/// Dialog pengumuman (dipakai saat notifikasi di-tap & dari menu Notifikasi).
Future<void> showPengumumanDialog(
  BuildContext context, {
  required String judul,
  required String isi,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.campaign, color: Colors.deepPurple.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(judul.isEmpty ? 'Pengumuman' : judul)),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(isi, style: const TextStyle(fontSize: 15)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Seluruh logika push notification (FCM + notifikasi lokal saat foreground).
///
/// Payload `data` yang dikenali:
/// - `{type: "ijin", id: "<uuid>"}` → buka [DaftarIjinPage]
/// - `{type: "pengumuman", judul: "...", isi: "..."}` → dialog pengumuman
// Catatan: firebase_messaging 17 menandai getToken/onTokenRefresh/deleteToken
// sebagai deprecated demi register()/onRegistered, yang menghasilkan Firebase
// Installation ID (FID), bukan FCM token. Backend mengirim via FCM HTTP v1
// dengan target `token` (lihat issue.md Lampiran A), jadi API token tetap
// dipakai di sini. Migrasi ke FID harus dilakukan bersamaan dengan backend.
// ignore_for_file: deprecated_member_use

class PushNotificationService {
  static const String topicSiswa = 'siswa';
  static const String _savedTokenKey = 'fcm_token';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;
  static Future<void>? _unregistering;

  /// Data notifikasi yang di-tap tapi belum bisa diproses (app baru dibuka:
  /// masih di splash / login / ResumePresensiPage). Diproses di dashboard.
  static Map<String, dynamic>? _pendingData;

  static const List<AndroidNotificationChannel> _channels = [
    AndroidNotificationChannel(
      'status_izin',
      'Status Izin',
      description: 'Pemberitahuan saat pengajuan izin disetujui atau ditolak',
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      'pengumuman',
      'Pengumuman Sekolah',
      description: 'Pengumuman dari SMKN 2 Semarang',
      importance: Importance.high,
    ),
  ];

  /// Dipanggil sekali dari SplashScreen (bukan dari main(), agar startup
  /// tetap ringan).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
            final id = data.remove('_id');
            if (id is String) NotifikasiStore.markRead(id);
            handleTap(data);
          } catch (e) {
            debugPrint('Payload notifikasi tidak valid: $e');
          }
        },
      );

      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      for (final channel in _channels) {
        await android?.createNotificationChannel(channel);
      }

      // iOS: biarkan sistem menampilkan notifikasi walau app sedang terbuka.
      // (Android ditangani manual di _showForegroundNotification.)
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      FirebaseMessaging.onMessage.listen((m) async {
        await _record(m);
        await _showForegroundNotification(m);
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) async {
        await _record(m, read: true); // siswa sudah membukanya
        handleTap(m.data);
      });

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _record(initial, read: true);
        _pendingData = initial.data;
      }
      await importDelivered();
    } catch (e) {
      debugPrint('PushNotificationService.init gagal: $e');
    }
  }

  static Future<void> _record(RemoteMessage m, {bool read = false}) async {
    try {
      await NotifikasiStore.addFromMessage(m, read: read);
    } catch (e) {
      debugPrint('Gagal mencatat notifikasi: $e');
    }
  }

  /// iOS saja: pesan yang datang saat app tertutup tidak memicu kode Dart,
  /// jadi saat app dibuka/aktif kembali, salin notifikasi yang masih ada di
  /// Notification Center ke riwayat (hanya judul & ringkasan). Di Android
  /// sudah ditangani background handler.
  static Future<void> importDelivered() async {
    if (!Platform.isIOS) return;
    try {
      final delivered = await _local.getActiveNotifications();
      for (final n in delivered) {
        final title = n.title ?? '';
        final body = n.body ?? '';
        if (title.isEmpty && body.isEmpty) continue;
        await NotifikasiStore.addFromDelivered(title, body);
      }
    } catch (e) {
      debugPrint('Gagal impor notifikasi iOS: $e');
    }
  }

  /// Android saja. Di iOS sistem sudah menampilkannya (lihat [init]);
  /// menampilkan lagi di sini akan membuat notifikasi dobel.
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;

    final channelId =
        notification.android?.channelId ??
        (message.data['type'] == 'ijin' ? 'status_izin' : 'pengumuman');
    final channel = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _channels.last,
    );

    try {
      await _local.show(
        id: (message.messageId ?? '${DateTime.now()}').hashCode & 0x7fffffff,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
          ),
        ),
        // `_id` dipakai untuk menandai riwayat sebagai dibaca saat di-tap.
        payload: jsonEncode({...message.data, '_id': ?message.messageId}),
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
    }
  }

  /// Kirim token ke backend + subscribe topic. Aman dipanggil berkali-kali.
  /// Panggil TANPA await (fire-and-forget) agar tidak menunda UI.
  static Future<void> registerToken() async {
    // Tunggu unregister dari logout sebelumnya selesai, supaya deleteToken()
    // miliknya tidak menghapus token yang baru saja didaftarkan.
    await _unregistering;
    if (!SessionManager.isLoggedIn || SessionManager.authToken == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;
      await _sendToken(token);
      await messaging.subscribeToTopic(topicSiswa);
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      // iOS bisa melempar error jika APNs token belum siap. Abaikan; dicoba
      // lagi pada pembukaan app berikutnya.
      debugPrint('registerToken gagal: $e');
    }
  }

  static Future<void> _sendToken(String token) async {
    final authToken = SessionManager.authToken;
    if (authToken == null) return;
    try {
      final response = await http
          .post(
            Uri.parse('$API_BASE_URL/fcm-token'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'token': token,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedTokenKey, token);
      } else {
        debugPrint('POST /fcm-token gagal: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Kirim FCM token gagal: $e');
    }
  }

  /// Dipanggil dari [SessionManager.logout]. [authToken] harus diambil
  /// SEBELUM sesi dihapus. Tidak perlu di-await oleh tombol logout.
  static Future<void> unregister({required String? authToken}) {
    return _unregistering = _doUnregister(authToken).whenComplete(() {
      _unregistering = null;
    });
  }

  static Future<void> _doUnregister(String? authToken) async {
    try {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      _pendingData = null;

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_savedTokenKey);
      await prefs.remove(_savedTokenKey);

      if (token != null && authToken != null) {
        try {
          await http
              .delete(
                Uri.parse('$API_BASE_URL/fcm-token'),
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $authToken',
                },
                body: jsonEncode({'token': token}),
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('DELETE /fcm-token gagal: $e');
        }
      }

      await FirebaseMessaging.instance.unsubscribeFromTopic(topicSiswa);
      // Membuat token lama tidak valid, walau DELETE di atas gagal (offline).
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('unregister FCM gagal: $e');
    }
  }

  /// Dipanggil dari dashboard (MyHomePage.initState): proses notifikasi yang
  /// membuka app saat app sebelumnya mati.
  static void consumePending() {
    final data = _pendingData;
    _pendingData = null;
    if (data == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => handleTap(data));
  }

  static void handleTap(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null || !SessionManager.isLoggedIn) {
      _pendingData = data; // diproses nanti saat dashboard terbuka
      return;
    }

    switch (data['type']) {
      case 'ijin':
        navigator.push(
          MaterialPageRoute(builder: (_) => const DaftarIjinPage()),
        );
        break;
      case 'pengumuman':
        showPengumumanDialog(
          context,
          judul: data['judul']?.toString() ?? '',
          isi: data['isi']?.toString() ?? '',
        );
        break;
    }
  }
}
