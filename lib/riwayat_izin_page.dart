import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class RiwayatIzinPage extends StatefulWidget {
  const RiwayatIzinPage({super.key});

  @override
  State<RiwayatIzinPage> createState() => _RiwayatIzinPageState();
}

class _RiwayatIzinPageState extends State<RiwayatIzinPage> {
  List<dynamic> _izinList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRiwayatIzin();
  }

  // Load permit history from API with dummy data fallback
  Future<void> _loadRiwayatIzin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint =
          '$API_BASE_URL/riwayat-izin?siswa_id=${SessionManager.siswaId}';

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${SessionManager.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          _izinList = jsonData['data'] ?? [];
          _isLoading = false;
        });
      } else {
        // Load dummy data on error
        _loadDummyData();
      }
    } catch (e) {
      // Load dummy data on exception
      _loadDummyData();
    }
  }

  // Load dummy data for development/testing
  void _loadDummyData() {
    final dummyData = [
      {
        'id': 2,
        'tipe_izin': 'Keluar Kelas',
        'jam_keluar': 3,
        'jam_masuk': 4,
        'guru_pengampu': 'Ibu Siti Nurhaliza',
        'keperluan': 'Minum air dan kamar kecil',
        'status_izin': 'menunggu',
        'created_at': '2026-02-03T09:15:00',
      },
      {
        'id': 4,
        'tipe_izin': 'Keluar Kelas',
        'jam_keluar': 5,
        'jam_masuk': 5,
        'guru_pengampu': 'Bapak Ahmad Ridho',
        'keperluan': 'Perlu izin khusus',
        'status_izin': 'disetujui',
        'created_at': '2026-02-02T11:30:00',
      },
      {
        'id': 6,
        'tipe_izin': 'Keluar Kelas',
        'jam_keluar': 2,
        'jam_masuk': 3,
        'guru_pengampu': 'Ibu Dewi Lestari',
        'keperluan': 'Sakit kepala',
        'status_izin': 'disetujui',
        'created_at': '2026-02-01T08:00:00',
      },
      {
        'id': 7,
        'tipe_izin': 'Keluar Kelas',
        'jam_keluar': 7,
        'jam_masuk': 8,
        'guru_pengampu': 'Bapak Bambang Suryanto',
        'keperluan': 'Mengurus administrasi',
        'status_izin': 'ditolak',
        'created_at': '2026-01-31T10:30:00',
      },
    ];

    setState(() {
      _izinList = dummyData;
      _isLoading = false;
    });
  }

  // Format date to Indonesian format
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Get status color
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'disetujui':
      case 'approved':
        return Colors.green;
      case 'ditolak':
      case 'rejected':
        return Colors.red;
      case 'menunggu':
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Get status text
  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'disetujui':
        return 'Disetujui';
      case 'ditolak':
        return 'Ditolak';
      case 'menunggu':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
        return 'Menunggu';
      default:
        return status ?? 'Tidak diketahui';
    }
  }

  // Get permit type icon
  IconData _getPermitTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'ijin presensi':
      case 'ijin_presensi':
        return Icons.mail;
      case 'keluar kelas':
      case 'keluar_kelas':
        return Icons.exit_to_app;
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text(
          'Riwayat Izin',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Main content
                Expanded(
                  child: _izinList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada riwayat izin',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRiwayatIzin,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _izinList.where((item) => (item['tipe_izin'] ?? '').toString().toLowerCase().contains('keluar')).length,
                            itemBuilder: (context, index) {
                              final filteredList = _izinList.where((item) => (item['tipe_izin'] ?? '').toString().toLowerCase().contains('keluar')).toList();
                              final izin = filteredList[index];
                              final tipe =
                                  izin['tipe_izin'] ??
                                  izin['jenis_izin'] ??
                                  'Tidak diketahui';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getPermitTypeIcon(tipe),
                                                  color: Colors
                                                      .deepPurple
                                                      .shade900,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    tipe,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .deepPurple
                                                              .shade900,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                izin['status_izin'],
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                  izin['status_izin'],
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusText(
                                                izin['status_izin'],
                                              ),
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                  izin['status_izin'],
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Date range for ijin presensi
                                      if (izin['start_date'] != null &&
                                          izin['end_date'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${_formatDate(izin['start_date'])} - ${_formatDate(izin['end_date'])} (${izin['lama_ijin'] ?? '-'} hari)',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      // Lesson info for keluar kelas
                                      if (izin['jam_keluar'] != null &&
                                          izin['jam_masuk'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Jam ke-${izin['jam_keluar']} s/d Jam ke-${izin['jam_masuk']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      // Teacher info for keluar kelas
                                      if (izin['guru_pengampu'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Guru: ${izin['guru_pengampu']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      // Description/reason
                                      if (izin['keperluan'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.description,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Keperluan: ${izin['keperluan']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      // Submission date
                                      if (izin['created_at'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Diajukan: ${_formatDate(izin['created_at'])}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
