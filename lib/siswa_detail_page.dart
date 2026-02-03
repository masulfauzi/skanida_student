import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart'; // To access SessionManager and API constants

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

  @override
  void initState() {
    super.initState();
    _siswaData = SiswaService.getSiswaData();
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Nama',
                        siswa['nama_siswa'] ?? siswa['name'] ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'NIS',
                        siswa['nis'] ?? siswa['nisn'] ?? '-',
                      ),
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
                        siswa['no_telepon'] ?? siswa['phone'] ?? '-',
                      ),
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
