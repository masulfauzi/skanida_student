import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class Presensi {
  final String tanggal;
  final String? waktuPresensi;
  final String status;

  Presensi({required this.tanggal, this.waktuPresensi, required this.status});

  factory Presensi.fromJson(Map<String, dynamic> json) {
    return Presensi(
      tanggal: json['tgl']?.toString() ?? 'Data tidak valid',
      waktuPresensi: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).add(const Duration(hours: 7)).toString().split(' ')[1].substring(0, 8)
          : null,
      status: json['status']?.toString() ?? 'Data tidak valid',
    );
  }
}

class RekapPresensiPage extends StatefulWidget {
  const RekapPresensiPage({super.key});

  @override
  State<RekapPresensiPage> createState() => _RekapPresensiPageState();
}

class _RekapPresensiPageState extends State<RekapPresensiPage> {
  late Future<List<Presensi>> _futurePresensi;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _futurePresensi = _fetchPresensiData();
  }

  Future<List<Presensi>> _fetchPresensiData({int? month, int? year}) async {
    await SessionManager.loadSession(); // Ensure session data is loaded

    final String? siswaId = SessionManager.siswaId;
    final String? authToken = SessionManager.authToken;

    if (siswaId == null || authToken == null) {
      throw Exception('Sesi tidak valid. Silakan login kembali.');
    }

    final int targetMonth = month ?? _selectedMonth;
    final int targetYear = year ?? _selectedYear;
    final Uri uri = Uri.parse('$API_BASE_URL/presensi/$siswaId/$targetMonth/$targetYear');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> data = jsonData['data'];
        return data.map((item) => Presensi.fromJson(item)).toList();
      } else {
        throw Exception(
          'Gagal memuat data presensi (Status code: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Gagal mengambil data');
    }
  }

  void _updateFilter() {
    setState(() {
      _futurePresensi = _fetchPresensiData(month: _selectedMonth, year: _selectedYear);
    });
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return monthNames[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Presensi'),
        backgroundColor: Colors.deepPurple.shade900,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _futurePresensi = _fetchPresensiData();
          });
        },
        child: FutureBuilder<List<Presensi>>(
          future: _futurePresensi,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal mengambil data',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _futurePresensi = _fetchPresensiData();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('Tidak ada data rekap presensi.'),
              );
            }

            final presensiData = snapshot.data!;

            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Bulan',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              isExpanded: true,
                              items: List.generate(12, (index) {
                                return DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(_getMonthName(index + 1)),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedMonth = value;
                                  });
                                  _updateFilter();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tahun',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              isExpanded: true,
                              items: List.generate(5, (index) {
                                final year = DateTime.now().year - 4 + index;
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text(year.toString()),
                                );
                              }),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedYear = value;
                                  });
                                  _updateFilter();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                  child: Text(
                    'Presensi Bulan: ${_getMonthName(_selectedMonth)} $_selectedYear',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16.0),
                  child: DataTable(
                    border: TableBorder.all(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    headingRowColor: MaterialStateProperty.all(
                      Colors.deepPurple.shade50,
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Tanggal',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Waktu\nPresensi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: presensiData.map((presensi) {
                      return DataRow(
                        cells: [
                          DataCell(Text(presensi.tanggal)),
                          DataCell(Text(presensi.waktuPresensi ?? '-')),
                          DataCell(
                            Text(
                              presensi.status,
                              style: TextStyle(
                                color: presensi.status == 'Hadir'
                                    ? Colors.green.shade700
                                    : (presensi.status == 'Absen'
                                          ? Colors.red.shade700
                                          : Colors.orange.shade700),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
