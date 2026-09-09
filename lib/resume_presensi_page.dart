import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';
import 'presensi_draft.dart';
import 'presensi_uploader.dart';

/// Shown right after the app starts when a pending presensi selfie was
/// found on disk (see [PresensiDraft]). This happens when Android killed
/// the whole app process while the native camera app was in the
/// foreground, or while the upload request was still in flight — in both
/// cases the user had already taken a photo, so we let them resume instead
/// of silently landing on the dashboard and forcing them to retake it.
class ResumePresensiPage extends StatefulWidget {
  final String photoPath;
  final String siswaId;

  const ResumePresensiPage({
    super.key,
    required this.photoPath,
    required this.siswaId,
  });

  @override
  State<ResumePresensiPage> createState() => _ResumePresensiPageState();
}

class _ResumePresensiPageState extends State<ResumePresensiPage> {
  bool _isUploading = false;

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MyHomePage(title: 'Skanida Student'),
      ),
    );
  }

  Future<void> _cancel() async {
    await PresensiDraft.clear();
    _goToDashboard();
  }

  Future<void> _sendNow() async {
    setState(() {
      _isUploading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');

    if (authToken == null) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Token autentikasi tidak ditemukan. Silakan login kembali.',
            ),
          ),
        );
      }
      return;
    }

    final bytes = await File(widget.photoPath).readAsBytes();
    final result = await PresensiUploader.upload(
      imageBytes: bytes,
      siswaId: widget.siswaId,
      authToken: authToken,
    );

    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });

    if (result.success) {
      await PresensiDraft.clear();
      if (!mounted) return;
      await showPresensiSuccessDialog(
        context,
        result.data!,
        onClose: _goToDashboard,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gagal mengirim presensi'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        automaticallyImplyLeading: false,
        title: const Text(
          'Lanjutkan Presensi',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'Sepertinya presensi terakhir Anda terhenti sebelum foto '
                'terkirim. Lanjutkan mengirim foto ini?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(widget.photoPath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploading ? null : _cancel,
                      child: const Text('Batalkan'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple.shade900,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isUploading ? null : _sendNow,
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Kirim Sekarang'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
