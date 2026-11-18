# Issue: Fitur Push Notification (status izin & pengumuman sekolah)

## 1. Ringkasan

Siswa saat ini harus membuka aplikasi dan mengecek **Daftar Ijin** secara manual
untuk tahu apakah pengajuan izinnya sudah diproses. Fitur "pesan harian" juga sudah
dihapus, sehingga sekolah tidak punya saluran untuk menyampaikan pengumuman lewat aplikasi.

Issue ini menambahkan **push notification** (Firebase Cloud Messaging) untuk dua kebutuhan:

1. **Status izin**: siswa menerima notifikasi saat pengajuan izin (`POST /ijin`)
   **disetujui** atau **ditolak** oleh guru/admin.
2. **Pengumuman sekolah**: admin mengirim pengumuman ke semua siswa.

**Lingkup issue ini: aplikasi Flutter saja.** Pekerjaan backend (Laravel, repo `sianida`)
dikerjakan terpisah. Kontraknya ada di **Lampiran A**. Sisi Flutter bisa dikerjakan dan
dites lebih dulu memakai Firebase Console, sebelum backend selesai.

Kondisi awal repo saat issue ini ditulis:
- Belum ada Firebase sama sekali. `google-services.json` dan `GoogleService-Info.plist` belum ada.
- Package ID **berbeda** di dua platform:
  - Android: `com.sahasika.skanida_student`
  - iOS: `com.sahasika.skanidaStudent`
- iOS minimum 15.0. Dependensi iOS memakai **CocoaPods**, karena Swift Package Manager
  dimatikan di `pubspec.yaml` (tidak perlu diubah).
- Izin aplikasi saat ini hanya kamera dan lokasi, diminta per-fitur lewat `PermissionGuard`.

---

## 2. Keputusan Desain

| Hal | Keputusan |
|---|---|
| Paket | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` |
| Konfigurasi Firebase | `flutterfire configure` → menghasilkan `lib/firebase_options.dart` + file config tiap platform |
| Channel Android | `status_izin` ("Status Izin") dan `pengumuman` ("Pengumuman Sekolah"), keduanya importance high |
| Target pengiriman | Status izin → ke **token** milik siswa. Pengumuman → ke **topic `siswa`** |
| Payload `data` | `{type: "ijin", id: "<uuid>"}` atau `{type: "pengumuman", judul: "...", isi: "..."}` |
| Saat notifikasi di-tap | `ijin` → buka `DaftarIjinPage`. `pengumuman` → tampilkan dialog berisi judul & isi |
| Notifikasi saat app terbuka (foreground) | Android: ditampilkan manual via `flutter_local_notifications`. iOS: oleh sistem via `setForegroundNotificationPresentationOptions` (**jangan** tampilkan manual juga, nanti dobel) |
| Kapan izin notifikasi diminta | **Bukan di splash/awal.** (1) Satu kali setelah siswa berhasil mengajukan izin, (2) lewat banner "Aktifkan notifikasi" di dashboard yang bisa ditutup |
| Privasi | Judul/isi notifikasi **tidak boleh** memuat data sensitif (alasan izin, alasan penolakan, NISN). Detail dibaca di aplikasi setelah tap |
| Logout | Token FCM dihapus dari server & topic di-unsubscribe, agar HP yang dipakai bergantian tidak menerima notifikasi milik siswa lain |

Prinsip dari CLAUDE.md yang **wajib** tetap dijaga:
- Tidak ada inisialisasi berat di startup. Di `main()` hanya `Firebase.initializeApp()`
  dan pendaftaran background handler. Sisanya berjalan setelah frame pertama atau setelah login.
- Draft presensi (`ResumePresensiPage`) **tetap prioritas** di atas navigasi dari notifikasi.
- Jangan tambahkan ATT / `NSUserTrackingUsageDescription`. Push tidak membutuhkannya.

---

## 3. Acceptance Criteria

- [ ] Notifikasi status izin & pengumuman muncul di Android dan iOS, dalam 3 kondisi:
      app terbuka (foreground), app di background, dan app ditutup penuh (terminated).
- [ ] Tap notifikasi `ijin` membuka **Daftar Ijin**. Tap notifikasi `pengumuman` menampilkan dialog pengumuman.
      Ini berlaku juga ketika app sebelumnya mati.
- [ ] Jika app dibuka dari notifikasi **dan** ada draft presensi, yang terbuka lebih dulu
      tetap `ResumePresensiPage`. Notifikasi diproses setelah siswa sampai di dashboard.
- [ ] Token terkirim ke `POST /fcm-token` setelah login dan saat app dibuka dalam keadaan sudah login.
- [ ] Logout memanggil `DELETE /fcm-token`, unsubscribe topic `siswa`, dan menghapus token lokal.
      Tombol logout tetap terasa instan (tidak menunggu jaringan).
- [ ] Izin notifikasi tidak diminta saat startup. Menolak izin tidak mengganggu fitur lain.
- [ ] Jika backend belum punya endpoint `/fcm-token` (404) atau sedang offline, aplikasi tetap normal (gagal diam-diam).
- [ ] `flutter analyze` tidak menambah error/warning baru. `flutter build apk` dan `flutter build ios --no-codesign` berhasil.

---

## 4. Rencana Implementasi (Urut, Ikuti Sesuai Nomor)

### Task 0 — Persiapan Firebase & Apple (dikerjakan pemilik proyek)

1. Buat project di [Firebase Console](https://console.firebase.google.com).
2. Install tools:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   ```
3. Di root repo jalankan:
   ```bash
   flutterfire configure \
     --project=<id-project-firebase> \
     --platforms=android,ios \
     --android-package-name=com.sahasika.skanida_student \
     --ios-bundle-id=com.sahasika.skanidaStudent
   ```
   Hasilnya: `lib/firebase_options.dart`, `android/app/google-services.json`,
   `ios/Runner/GoogleService-Info.plist`. Ketiga file ini **boleh di-commit**
   (bukan rahasia), tetapi di Google Cloud Console batasi API key-nya per package/bundle ID.
4. Apple Developer → Keys → buat **APNs Auth Key (.p8)**. Upload ke Firebase Console →
   Project Settings → Cloud Messaging → Apple app configuration (isi Key ID & Team ID).
5. Firebase Console → Project Settings → Service accounts → **Generate new private key**.
   File JSON ini **RAHASIA**: serahkan ke pengembang backend, **jangan** taruh di repo Flutter.

### Task 1 — Dependensi & konfigurasi Android

1. Tambah paket (biarkan `pub` memilih versi terbaru yang kompatibel):
   ```bash
   flutter pub add firebase_core firebase_messaging 'flutter_local_notifications:^22.0.0'
   ```
   > `flutter_local_notifications` **dikunci di v22**: v23 mewajibkan AGP 9.1.1, sedangkan proyek ini
   > masih AGP 8.11.1. Naikkan ke v23 hanya bersamaan dengan migrasi AGP 9.
   >
   > `firebase_messaging` 17 menandai `getToken`/`onTokenRefresh`/`deleteToken` sebagai deprecated
   > (diganti `register()`/`onRegistered` yang menghasilkan *Firebase Installation ID*, bukan FCM token).
   > Kita tetap memakai API token karena backend mengirim ke target `token` (Lampiran A).
2. Plugin Google Services. Biasanya sudah ditambahkan `flutterfire configure`; cek dan tambahkan bila belum:
   - `android/settings.gradle.kts`, di blok `plugins { }`:
     ```kotlin
     id("com.google.gms.google-services") version "4.4.2" apply false
     ```
   - `android/app/build.gradle.kts`, di blok `plugins { }`:
     ```kotlin
     id("com.google.gms.google-services")
     ```
3. **Core library desugaring** (wajib untuk `flutter_local_notifications`, tanpa ini build gagal).
   Ubah di `android/app/build.gradle.kts`:
   ```kotlin
   compileOptions {
       isCoreLibraryDesugaringEnabled = true
       sourceCompatibility = JavaVersion.VERSION_17
       targetCompatibility = JavaVersion.VERSION_17
   }
   ```
   Lalu tambahkan di akhir file:
   ```kotlin
   dependencies {
       coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
   }
   ```
4. `android/app/src/main/AndroidManifest.xml`:
   - Di samping `<uses-permission>` yang sudah ada:
     ```xml
     <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
     ```
   - Di dalam `<application>`, di dekat meta-data Google Mobile Ads:
     ```xml
     <meta-data
         android:name="com.google.firebase.messaging.default_notification_channel_id"
         android:value="pengumuman" />
     <meta-data
         android:name="com.google.firebase.messaging.default_notification_icon"
         android:resource="@drawable/ic_notification" />
     ```
5. Ikon notifikasi `android/app/src/main/res/drawable/ic_notification.xml`:
   **putih polos di atas latar transparan** (vector drawable). Logo berwarna akan tampil
   sebagai kotak putih di status bar. Cara termudah: Android Studio → klik kanan `res` →
   New → Vector Asset → pilih ikon (misalnya "notifications" atau siluet logo) → warna putih → nama `ic_notification`.

### Task 2 — Konfigurasi iOS

1. Buka `ios/Runner.xcworkspace` di Xcode → target **Runner** → tab **Signing & Capabilities**:
   - **+ Capability → Push Notifications**. Xcode akan membuat `ios/Runner/Runner.entitlements`
     berisi `aps-environment`.
   - **+ Capability → Background Modes** → centang **Remote notifications**. Info.plist akan
     mendapat `UIBackgroundModes` → `remote-notification`.
2. `ios/Podfile`: di `GCC_PREPROCESSOR_DEFINITIONS`, tambahkan `'PERMISSION_NOTIFICATIONS=1',`
   setelah `'PERMISSION_LOCATION=1',`. Tanpa ini, `Permission.notification` dari
   `permission_handler` di iOS selalu bernilai denied.
3. Jalankan:
   ```bash
   cd ios && pod install && cd ..
   ```
4. `AppDelegate.swift` **tidak perlu diubah**. `firebase_messaging` memakai method swizzling,
   dan kita tidak menampilkan local notification di iOS.

### Task 3 — Buat `lib/push_notification_service.dart` (file baru)

Semua logika push dikumpulkan di file ini. Kerangka di bawah adalah panduan.
Signature `flutter_local_notifications` (misalnya `initialize`, `show`) bisa sedikit
berbeda antar versi mayor, jadi **cocokkan dengan README versi yang ter-install**.

```dart
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

/// Wajib top-level + entry-point. Dipanggil saat pesan datang ketika app di
/// background/terminated. Pesan bertipe "notification" sudah ditampilkan
/// otomatis oleh sistem, jadi di sini cukup inisialisasi Firebase.
/// JANGAN memakai context / SessionManager di sini.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  static const String topicSiswa = 'siswa';
  static const String _savedTokenKey = 'fcm_token';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Data notifikasi yang di-tap tapi belum bisa diproses (app baru dibuka,
  /// masih di splash / login / ResumePresensiPage).
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

  /// Dipanggil sekali dari SplashScreen (BUKAN dari main()).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            handleTap(Map<String, dynamic>.from(jsonDecode(payload)));
          }
        },
      );

      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      for (final channel in _channels) {
        await android?.createNotificationChannel(channel);
      }

      // iOS: biarkan sistem menampilkan notifikasi walau app sedang terbuka.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
              alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((m) => handleTap(m.data));

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _pendingData = initial.data;
    } catch (e) {
      debugPrint('PushNotificationService.init gagal: $e');
    }
  }

  /// Android saja. Di iOS sistem sudah menampilkan (lihat init()).
  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    final notification = message.notification;
    if (notification == null) return;
    final channelId = notification.android?.channelId ??
        (message.data['type'] == 'ijin' ? 'status_izin' : 'pengumuman');
    final channel = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _channels.last,
    );
    await _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Kirim token ke backend + subscribe topic. Aman dipanggil berkali-kali.
  /// Panggil TANPA await (fire-and-forget) agar tidak menunda UI.
  static Future<void> registerToken() async {
    if (!SessionManager.isLoggedIn || SessionManager.authToken == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;
      await _sendToken(token);
      await messaging.subscribeToTopic(topicSiswa);
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      // iOS bisa melempar error jika APNs token belum siap. Abaikan, nanti
      // dicoba lagi pada pembukaan app berikutnya.
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
      }
    } catch (e) {
      debugPrint('Kirim FCM token gagal: $e');
    }
  }

  /// Dipanggil dari SessionManager.logout(). authToken harus diambil SEBELUM
  /// sesi dihapus. Jangan di-await oleh tombol logout.
  static Future<void> unregister({required String? authToken}) async {
    try {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_savedTokenKey);
      await prefs.remove(_savedTokenKey);

      if (token != null && authToken != null) {
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
      }
      await FirebaseMessaging.instance.unsubscribeFromTopic(topicSiswa);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('unregister FCM gagal: $e');
    }
  }

  /// Dipanggil dari MyHomePage.initState (lihat Task 6).
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
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.campaign, color: Colors.deepPurple.shade700),
                const SizedBox(width: 10),
                Expanded(child: Text(data['judul']?.toString() ?? 'Pengumuman')),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(data['isi']?.toString() ?? ''),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;
    }
  }
}
```

### Task 4 — Ubah `lib/main.dart`

1. Import:
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'package:firebase_messaging/firebase_messaging.dart';
   import 'firebase_options.dart';
   import 'push_notification_service.dart';
   ```
2. Tambahkan global navigator key di dekat `API_BASE_URL`:
   ```dart
   final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
   ```
3. Di `main()`, setelah `WidgetsFlutterBinding.ensureInitialized();` dan **sebelum** `runZonedGuarded`:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
   ```
   Hanya dua baris ini yang berjalan di startup. Jangan meminta izin atau mengambil token di sini.
4. Di `MyApp.build`, tambahkan `navigatorKey: navigatorKey,` pada `MaterialApp`.
5. `SessionManager.logout()`: ambil token **sebelum** dihapus, lalu panggil unregister tanpa `await`:
   ```dart
   static void logout() {
     final tokenForUnregister = authToken;
     PushNotificationService.unregister(authToken: tokenForUnregister);
     isLoggedIn = false;
     // ... sisanya tetap seperti sekarang
   }
   ```

### Task 5 — Registrasi token

1. `lib/splash_screen.dart`, di `_navigateToHome()`, tepat setelah `await SessionManager.loadSession();`:
   ```dart
   await PushNotificationService.init();
   if (SessionManager.isLoggedIn) {
     PushNotificationService.registerToken(); // tanpa await
   }
   ```
   `init()` cepat dan sudah berjalan setelah frame pertama (splash memakai `addPostFrameCallback`),
   jadi tidak melanggar prinsip "tanpa inisialisasi berat di startup".
2. `lib/login_page.dart`, setelah `SessionManager.login(...)` (sekitar baris 41) dan sebelum
   `pushReplacementNamed('/home')`:
   ```dart
   PushNotificationService.registerToken(); // tanpa await
   ```

### Task 6 — Navigasi saat notifikasi di-tap

- **App hidup (foreground/background):** sudah ditangani `onMessageOpenedApp` dan
  `onDidReceiveNotificationResponse` → `handleTap` → `navigatorKey`.
- **App mati (terminated):** `getInitialMessage()` di `init()` menyimpan `_pendingData`.
  Data ini dikonsumsi **di dashboard**, bukan di splash. Dengan begitu urutan ini otomatis terjaga:
  Splash → (Login | ResumePresensiPage) → Dashboard → halaman dari notifikasi.

Di `lib/main.dart`, `_MyHomePageState`, tambahkan:
```dart
@override
void initState() {
  super.initState();
  PushNotificationService.consumePending();
  _checkNotificationBanner(); // dari Task 7
}
```

### Task 7 — Izin notifikasi (per-konteks)

1. `lib/permission_types.dart`:
   ```dart
   enum RequiredPermission { camera, location, notification }
   ```
   Setelah ini, **semua `switch` atas `RequiredPermission` akan error kompilasi** sampai case
   `notification` ditambahkan. Itu memang disengaja untuk membantu menemukan tempat yang perlu diubah.
2. `lib/permission_guard.dart` → `hasPermission`:
   ```dart
   case RequiredPermission.notification:
     return _isAllowed(await Permission.notification.status);
   ```
   Di Android 12 ke bawah, `Permission.notification` otomatis granted.
3. `lib/permission_pre_alert_page.dart`: tiru pola kamera/lokasi yang sudah ada.
   - Field `_notificationStatus`, getter `_needsNotification`.
   - Tambahkan ke `_allPermissionsGranted`, `_loadPermissionStatuses`, dan `_requestAllPermissions`.
   - Method `_requestNotificationPermission()` (pola sama dengan `_requestCameraPermission`, nama di dialog settings: `'Notifikasi'`).
   - Tile baru: judul `'Notifikasi'`, ikon `Icons.notifications_active`,
     deskripsi `'Untuk memberi tahu status izin dan pengumuman sekolah.'`.
   - `_buildIntroText` case `notification`:
     `'Aktifkan notifikasi agar Anda tahu saat izin disetujui atau ditolak, serta menerima pengumuman sekolah.'`
   - Setelah izin notifikasi **granted**, panggil `PushNotificationService.registerToken();`.
     Di iOS, token kadang baru tersedia setelah izin diberikan.
4. **Pemicu #1, setelah submit izin sukses.** Di `lib/ijin_online_page.dart`, pada blok sukses (sekitar baris 304),
   setelah `await AdsHelper.showInterstitialAd();` dan **sebelum** `Navigator.of(context).pop()`:
   ```dart
   await _offerNotificationPermissionOnce();
   ```
   Method helper di state yang sama:
   ```dart
   Future<void> _offerNotificationPermissionOnce() async {
     const key = 'notif_prompt_after_ijin_shown';
     final prefs = await SharedPreferences.getInstance();
     if (prefs.getBool(key) ?? false) return;
     if (await PermissionGuard.hasPermission(RequiredPermission.notification)) return;
     await prefs.setBool(key, true);
     if (!mounted) return;
     await PermissionGuard.ensurePermission(context, RequiredPermission.notification);
   }
   ```
   Prompt ini hanya muncul **sekali seumur instalasi**, agar tidak mengganggu setiap kali mengajukan izin.
5. **Pemicu #2, banner di dashboard.** Di `_MyHomePageState`:
   - State `bool _showNotifBanner = false;`.
   - `_checkNotificationBanner()`: tampilkan banner bila izin belum diberikan **dan** prefs
     `notif_banner_dismissed` belum true. Cek `mounted` sebelum `setState`.
   - Banner diletakkan tepat di bawah header "Hello, ...". Isinya: ikon lonceng, teks
     *"Aktifkan notifikasi untuk menerima status izin & pengumuman sekolah."*, dan dua tombol:
     - **Aktifkan** → `PermissionGuard.ensurePermission(context, RequiredPermission.notification)`,
       lalu cek ulang dan sembunyikan banner jika sudah granted.
     - **Nanti** → simpan `notif_banner_dismissed = true` dan sembunyikan.
   - Gaya: `Card` dengan warna `Colors.deepPurple.shade50`, sudut 12, konsisten dengan tema ungu.

### Task 8 — Dokumen, versi, dan store

1. `PRIVACY_POLICY.md`: tambahkan bagian notifikasi. Isinya: aplikasi menyimpan **token perangkat
   (FCM)** di server sekolah untuk mengirim notifikasi, memakai layanan **Firebase Cloud Messaging
   (Google)**, token dihapus saat logout, dan izin notifikasi bersifat opsional.
2. `APP_DESCRIPTION.md`: tambahkan poin fitur notifikasi status izin & pengumuman.
3. `RELEASE_NOTES.md`: entri versi baru.
4. `CLAUDE.md`: tambahkan `push_notification_service.dart` ke bagian Arsitektur, `notification` ke
   bagian Izin, dan endpoint `/fcm-token` ke tabel endpoint.
5. `pubspec.yaml`: naikkan versi ke `1.4.0+18`.
6. Saat upload ke store:
   - **Play Console → Data safety**: tambahkan "Device or other IDs" (tujuan: App functionality, tidak dibagikan).
   - **App Store Connect → App Privacy**: tambahkan "Device ID" (App Functionality, tidak untuk tracking).

### Task 9 — Testing manual

Lihat **Bagian 5**.

---

## 5. Cara Verifikasi

Tes ini bisa dilakukan **tanpa backend** memakai Firebase Console → Messaging → *New campaign* →
*Send test message*. Ambil token dari log debug: tambahkan sementara
`debugPrint('FCM token: $token');` di `registerToken`, lalu hapus sebelum commit.

1. `flutter analyze`, `flutter build apk`, dan `flutter build ios --no-codesign` berhasil.
2. **Android 13+ (HP asli):** login → izin notifikasi **tidak** muncul otomatis → banner muncul di dashboard → tap **Aktifkan** → izin diberikan → banner hilang.
3. Kirim test message dengan *custom data* `type=ijin`, `id=123` di tiga kondisi:
   - App terbuka → notifikasi tampil (heads-up) → tap → Daftar Ijin terbuka.
   - App di background → tap → Daftar Ijin terbuka.
   - App di-swipe/mati → tap → splash → dashboard → Daftar Ijin terbuka.
4. Ulangi dengan `type=pengumuman`, `judul=Tes`, `isi=Halo` → dialog pengumuman muncul.
5. Untuk tes topic, kirim ke topic `siswa`. Ini harus diterima tanpa perlu token individu.
6. **iOS (HP asli, simulator tidak cukup):** ulangi langkah 2–5. Pastikan notifikasi saat foreground **tidak dobel**.
7. **Draft presensi:** mulai presensi → di kamera, kill app lewat Android "Don't keep activities"
   atau dengan menunggu → kirim notif → tap → harus masuk `ResumePresensiPage` dulu. Setelah selesai, notifikasi diproses di dashboard.
8. **Logout:** logout → login akun lain → kirim test ke token lama → **tidak** diterima (token sudah di-`deleteToken`).
9. Tolak izin notifikasi → fitur presensi, izin, dan lainnya tetap berjalan normal.
10. Ajukan izin baru → prompt izin notifikasi muncul **sekali**. Pengajuan berikutnya tidak muncul lagi.

Setelah backend siap (Lampiran A): setujui atau tolak izin dari web admin → notifikasi sampai di HP siswa.

---

## 6. Ringkasan File yang Berubah

| File | Perubahan |
|---|---|
| `pubspec.yaml` | 3 paket baru, versi `1.4.0+18` |
| `lib/firebase_options.dart` | **Baru** (hasil `flutterfire configure`) |
| `lib/push_notification_service.dart` | **Baru**: seluruh logika push |
| `lib/main.dart` | Inisialisasi Firebase, `navigatorKey`, logout → unregister, `initState` + banner di dashboard |
| `lib/splash_screen.dart` | `init()` + `registerToken()` |
| `lib/login_page.dart` | `registerToken()` setelah login |
| `lib/permission_types.dart`, `lib/permission_guard.dart`, `lib/permission_pre_alert_page.dart` | Izin `notification` |
| `lib/ijin_online_page.dart` | Tawarkan izin notifikasi sekali setelah submit sukses |
| `android/settings.gradle.kts`, `android/app/build.gradle.kts` | Plugin google-services, desugaring |
| `android/app/google-services.json` | **Baru** |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS`, meta-data channel & ikon |
| `android/app/src/main/res/drawable/ic_notification.xml` | **Baru**: ikon monokrom |
| `ios/Runner/GoogleService-Info.plist`, `ios/Runner/Runner.entitlements` | **Baru** |
| `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj` | Background Modes, Push capability (via Xcode) |
| `ios/Podfile` (+ `Podfile.lock`) | `PERMISSION_NOTIFICATIONS=1`, pod Firebase |
| `PRIVACY_POLICY.md`, `APP_DESCRIPTION.md`, `RELEASE_NOTES.md`, `CLAUDE.md` | Dokumentasi |

---

## 7. Catatan / Risiko

- **iOS butuh HP asli + akun Apple Developer berbayar + APNs key** yang sudah di-upload ke Firebase.
  Tanpa itu, `getToken()` di iOS gagal. Ini sudah ditangani oleh `try/catch`, jadi app tidak crash.
- **Lupa desugaring** → build Android gagal dengan error tentang `coreLibraryDesugaring`.
- **Ikon notifikasi berwarna** → tampil sebagai kotak putih di status bar Android.
- **Notifikasi dobel di iOS** jika local notification juga ditampilkan saat foreground.
  `_showForegroundNotification` harus tetap `return` untuk non-Android.
- **Background handler** harus top-level + `@pragma('vm:entry-point')`. Jika ditaruh di dalam class
  atau anotasinya hilang, notifikasi data-only di release build tidak diproses.
- **HP dengan penghemat baterai agresif** (Xiaomi, Oppo, Vivo) bisa menunda notifikasi saat app
  di-kill. Ini perilaku OS, bukan bug aplikasi.
- **Logout tanpa koneksi** → `DELETE /fcm-token` gagal, tetapi `deleteToken()` lokal tetap membuat
  token lama tidak valid. Backend akan menerima `UNREGISTERED` saat mengirim dan harus menghapus token itu (Lampiran A).
- Jangan menaruh **service account JSON** di repo ini (repo publik).

---

## Lampiran A — Kontrak API untuk Backend (`sianida`, Laravel 9 + Sanctum)

Dikerjakan terpisah dari issue ini. Bagian ini adalah kontrak yang diharapkan aplikasi.

### A.1 Endpoint (di grup `auth:sanctum`, `routes/api.php`)

**`POST /fcm-token`**: simpan atau perbarui token perangkat.
```json
// Request
{ "token": "<fcm token>", "platform": "android" }   // platform: "android" | "ios"
// Response 200
{ "success": true, "message": "Token tersimpan" }
// Response 422 bila token kosong
```
- Lakukan **upsert berdasarkan `token`**. Jika token yang sama sebelumnya milik user lain,
  pindahkan ke user sekarang (HP dipakai bergantian).
- Simpan `user_id` (`$request->user()->id`) dan `id_siswa`. Petakan `id_siswa` lewat
  `users.identitas = siswa.nik`, seperti di `AuthController::login`.

**`DELETE /fcm-token`**: hapus token saat logout.
```json
// Request
{ "token": "<fcm token>" }
// Response 200
{ "success": true }
```

### A.2 Tabel saran

Nama: **`fcm_token`**. Jangan pakai `device`, karena tabel itu sudah dipakai untuk gateway WhatsApp.

| Kolom | Tipe |
|---|---|
| `id` | `string(36)` primary (UUID, trait `UsesUuid`) |
| `user_id` | `string(36)`, index |
| `id_siswa` | `string(36)`, nullable, index |
| `token` | `string(255)`, **unique** |
| `platform` | `string(10)` |
| `created_at`, `updated_at` | timestamps |

### A.3 Pengiriman

- Pakai **FCM HTTP v1 API** (`https://fcm.googleapis.com/v1/projects/<project-id>/messages:send`)
  dengan service account JSON dari Task 0 langkah 5. Paket opsional: `kreait/laravel-firebase`,
  atau `google/auth` + Guzzle.
- **Status izin**: kirim di `app/Modules/Ijin/Controllers/IjinController.php`, di method
  `approve()` dan `reject()` setelah `save()`, ke semua token milik `id_siswa` izin tersebut.
- Jika FCM membalas `UNREGISTERED` / `INVALID_ARGUMENT` untuk sebuah token → hapus token itu dari tabel.
- Queue saat ini `sync`, jadi pengiriman berjalan di dalam request web. Untuk izin (beberapa token)
  ini masih aman. Untuk pengumuman, karena memakai topic, cukup 1 request.

### A.4 Format payload

**Izin disetujui** (ke token):
```json
{
  "message": {
    "token": "<fcm token>",
    "notification": {
      "title": "Izin disetujui",
      "body": "Pengajuan izinmu untuk 17 November 2026 telah disetujui."
    },
    "data": { "type": "ijin", "id": "<uuid ijin>" },
    "android": { "priority": "high", "notification": { "channel_id": "status_izin" } },
    "apns": { "payload": { "aps": { "sound": "default" } } }
  }
}
```

**Izin ditolak**: sama seperti di atas, dengan
`"title": "Izin ditolak"` dan `"body": "Pengajuan izinmu ditolak. Buka aplikasi untuk melihat alasannya."`.
**Jangan** cantumkan isi `alasan_tolak` di notifikasi.

**Pengumuman** (ke topic):
```json
{
  "message": {
    "topic": "siswa",
    "notification": { "title": "Pengumuman", "body": "<ringkasan, maks ~100 karakter>" },
    "data": { "type": "pengumuman", "judul": "<judul>", "isi": "<isi lengkap>" },
    "android": { "priority": "high", "notification": { "channel_id": "pengumuman" } },
    "apns": { "payload": { "aps": { "sound": "default" } } }
  }
}
```
- Semua nilai di `data` **harus string**.
- Total payload maksimal **4 KB**. Jika isi pengumuman lebih panjang, kirim versi ringkas.
