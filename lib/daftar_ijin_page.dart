import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class DaftarIjinPage extends StatefulWidget {
  const DaftarIjinPage({super.key});

  @override
  State<DaftarIjinPage> createState() => _DaftarIjinPageState();
}

class _DaftarIjinPageState extends State<DaftarIjinPage> {
  List<dynamic> _ijinList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIjinList();
  }

  // Load ijin list from API
  Future<void> _loadIjinList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint = '$API_BASE_URL/ijin?siswa_id=${SessionManager.siswaId}';

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
          _ijinList = jsonData['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _ijinList = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _ijinList = [];
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text('Daftar Ijin', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Main content
                Expanded(
                  child: _ijinList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada data ijin',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadIjinList,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _ijinList.length,
                            itemBuilder: (context, index) {
                              final ijin = _ijinList[index];
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
                                            child: Text(
                                              ijin['jenis_ijin'] ??
                                                  'Tidak diketahui',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors
                                                        .deepPurple
                                                        .shade900,
                                                  ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                ijin['status_ijin'],
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: _getStatusColor(
                                                  ijin['status_ijin'],
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusText(
                                                ijin['status_ijin'],
                                              ),
                                              style: TextStyle(
                                                color: _getStatusColor(
                                                  ijin['status_ijin'],
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      if (ijin['start_date'] != null &&
                                          ijin['end_date'] != null) ...[
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
                                                '${_formatDate(ijin['start_date'])} - ${_formatDate(ijin['end_date'])} (${ijin['lama_ijin']} hari)',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      if (ijin['created_at'] != null) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Diajukan: ${_formatDate(ijin['created_at'])}',
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

  // Format date list
  String _formatDateList(dynamic dates) {
    if (dates is List && dates.isNotEmpty) {
      if (dates.length == 1) {
        return _formatDate(dates[0]);
      } else {
        return '${_formatDate(dates[0])} - ${_formatDate(dates[dates.length - 1])} (${dates.length} hari)';
      }
    } else if (dates is String) {
      try {
        final dateList = jsonDecode(dates) as List;
        return _formatDateList(dateList);
      } catch (e) {
        return dates;
      }
    }
    return 'Tidak ada tanggal';
  }
}
