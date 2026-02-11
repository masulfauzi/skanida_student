import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isUploading = false;

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
    // Automatically open the camera when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _takeSelfie();
    });
  }

  Future<void> _takeSelfie() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      } else if (mounted && _capturedImage == null) {
        // User cancelled without taking a photo, go back
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening camera: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _uploadImage(String imagePath) async {
    setState(() {
      _isUploading = true;
    });
    try {
      // Get siswaId from SessionManager and authToken from SharedPreferences
      final siswaId = SessionManager.siswaId;
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');

      if (siswaId == null) {
        if (mounted) {
          setState(() {
            _isUploading = false;
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
          _isUploading = false;
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
          _isUploading = false;
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
      body: _capturedImage != null
          ? Stack(
              children: [
                // Image preview
                Center(
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.contain,
                  ),
                ),
                // Bottom buttons: Retake and Upload
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Retake button
                      GestureDetector(
                        onTap: _isUploading ? null : _takeSelfie,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey.shade600,
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.refresh,
                            size: 30,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      // Upload button
                      GestureDetector(
                        onTap: _isUploading
                            ? null
                            : () => _uploadImage(_capturedImage!.path),
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
                          child: _isUploading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.deepPurple,
                                  ),
                                )
                              : Icon(
                                  Icons.check,
                                  size: 35,
                                  color: Colors.deepPurple.shade900,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
