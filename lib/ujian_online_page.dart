import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'exam_lock.dart';
import 'main.dart';

const String ujianUrl = 'https://ujian.smkn2semarang.sch.id';
const String _ujianHost = 'ujian.smkn2semarang.sch.id';

enum _Phase { preparing, exam }

/// Ujian Online: WebView situs ujian dengan aplikasi disematkan (Android).
///
/// Bila siswa keluar dari aplikasi / melepas pin, ujian ditutup dan seluruh
/// cookie, cache & local storage WebView dihapus. Data yang sama juga dihapus
/// setiap kali halaman dibuka & saat keluar normal.
///
/// Syarat mode ujian: aplikasi harus tersemat dan tidak dalam split-screen /
/// jendela mengambang. Bila tidak terpenuhi, aplikasi ditutup paksa.
///
/// Login otomatis (SSO): minta kode sekali pakai ke sianida
/// (`POST /ujian/sso-code`), lalu buka `/sso?code=...` di situs ujian.
/// Bila gagal, situs ujian dibuka biasa (login manual).
class UjianOnlinePage extends StatefulWidget {
  const UjianOnlinePage({super.key});

  @override
  State<UjianOnlinePage> createState() => _UjianOnlinePageState();
}

class _UjianOnlinePageState extends State<UjianOnlinePage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  _Phase _phase = _Phase.preparing;
  int _progress = 0;
  String? _loadError;

  /// Deteksi pelanggaran hanya aktif setelah aplikasi benar-benar disematkan.
  bool _armed = false;
  bool _closing = false;
  Timer? _pinWatcher;

  /// Bar status (jam, koneksi, baterai) karena status bar sistem disembunyikan.
  Timer? _statusTimer;
  DateTime _now = DateTime.now();
  DeviceStatus? _status;
  int _statusTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ExamLock.onUserLeave = _onUserLeaveHint;
    ExamLock.onMultiWindowChanged = _onMultiWindowChanged;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            final allowed =
                uri.scheme == 'https' &&
                (uri.host == _ujianHost || uri.host.endsWith('.$_ujianHost'));
            if (!allowed && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tautan di luar situs ujian diblokir'),
                ),
              );
            }
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loadError = null);
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame != false && mounted) {
              setState(() => _loadError = err.description);
            }
          },
        ),
      );
    _refreshDeviceStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (++_statusTick % 5 == 0) _refreshDeviceStatus();
    });
    _start();
  }

  Future<void> _refreshDeviceStatus() async {
    final s = await ExamLock.deviceStatus();
    if (mounted && s != null) setState(() => _status = s);
  }

  Future<void> _resetWebData() async {
    try {
      await WebViewCookieManager().clearCookies();
      await _controller.clearCache();
      await _controller.clearLocalStorage();
    } catch (e) {
      debugPrint('Gagal menghapus data ujian: $e');
    }
  }

  Future<void> _start() async {
    if (await ExamLock.isMultiWindow()) {
      return _forceCloseApp(_pesanMultiWindow);
    }
    await _resetWebData();
    await ExamLock.setSecure(true);
    await ExamLock.setHideOverlays(true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    var state = await ExamLock.state();
    if (state == ExamLock.stateNone) {
      await ExamLock.start();
      // Tunggu konfirmasi "Sematkan aplikasi" (maks ±15 detik).
      for (var i = 0; i < 30 && state == ExamLock.stateNone; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || _closing) return;
        state = await ExamLock.state();
      }
    }
    if (!mounted || _closing) return;

    if (state == ExamLock.stateNone) {
      return _forceCloseApp(
        'Aplikasi tidak disematkan, sehingga ujian tidak bisa dibuka.\n\n'
        'Saat membuka menu Ujian Online, pilih izinkan/OK pada pertanyaan '
        '"Sematkan aplikasi". Jika tidak muncul, aktifkan dulu di '
        'Pengaturan › Keamanan › "Sematkan aplikasi" (Screen/App pinning).',
      );
    }
    if (await ExamLock.isMultiWindow()) {
      return _forceCloseApp(_pesanMultiWindow);
    }

    setState(() => _phase = _Phase.exam);
    _armed = true;
    _pinWatcher?.cancel();
    _pinWatcher = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_armed) return;
      if (await ExamLock.isMultiWindow()) {
        _forceCloseApp(_pesanMultiWindow);
      } else if (await ExamLock.state() == ExamLock.stateNone) {
        _violation();
      }
    });
    final code = await _requestSsoCode();
    if (!mounted || _closing) return;
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login otomatis gagal, silakan login manual'),
        ),
      );
    }
    await _controller.loadRequest(
      Uri.parse(
        code == null
            ? ujianUrl
            : '$ujianUrl/sso?code=${Uri.encodeQueryComponent(code)}',
      ),
    );
  }

  /// Kode SSO sekali pakai dari sianida, atau `null` bila gagal.
  Future<String?> _requestSsoCode() async {
    try {
      final res = await http
          .post(
            Uri.parse('$API_BASE_URL/ujian/sso-code'),
            headers: {
              'Authorization': 'Bearer ${SessionManager.authToken}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final code = (jsonDecode(res.body) as Map<String, dynamic>)['code'];
        if (code is String && code.isNotEmpty) return code;
      }
      debugPrint('SSO ujian gagal: HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('SSO ujian gagal: $e');
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` diabaikan: muncul juga saat dialog sistem / panel notifikasi.
    if (!_armed || state != AppLifecycleState.paused) return;
    ExamLock.isInteractive().then((screenOn) {
      // Layar mati / terkunci bukan pelanggaran.
      if (screenOn) _violation();
    });
  }

  static const String _pesanMultiWindow =
      'Ujian tidak boleh dibuka dalam layar terpisah (split-screen) atau '
      'jendela mengambang.\n\nBuka aplikasi dalam layar penuh, lalu buka '
      'kembali menu Ujian Online.';

  void _onMultiWindowChanged(bool multiWindow) {
    if (multiWindow) _forceCloseApp(_pesanMultiWindow);
  }

  /// Syarat mode ujian tidak terpenuhi: hapus sesi lalu tutup paksa aplikasi.
  Future<void> _forceCloseApp(String pesan) async {
    if (_closing) return;
    _armed = false;
    _closing = true;
    _pinWatcher?.cancel();
    _statusTimer?.cancel();
    await _resetWebData();
    await ExamLock.setHideOverlays(false);
    if (!mounted) return ExamLock.forceClose();

    // Tutup otomatis bila tombol tidak ditekan.
    final autoClose = Timer(const Duration(seconds: 5), ExamLock.forceClose);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: Icon(Icons.gpp_bad, color: Colors.red.shade700, size: 40),
          title: const Text('Aplikasi akan ditutup'),
          content: Text(pesan),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: ExamLock.forceClose,
              child: const Text('Tutup aplikasi'),
            ),
          ],
        ),
      ),
    );
    autoClose.cancel();
  }

  void _onUserLeaveHint() {
    if (!_armed) return;
    // Pastikan benar-benar meninggalkan aplikasi (saat disematkan, Home
    // diblokir sistem dan aplikasi tetap aktif).
    Future.delayed(const Duration(milliseconds: 500), () {
      final s = WidgetsBinding.instance.lifecycleState;
      if (_armed && s != AppLifecycleState.resumed) _violation();
    });
  }

  Future<void> _teardown() async {
    _armed = false;
    _closing = true;
    _pinWatcher?.cancel();
    _statusTimer?.cancel();
    await _resetWebData();
    await ExamLock.stop();
    await ExamLock.setSecure(false);
    await ExamLock.setHideOverlays(false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _violation() async {
    if (_closing) return;
    await _teardown();
    if (!mounted) return;
    Navigator.of(context).pop();
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(Icons.gpp_bad, color: Colors.red.shade700, size: 40),
        title: const Text('Ujian ditutup'),
        content: const Text(
          'Ujian ditutup karena Anda keluar dari aplikasi atau melepas '
          'sematan aplikasi.\n\n'
          'Buka kembali menu Ujian Online untuk melanjutkan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari ujian?'),
        content: const Text(
          'Pastikan jawaban sudah dikirim sebelum keluar. '
          'Anda bisa membuka menu Ujian Online lagi untuk melanjutkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _teardown();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (ExamLock.onUserLeave == _onUserLeaveHint) ExamLock.onUserLeave = null;
    if (ExamLock.onMultiWindowChanged == _onMultiWindowChanged) {
      ExamLock.onMultiWindowChanged = null;
    }
    _pinWatcher?.cancel();
    _statusTimer?.cancel();
    if (!_closing) {
      // Jaring pengaman bila halaman ditutup tanpa lewat _teardown.
      _armed = false;
      WebViewCookieManager().clearCookies();
      ExamLock.stop();
      ExamLock.setSecure(false);
      ExamLock.setHideOverlays(false);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Widget _statusItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    String two(int n) => n.toString().padLeft(2, '0');
    final jam = '${two(_now.hour)}:${two(_now.minute)}:${two(_now.second)}';
    final s = _status;

    // Koneksi
    final (IconData netIcon, String netLabel) = switch (s?.network) {
      'wifi' => (Icons.wifi, 'WiFi'),
      'cellular' => (Icons.signal_cellular_alt, 'Data seluler'),
      'ethernet' => (Icons.settings_ethernet, 'Ethernet'),
      'none' => (Icons.signal_wifi_off, 'Tidak ada koneksi'),
      null => (Icons.language, '-'),
      _ => (Icons.language, 'Terhubung'),
    };
    final offline = s?.network == 'none';
    final noInternet = s != null && !offline && !s.validated;
    final netColor = offline
        ? Colors.red.shade200
        : noInternet
        ? Colors.amber.shade300
        : Colors.white;

    // Baterai
    final level = s?.battery;
    final IconData batIcon;
    if (s?.charging == true) {
      batIcon = Icons.battery_charging_full;
    } else if (level == null) {
      batIcon = Icons.battery_unknown;
    } else if (level <= 10) {
      batIcon = Icons.battery_alert;
    } else if (level <= 25) {
      batIcon = Icons.battery_2_bar;
    } else if (level <= 50) {
      batIcon = Icons.battery_4_bar;
    } else if (level <= 85) {
      batIcon = Icons.battery_6_bar;
    } else {
      batIcon = Icons.battery_full;
    }
    final batColor = level == null || s?.charging == true
        ? Colors.white
        : level <= 10
        ? Colors.red.shade200
        : level <= 20
        ? Colors.amber.shade300
        : Colors.white;

    return Container(
      height: 28,
      color: Colors.deepPurple.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statusItem(Icons.access_time, jam, Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: _statusItem(
                netIcon,
                noInternet ? '$netLabel (tanpa internet)' : netLabel,
                netColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _statusItem(batIcon, level == null ? '-' : '$level%', batColor),
        ],
      ),
    );
  }

  Widget _buildExam() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              const Text(
                'Halaman ujian gagal dimuat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Periksa koneksi internet lalu muat ulang.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _controller.reload(),
                icon: const Icon(Icons.refresh),
                label: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_progress < 100)
          LinearProgressIndicator(
            value: _progress / 100,
            minHeight: 3,
            color: Colors.purple,
            backgroundColor: Colors.transparent,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepPurple.shade900,
          automaticallyImplyLeading: false,
          title: const Text(
            'Ujian Online',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            if (_phase == _Phase.exam)
              IconButton(
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  setState(() => _loadError = null);
                  _controller.reload();
                },
              ),
            IconButton(
              tooltip: 'Keluar ujian',
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _confirmExit,
            ),
          ],
        ),
        // Bar status di bawah; SafeArea agar tidak tertutup navigasi gesture.
        bottomNavigationBar: ColoredBox(
          color: Colors.deepPurple.shade800,
          child: SafeArea(top: false, child: _buildStatusBar()),
        ),
        body: switch (_phase) {
          _Phase.preparing => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Menyiapkan mode ujian...'),
              ],
            ),
          ),
          _Phase.exam => _buildExam(),
        },
      ),
    );
  }
}
