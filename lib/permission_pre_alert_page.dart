import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'permission_types.dart';

const String permissionPreAlertSeenKey = 'permission_pre_alert_seen';

class PermissionPreAlertPage extends StatefulWidget {
  const PermissionPreAlertPage({
    super.key,
    this.nextPage,
    this.forceGrantAll = false,
    this.requiredPermissions,
  });

  final Widget? nextPage;
  final bool forceGrantAll;
  final Set<RequiredPermission>? requiredPermissions;

  @override
  State<PermissionPreAlertPage> createState() => _PermissionPreAlertPageState();
}

class _PermissionPreAlertPageState extends State<PermissionPreAlertPage> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _fileStatus = PermissionStatus.denied;
  PermissionStatus _locationStatus = PermissionStatus.denied;

  bool _isRequestingAll = false;

  Set<RequiredPermission> get _requiredPermissions {
    return widget.requiredPermissions ??
        {
          RequiredPermission.camera,
          RequiredPermission.file,
          RequiredPermission.location,
        };
  }

  bool get _needsCamera =>
      _requiredPermissions.contains(RequiredPermission.camera);
  bool get _needsFile => _requiredPermissions.contains(RequiredPermission.file);
  bool get _needsLocation =>
      _requiredPermissions.contains(RequiredPermission.location);

  bool get _allPermissionsGranted {
    if (_requiredPermissions.isEmpty) {
      return true;
    }

    final cameraOk = !_needsCamera || _isAllowed(_cameraStatus);
    final fileOk = !_needsFile || _isAllowed(_fileStatus);
    final locationOk = !_needsLocation || _isAllowed(_locationStatus);

    return cameraOk && fileOk && locationOk;
  }

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
    final camera = _needsCamera
        ? await Permission.camera.status
        : _cameraStatus;
    final file = _needsFile
        ? await _currentFilePermissionStatus()
        : _fileStatus;
    final location = _needsLocation
        ? await Permission.locationWhenInUse.status
        : _locationStatus;

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
      await _showSettingsDialog('Kamera');
      return;
    }

    final status = await Permission.camera.request();
    if (!mounted) {
      return;
    }

    setState(() {
      _cameraStatus = status;
    });

    if (status == PermissionStatus.permanentlyDenied) {
      await _showSettingsDialog('Kamera');
    }
  }

  Future<void> _requestFilePermission() async {
    if (_fileStatus == PermissionStatus.permanentlyDenied) {
      await _showSettingsDialog('File/Media');
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

    if (status == PermissionStatus.permanentlyDenied) {
      await _showSettingsDialog('File/Media');
    }
  }

  Future<void> _requestLocationPermission() async {
    if (_locationStatus == PermissionStatus.permanentlyDenied) {
      await _showSettingsDialog('Lokasi');
      return;
    }

    final status = await Permission.locationWhenInUse.request();
    if (!mounted) {
      return;
    }

    setState(() {
      _locationStatus = status;
    });

    if (status == PermissionStatus.permanentlyDenied) {
      await _showSettingsDialog('Lokasi');
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isRequestingAll = true;
    });

    if (_needsCamera) {
      await _requestCameraPermission();
    }
    if (_needsFile) {
      await _requestFilePermission();
    }
    if (_needsLocation) {
      await _requestLocationPermission();
    }

    final hasPermanentDeny =
        (_needsCamera && _cameraStatus == PermissionStatus.permanentlyDenied) ||
        (_needsFile && _fileStatus == PermissionStatus.permanentlyDenied) ||
        (_needsLocation &&
            _locationStatus == PermissionStatus.permanentlyDenied);

    if (hasPermanentDeny) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sebagian izin ditolak permanen. Anda dapat mengaktifkannya di Settings.',
            ),
            action: SnackBarAction(
              label: 'Buka Settings',
              onPressed: () => openAppSettings(),
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

    await _continueToApp();
  }

  Future<void> _continueToApp() async {
    if (widget.forceGrantAll && !_allPermissionsGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin belum diberikan. Anda dapat melanjutkan tanpa izin, tetapi fitur terkait tidak bisa digunakan.',
            ),
          ),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(permissionPreAlertSeenKey, true);

    if (!mounted) {
      return;
    }

    if (widget.nextPage != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => widget.nextPage!));
      return;
    }

    Navigator.of(context).pop(_allPermissionsGranted);
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
    return 'Belum diberi izin';
  }

  Color _statusColor(PermissionStatus status) {
    return _isAllowed(status) ? Colors.green.shade700 : Colors.orange.shade800;
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required PermissionStatus status,
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
    const requestAllLabel = 'Lanjutkan';

    final introText = _buildIntroText();

    return PopScope(
      canPop: false,
      child: Scaffold(
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
                  introText,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 15),
                ),
                const SizedBox(height: 14),
                if (_needsCamera)
                  _buildPermissionTile(
                    icon: Icons.camera_alt,
                    title: 'Kamera',
                    description:
                        'Digunakan untuk selfie presensi dan unggah bukti.',
                    status: _cameraStatus,
                  ),
                if (_needsFile)
                  _buildPermissionTile(
                    icon: Icons.folder,
                    title: 'File / Media',
                    description:
                        'Digunakan untuk memilih berkas pendukung izin.',
                    status: _fileStatus,
                  ),
                if (_needsLocation)
                  _buildPermissionTile(
                    icon: Icons.location_on,
                    title: 'Lokasi',
                    description:
                        'Digunakan untuk validasi posisi saat presensi.',
                    status: _locationStatus,
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
                      _isRequestingAll ? 'Meminta izin...' : requestAllLabel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildIntroText() {
    if (_requiredPermissions.length == 1) {
      final permission = _requiredPermissions.first;
      switch (permission) {
        case RequiredPermission.camera:
          return 'Agar fitur selfie presensi dapat digunakan, aplikasi memerlukan izin kamera.';
        case RequiredPermission.file:
          return 'Agar fitur unggah berkas berjalan, aplikasi memerlukan izin akses file/media.';
        case RequiredPermission.location:
          return 'Agar validasi presensi berjalan, aplikasi memerlukan izin lokasi.';
      }
    }

    return 'Aplikasi akan meminta izin berikut saat fitur digunakan. Anda dapat melanjutkan tanpa mengizinkan.';
  }

  Future<void> _showSettingsDialog(String permissionName) async {
    if (!mounted) {
      return;
    }

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Izin $permissionName'),
        content: Text(
          'Izin $permissionName ditolak permanen. Anda dapat mengaktifkannya di Settings agar fitur berjalan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Buka Settings'),
          ),
        ],
      ),
    );

    if (openSettings == true) {
      await openAppSettings();
    }

    await _loadPermissionStatuses();
  }
}
