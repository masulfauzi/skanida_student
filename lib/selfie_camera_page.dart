import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'main.dart';

class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({super.key});

  @override
  State<SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<SelfieCameraPage> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isTakingPicture = false;

  // Format datetime to Indonesian format (UTC+7)
  String _formatDateTimeIndonesian(String dateTimeString) {
    try {
      // Parse UTC datetime
      final dateTimeUtc = DateTime.parse(dateTimeString);

      // Convert to Indonesian time (UTC+7)
      final dateTimeIndonesia = dateTimeUtc.add(const Duration(hours: 7));

      const List<String> monthsIndonesian = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      final day = dateTimeIndonesia.day;
      final month = monthsIndonesian[dateTimeIndonesia.month - 1];
      final year = dateTimeIndonesia.year;
      final hour = dateTimeIndonesia.hour.toString().padLeft(2, '0');
      final minute = dateTimeIndonesia.minute.toString().padLeft(2, '0');

      return '$day $month $year, $hour:$minute WIB';
    } catch (e) {
      return dateTimeString; // Return original string if parsing fails
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      // Find front camera for selfie
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
    });

    try {
      final image = await _cameraController!.takePicture();

      if (mounted) {
        // Upload the image to the API
        await _uploadImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _uploadImage(String imagePath) async {
    try {
      // Get siswaId from SessionManager and authToken from SharedPreferences
      final siswaId = SessionManager.siswaId;
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (siswaId == null) {
        if (mounted) {
          setState(() {
            _isTakingPicture = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Siswa ID tidak ditemukan. Silakan login kembali.'),
            ),
          );
        }
        return;
      }

      if (authToken == null) {
        if (mounted) {
          setState(() {
            _isTakingPicture = false;
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

      // Prepare multipart request
      final uri = Uri.parse('$API_BASE_URL/presensi');
      final request = http.MultipartRequest('POST', uri);

      // Add authentication header
      request.headers['Authorization'] = 'Bearer $authToken';
      request.headers['Accept'] = 'application/json';

      // Add siswaId field
      request.fields['siswaId'] = siswaId;

      // Add image file
      final imageFile = File(imagePath);
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Parse response
          try {
            final jsonResponse = json.decode(response.body);
            // Show success dialog with attendance details
            _showSuccessDialog(jsonResponse);
          } catch (e) {
            // If JSON parsing fails, show the raw response
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Response parsing error: ${e.toString()}\nResponse: ${response.body}',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Handle error - show detailed error information
          String errorMessage = 'Status ${response.statusCode}: ';
          try {
            final errorJson = json.decode(response.body);
            errorMessage += errorJson['message'] ?? errorJson.toString();
          } catch (e) {
            // If response is not JSON, show raw body
            errorMessage += response.body;
          }

          // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
              const SizedBox(width: 12),
              const Text('Presensi Berhasil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Waktu',
                _formatDateTimeIndonesian(
                  data['data']?['created_at'] ??
                      data['data']?['updated_at'] ??
                      data['waktu'] ??
                      data['timestamp'] ??
                      '-',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to previous page
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.deepPurple.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
      body: _isInitialized
          ? Stack(
              children: [
                // Camera preview
                Center(child: CameraPreview(_cameraController!)),
                // Capture button at the bottom
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isTakingPicture ? null : _takePicture,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.deepPurple.shade900,
                            width: 4,
                          ),
                        ),
                        child: _isTakingPicture
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.deepPurple,
                                ),
                              )
                            : Icon(
                                Icons.camera_alt,
                                size: 35,
                                color: Colors.deepPurple.shade900,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
