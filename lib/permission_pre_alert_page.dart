import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String permissionPreAlertSeenKey = 'permission_pre_alert_seen';

class PermissionPreAlertPage extends StatefulWidget {
  const PermissionPreAlertPage({super.key, required this.nextPage});

  final Widget nextPage;

  @override
  State<PermissionPreAlertPage> createState() => _PermissionPreAlertPageState();
}

class _PermissionPreAlertPageState extends State<PermissionPreAlertPage> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _fileStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;

  bool _isRequestingAll = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatuses();
  }

  bool _isAllowed(PermissionStatus status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  Future<void> _loadPermissionStatuses() async {
    final camera = await Permission.camera.status;
    final file = await _currentFilePermissionStatus();
    final location = await Permission.locationWhenInUse.status;

    if (!mounted) {
      return;
    }

    setState(() {
      _cameraStatus = camera;
      _fileStatus = file;
      _locationStatus = location;
    });
  }

  Future<PermissionStatus> _currentFilePermissionStatus() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.status;
      if (_isAllowed(storage)) {
        return storage;
      }
      final photos = await Permission.photos.status;
      return _isAllowed(photos) ? photos : storage;
    }

    return Permission.photos.status;
  }

  Future<void> _requestCameraPermission() async {
    if (_cameraStatus == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
      await _loadPermissionStatuses();
      return;
    }

    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }

    setState(() {
      _cameraStatus = status;
    });
  }

  Future<void> _requestFilePermission() async {
    if (_fileStatus == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
      await _loadPermissionStatuses();
      return;
    }

    PermissionStatus status;

    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      if (_isAllowed(storageStatus)) {
        status = storageStatus;
      } else {
        final photosStatus = await Permission.photos.request();
        status = _isAllowed(photosStatus) ? photosStatus : storageStatus;
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _fileStatus = status;
    });
  }

  Future<void> _requestLocationPermission() async {
    if (_locationStatus == PermissionStatus.permanentlyDenied) {
      await openAppSettings();
      await _loadPermissionStatuses();
      return;
    }

    final status = await Permission.locationWhenInUse.request();
    if (!mounted) {
      return;
    }

    setState(() {
      _locationStatus = status;
    });
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isRequestingAll = true;
    });

    await _requestCameraPermission();
    await _requestFilePermission();
    await _requestLocationPermission();

    if (_cameraStatus == PermissionStatus.permanentlyDenied ||
        _fileStatus == PermissionStatus.permanentlyDenied ||
        _locationStatus == PermissionStatus.permanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sebagian izin ditolak permanen. Aktifkan manual di Settings.',
            ),
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRequestingAll = false;
    });
  }

  Future<void> _continueToApp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(permissionPreAlertSeenKey, true);

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextPage));
  }

  String _statusLabel(PermissionStatus status) {
    if (_isAllowed(status)) {
      return 'Diizinkan';
    }
    if (status == PermissionStatus.permanentlyDenied) {
      return 'Ditolak permanen';
    }
    if (status == PermissionStatus.restricted) {
      return 'Dibatasi sistem';
    }
    return 'Belum diizinkan';
  }

  Color _statusColor(PermissionStatus status) {
    return _isAllowed(status) ? Colors.green.shade700 : Colors.orange.shade800;
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionStatus status,
    required VoidCallback onRequest,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(onPressed: onRequest, child: const Text('Izinkan')),
              ],
            ),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              _statusLabel(status),
              style: TextStyle(
                color: _statusColor(status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Izin Aplikasi'),
        backgroundColor: Colors.deepPurple.shade900,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sebelum mulai, aktifkan izin penting berikut agar fitur aplikasi dapat berjalan dengan baik.',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
              ),
              const SizedBox(height: 14),
              _buildPermissionTile(
                icon: Icons.camera_alt,
                title: 'Kamera',
                description:
                    'Digunakan untuk selfie presensi dan unggah bukti.',
                status: _cameraStatus,
                onRequest: _requestCameraPermission,
              ),
              _buildPermissionTile(
                icon: Icons.folder,
                title: 'File / Media',
                description: 'Digunakan untuk memilih berkas pendukung izin.',
                status: _fileStatus,
                onRequest: _requestFilePermission,
              ),
              _buildPermissionTile(
                icon: Icons.location_on,
                title: 'Lokasi',
                description: 'Digunakan untuk validasi posisi saat presensi.',
                status: _locationStatus,
                onRequest: _requestLocationPermission,
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isRequestingAll ? null : _requestAllPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    _isRequestingAll ? 'Meminta izin...' : 'Izinkan Semua',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _continueToApp,
                  child: const Text('Lanjut ke Aplikasi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
