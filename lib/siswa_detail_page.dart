import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'main.dart'; // To access SessionManager and API constants
import 'permission_guard.dart';

class SiswaService {
  static Future<Map<String, dynamic>> getSiswaData() async {
    try {
      final url = SessionManager.siswaId != null
          ? '$API_BASE_URL/siswa?siswaId=${SessionManager.siswaId}'
          : '$API_BASE_URL/siswa';
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (SessionManager.authToken != null)
          'Authorization': 'Bearer ${SessionManager.authToken}',
      };

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        return {
          'success': true,
          'message': 'Data fetched successfully',
          'data': jsonResponse['data'] ?? jsonResponse,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized - please login again',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Data not found'};
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on Exception catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }
}

class SiswaDetailPage extends StatefulWidget {
  const SiswaDetailPage({super.key});

  @override
  State<SiswaDetailPage> createState() => _SiswaDetailPageState();
}

class _SiswaDetailPageState extends State<SiswaDetailPage> {
  late Future<Map<String, dynamic>> _siswaData;
  File? _pickedPhoto;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _siswaData = SiswaService.getSiswaData();
  }

  Future<void> _pickAndUploadPhoto() async {
    final granted = await PermissionGuard.ensurePermission(
      context,
      RequiredPermission.file,
    );
    if (!granted) {
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      _pickedPhoto = file;
      _uploading = true;
    });

    try {
      final uri = Uri.parse('$API_BASE_URL/siswa/upload-foto');
      final request = http.MultipartRequest('POST', uri);
      if (SessionManager.authToken != null) {
        request.headers['Authorization'] = 'Bearer ${SessionManager.authToken}';
      }
      if (SessionManager.siswaId != null) {
        request.fields['siswaId'] = SessionManager.siswaId!;
      }
      request.files.add(await http.MultipartFile.fromPath('foto', file.path));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      await response.stream.drain();

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto profil berhasil diupload')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal upload foto: ${response.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text('Data Siswa', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _siswaData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!['success']) {
            return Center(
              child: Text(
                snapshot.data?['message'] ?? 'No data found',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          final siswaData = snapshot.data!['data'];

          // Handle both single object and list formats
          final List<dynamic> items;
          if (siswaData is List) {
            items = siswaData;
          } else if (siswaData is Map) {
            items = [siswaData];
          } else {
            items = [];
          }

          if (items.isEmpty) {
            return const Center(child: Text('No siswa data available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final siswa = items[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _uploading ? null : _pickAndUploadPhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 80,
                              backgroundColor: Colors.deepPurple.shade100,
                              backgroundImage: _pickedPhoto != null
                                  ? FileImage(_pickedPhoto!)
                                  : (siswa['foto'] != null &&
                                        siswa['foto'].toString().isNotEmpty)
                                  ? NetworkImage(
                                      siswa['foto'].toString().startsWith(
                                            'http',
                                          )
                                          ? siswa['foto']
                                          : '$API_BASE_URL/../foto_profil/${siswa['foto']}',
                                    )
                                  : null,
                              child:
                                  (_pickedPhoto == null &&
                                      (siswa['foto'] == null ||
                                          siswa['foto'].toString().isEmpty))
                                  ? Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.deepPurple.shade400,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: _uploading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Nama',
                        siswa['nama_siswa'] ?? siswa['name'] ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('NIS', siswa['nis'] ?? '-'),
                      const SizedBox(height: 8),
                      _buildDetailRow('NISN', siswa['nisn'] ?? '-'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Kelas',
                        siswa['kelas'] ?? siswa['class'] ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('Email', siswa['email'] ?? '-'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'No. Telepon',
                        siswa['no_hp'] ?? siswa['phone'] ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow('NIK', siswa['nik'] ?? '-'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        const Text(': '),
        Expanded(
          child: Text(
            value.toString(),
            style: const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
