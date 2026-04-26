import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'main.dart';
import 'ads_helper.dart';

class KeluarKelasPage extends StatefulWidget {
  const KeluarKelasPage({super.key});

  @override
  State<KeluarKelasPage> createState() => _KeluarKelasPageState();
}

class _KeluarKelasPageState extends State<KeluarKelasPage> {
  final _formKey = GlobalKey<FormState>();
  String? _jenisIzin;
  String? _keperluan;
  String? _selectedTeacher;
  int? _lessonToLeave;
  int? _lessonToJoin;
  bool _isSubmitting = false;
  bool _isLoadingTeachers = true;
  bool _isLoadingJenisIzin = true;

  List<Map<String, dynamic>> _teachers = [];
  Map<String, String> _teacherNames = {}; // Map id_guru to nama for display
  List<Map<String, dynamic>> _jenisIzinList = []; // Store jenis izin from API

  final List<int> _lessons = List.generate(11, (index) => index + 1);

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    _loadJenisIzin();
    // Load interstitial ad when page initializes
    AdsHelper.loadInterstitialAd();
  }

  @override
  void dispose() {
    // Clean up ads
    AdsHelper.dispose();
    super.dispose();
  }

  // Load jenis izin from API
  Future<void> _loadJenisIzin() async {
    try {
      final endpoint = '$API_BASE_URL/jenis-ijin-kelas';

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
        final data = jsonData['data'] as List;

        setState(() {
          _jenisIzinList = List<Map<String, dynamic>>.from(data);
          _isLoadingJenisIzin = false;
        });
      } else {
        setState(() {
          _isLoadingJenisIzin = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingJenisIzin = false;
      });
    }
  }

  // Load teachers from API
  Future<void> _loadTeachers() async {
    try {
      final endpoint = '$API_BASE_URL/get_guru';

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
        final data = jsonData['data'] as List;

        setState(() {
          _teachers = List<Map<String, dynamic>>.from(data);
          _teacherNames = {
            for (var teacher in data)
              teacher['id_guru'].toString(): teacher['nama'],
          };
          _isLoadingTeachers = false;
        });
      } else {
        setState(() {
          _isLoadingTeachers = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingTeachers = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final endpoint = '$API_BASE_URL/keluar-kelas';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${SessionManager.authToken}',
        },
        body: jsonEncode({
          'id_siswa': SessionManager.siswaId,
          'id_jenis_ijin_kelas': _jenisIzin,
          'keperluan': _keperluan,
          'id_guru': _selectedTeacher,
          'jam_keluar': _lessonToLeave,
          'jam_masuk': _lessonToJoin,
        }),
      );

      setState(() {
        _isSubmitting = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog();
      } else {
        final jsonResponse = jsonDecode(response.body);
        final errorMessage =
            jsonResponse['message'] ??
            'Terjadi kesalahan saat mengajukan izin keluar kelas';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Berhasil'),
        content: const Text(
          'Izin keluar kelas berhasil diajukan. Mohon tunggu konfirmasi dari guru.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              // Show interstitial ad before navigating back
              await AdsHelper.showInterstitialAd();
              if (mounted) {
                Navigator.pop(context); // Go back to home
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text(
          'Izin Keluar Kelas',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instruction
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Isi form di bawah untuk mengajukan izin keluar kelas. Guru akan mengkonfirmasi permohonan Anda.',
                    style: TextStyle(color: Colors.blue.shade900),
                  ),
                ),
                const SizedBox(height: 24),

                // Jenis Izin Dropdown
                Text(
                  'Jenis Izin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingJenisIzin
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      )
                    : DropdownButtonFormField<String>(
                        value: _jenisIzin,
                        items: _jenisIzinList.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id'].toString(),
                            child: Text(
                              item['jenis_ijin_keluar_kelas'] ??
                                  'Tidak diketahui',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _jenisIzin = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih jenis izin';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Pilih jenis izin',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                const SizedBox(height: 24),

                // Keperluan Text Input
                Text(
                  'Keperluan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  onChanged: (value) {
                    setState(() {
                      _keperluan = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Masukkan keperluan';
                    }
                    return null;
                  },
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Jelaskan keperluan Anda',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Guru Pengampu Dropdown
                Text(
                  'Guru Pengampu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoadingTeachers
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedTeacher,
                        items: _teachers.map((teacher) {
                          return DropdownMenuItem<String>(
                            value: teacher['id_guru'].toString(),
                            child: Text(teacher['nama'] ?? 'Tidak diketahui'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTeacher = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih guru pengampu';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Pilih guru pengampu',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                const SizedBox(height: 24),

                // Time to Leave
                Text(
                  'Jam Keluar Kelas (Jam ke-)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _lessonToLeave,
                  items: _lessons.map((lesson) {
                    return DropdownMenuItem<int>(
                      value: lesson,
                      child: Text('Jam ke-$lesson'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _lessonToLeave = value;
                      _lessonToJoin =
                          null; // Reset return lesson when exit lesson changes
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Pilih jam keluar kelas';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Pilih jam keluar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Time to Join Again
                Text(
                  'Jam Kembali Masuk Kelas (Jam ke-)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _lessonToJoin,
                  items: _lessons
                      .where(
                        (lesson) =>
                            _lessonToLeave == null || lesson >= _lessonToLeave!,
                      )
                      .map((lesson) {
                        return DropdownMenuItem<int>(
                          value: lesson,
                          child: Text('Jam ke-$lesson'),
                        );
                      })
                      .toList(),
                  onChanged: _lessonToLeave != null
                      ? (value) {
                          setState(() {
                            _lessonToJoin = value;
                          });
                        }
                      : null,
                  validator: (value) {
                    if (value == null) {
                      return 'Pilih jam kembali masuk kelas';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Pilih jam masuk',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    helperText: _lessonToLeave == null
                        ? 'Pilih jam keluar kelas terlebih dahulu'
                        : '',
                  ),
                ),
                const SizedBox(height: 32),

                // Duration Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Permohonan:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keperluan: ${_keperluan ?? '-'}',
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Guru Pengampu: ${_selectedTeacher != null ? _teacherNames[_selectedTeacher] ?? '-' : '-'}',
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jam Keluar: Jam ke-${_lessonToLeave ?? '-'}',
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jam Kembali: Jam ke-${_lessonToJoin ?? '-'}',
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Ajukan Permohonan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
