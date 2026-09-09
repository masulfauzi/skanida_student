import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'permission_guard.dart';
import 'presensi_draft.dart';
import 'presensi_uploader.dart';

class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({super.key});

  @override
  State<SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<SelfieCameraPage> {
  final ImagePicker _picker = ImagePicker();
  // Image bytes are kept in memory because the picker's cache file
  // (cache/scaled_*.jpg) can be deleted by the OS or cleaner apps
  // before the user taps upload. A copy is also persisted to disk via
  // PresensiDraft so the photo survives the app process being killed
  // by Android while the native camera app is in the foreground.
  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    // Automatically open the camera when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeSelfie();
    });
  }

  Future<void> _takeSelfie() async {
    try {
      final granted = await PermissionGuard.ensurePermission(
        context,
        RequiredPermission.camera,
      );

      if (!granted) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (photo == null) {
        // User membatalkan dari aplikasi kamera OS, tidak ada foto baru.
        if (mounted && _capturedImageBytes == null) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Read the bytes immediately: the cache file the picker returns
      // may be deleted before the upload request finishes.
      final bytes = await photo.readAsBytes();
      if (mounted) {
        setState(() {
          _capturedImageBytes = bytes;
        });
      }

      // Persist the photo to disk right away so it isn't lost if the
      // OS kills the app process before/while the upload is happening.
      final siswaId = SessionManager.siswaId;
      if (siswaId != null) {
        await PresensiDraft.save(bytes: bytes, siswaId: siswaId);
      }

      // Tidak ada lagi langkah konfirmasi manual: begitu foto diambil,
      // langsung kirim ke server.
      await _uploadImage(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening camera: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _uploadImage(Uint8List imageBytes) async {
    // Get siswaId from SessionManager and authToken from SharedPreferences
    final siswaId = SessionManager.siswaId;
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');

    if (siswaId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Siswa ID tidak ditemukan. Silakan login kembali.'),
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    if (authToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Token autentikasi tidak ditemukan. Silakan login kembali.',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    final result = await PresensiUploader.upload(
      imageBytes: imageBytes,
      siswaId: siswaId,
      authToken: authToken,
    );

    if (!mounted) return;

    if (result.success) {
      // Upload succeeded: the pending draft is no longer needed.
      await PresensiDraft.clear();
      if (!mounted) return;
      await showPresensiSuccessDialog(
        context,
        result.data!,
        onClose: () => Navigator.of(context).pop(true),
      );
    } else {
      await _showUploadFailedDialog(
        result.errorMessage ?? 'Gagal mengirim presensi',
        imageBytes,
      );
    }
  }

  Future<void> _showUploadFailedDialog(String message, Uint8List bytes) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Presensi Gagal Terkirim'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // tutup dialog
              await PresensiDraft.clear();
              if (mounted) {
                Navigator.of(context).pop(); // kembali ke halaman Presensi
              }
            },
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // tutup dialog
              _takeSelfie(); // buka kamera lagi, ambil foto baru
            },
            child: const Text('Ambil Ulang'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // tutup dialog
              _uploadImage(bytes); // kirim ulang foto yang sama
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Ambil Foto Selfie',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _capturedImageBytes == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Preview foto yang baru diambil
                Image.memory(_capturedImageBytes!, fit: BoxFit.contain),
                // Overlay gelap + status pengiriman
                Container(color: Colors.black.withOpacity(0.45)),
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Mengirim presensi...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
