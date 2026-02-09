import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class PresensiSholatPage extends StatefulWidget {
  const PresensiSholatPage({super.key});

  @override
  State<PresensiSholatPage> createState() => _PresensiSholatPageState();
}

class _PresensiSholatPageState extends State<PresensiSholatPage> {
  List<dynamic> _sholatList = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadPresensiSholat();
  }

  // Load presensi sholat data from API
  Future<void> _loadPresensiSholat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint =
          '$API_BASE_URL/presensi-sholat?nisn=${SessionManager.currentUsername}&bulan=$_selectedMonth&tahun=$_selectedYear';

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
          _sholatList = jsonData['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _sholatList = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _sholatList = [];
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

  // Format time
  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '-';
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  // Get month name
  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }

  // Filter data by selected month
  List<dynamic> _getFilteredData() {
    return _sholatList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text(
          'Presensi Sholat',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sholatList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data presensi sholat',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Year and Month filters
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        // Month dropdown
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedMonth,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: List.generate(12, (index) {
                                return DropdownMenuItem<int>(
                                  value: index + 1,
                                  child: Text(_getMonthName(index + 1)),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _selectedMonth =
                                      value ?? DateTime.now().month;
                                  _loadPresensiSholat();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year dropdown
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedYear,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: List.generate(5, (index) {
                                final year = DateTime.now().year - 4 + index;
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(year.toString()),
                                );
                              }),
                              onChanged: (value) {
                                setState(() {
                                  _selectedYear = value ?? DateTime.now().year;
                                  _loadPresensiSholat();
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Data table
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
                            'No',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Tanggal',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: _getFilteredData().asMap().entries.map((entry) {
                        final index = entry.key + 1;
                        final sholat = entry.value;
                        final createdAt = sholat['created_at'];
                        final status = sholat['status'];
                        final tanggal = sholat['tgl'] != null
                            ? _formatDate(sholat['tgl'])
                            : '-';

                        return DataRow(
                          cells: [
                            DataCell(Text(index.toString())),
                            DataCell(Text(tanggal)),
                            DataCell(
                              Text(
                                status,
                                style: TextStyle(
                                  color: status == 'Hadir'
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
