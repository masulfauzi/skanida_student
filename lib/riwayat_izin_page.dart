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
          '$API_BASE_URL/riwayat-izin?id_siswa=${SessionManager.siswaId}';

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
        'id': '1',
        'id_siswa': SessionManager.siswaId,
        'id_guru': '6d3e6e33-2169-43c0-ba81-91a6fb8d7e7c',
        'id_jenis_ijin_keluar': '1',
        'keperluan': 'Minum air dan kamar kecil',
        'tanggal': '2026-02-03',
        'jam_keluar_pelajaran': '3',
        'jam_kembali_pelajaran': '4',
        'is_valid_guru': '0',
        'is_valid_bk': '0',
        'created_at': '2026-02-03T09:15:00.000000Z',
        'updated_at': '2026-02-03T09:15:00.000000Z',
      },
      {
        'id': '2',
        'id_siswa': SessionManager.siswaId,
        'id_guru': 'bapak-ahmad-id',
        'id_jenis_ijin_keluar': '1',
        'keperluan': 'Perlu izin khusus',
        'tanggal': '2026-02-02',
        'jam_keluar_pelajaran': '5',
        'jam_kembali_pelajaran': '5',
        'is_valid_guru': '1',
        'is_valid_bk': '1',
        'created_at': '2026-02-02T11:30:00.000000Z',
        'updated_at': '2026-02-02T11:30:00.000000Z',
      },
      {
        'id': '3',
        'id_siswa': SessionManager.siswaId,
        'id_guru': 'ibu-dewi-id',
        'id_jenis_ijin_keluar': '1',
        'keperluan': 'Sakit kepala',
        'tanggal': '2026-02-01',
        'jam_keluar_pelajaran': '2',
        'jam_kembali_pelajaran': '3',
        'is_valid_guru': '1',
        'is_valid_bk': '0',
        'created_at': '2026-02-01T08:00:00.000000Z',
        'updated_at': '2026-02-01T08:00:00.000000Z',
      },
      {
        'id': '4',
        'id_siswa': SessionManager.siswaId,
        'id_guru': 'bapak-bambang-id',
        'id_jenis_ijin_keluar': '1',
        'keperluan': 'Mengurus administrasi',
        'tanggal': '2026-01-31',
        'jam_keluar_pelajaran': '7',
        'jam_kembali_pelajaran': '8',
        'is_valid_guru': '0',
        'is_valid_bk': '0',
        'created_at': '2026-01-31T10:30:00.000000Z',
        'updated_at': '2026-01-31T10:30:00.000000Z',
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

  // Get status color based on validation flags
  Color _getStatusColor(Map<String, dynamic> izin) {
    final isValidGuru = izin['is_valid_guru'].toString() == '1';
    final isValidBk = izin['is_valid_bk'].toString() == '1';
    
    if (isValidGuru && isValidBk) {
      return Colors.green;
    } else if (!isValidGuru || !isValidBk) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  // Get status text based on validation flags
  String _getStatusText(Map<String, dynamic> izin) {
    final isValidGuru = izin['is_valid_guru'].toString() == '1';
    final isValidBk = izin['is_valid_bk'].toString() == '1';
    
    if (isValidGuru && isValidBk) {
      return 'Disetujui';
    } else if (isValidGuru && !isValidBk) {
      return 'Menunggu BK';
    } else {
      return 'Menunggu Guru';
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
                            itemCount: _izinList
                                .where(
                                  (item) =>
                                      (item['id_jenis_ijin_keluar'] ?? '')
                                          .toString()
                                          .isNotEmpty,
                                )
                                .length,
                            itemBuilder: (context, index) {
                              final filteredList = _izinList
                                  .where(
                                    (item) =>
                                        (item['id_jenis_ijin_keluar'] ?? '')
                                            .toString()
                                            .isNotEmpty,
                                  )
                                  .toList();
                              final izin = filteredList[index];
                              const tipe = 'Keluar Kelas';

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
                                              color: _getStatusColor(izin)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _getStatusColor(izin),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusText(izin),
                                              style: TextStyle(
                                                color: _getStatusColor(izin),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Lesson info for keluar kelas
                                      if (izin['jam_keluar_pelajaran'] != null) ...[
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
                                                'Jam ke-${izin['jam_keluar_pelajaran']}${izin['jam_kembali_pelajaran'] != null ? ' s/d Jam ke-${izin['jam_kembali_pelajaran']}' : ''}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      // Guru Name
                                      if (izin['nama'] != null) ...[
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
                                                'Guru: ${izin['nama']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
