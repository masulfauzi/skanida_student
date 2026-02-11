import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class IjinSholatPage extends StatefulWidget {
  const IjinSholatPage({super.key});

  @override
  State<IjinSholatPage> createState() => _IjinSholatPageState();
}

class _IjinSholatPageState extends State<IjinSholatPage> {
  final _formKey = GlobalKey<FormState>();
  String _selectedDate = '';
  String _selectedJenisSholat = '';
  String _alasan = '';
  String _keterangan = '';
  bool _isLoading = false;

  final List<String> alasanijin = ['Haid'];

  @override
  void initState() {
    super.initState();
    // Set today's date as default
    _selectedDate = DateTime.now().toString().split(' ')[0];
  }

  // Format date to Indonesian format
  String _formatDateIndonesian(String dateString) {
    try {
      final date = DateTime.parse(dateString);
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
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _submitIzin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      final endpoint = '$API_BASE_URL/ijin-sholat';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${SessionManager.authToken}',
        },
        body: jsonEncode({
          'nisn': SessionManager.currentUsername,
          'tanggal': _selectedDate,
          'alasan': _selectedJenisSholat,
          'keterangan': _keterangan,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin sholat berhasil diajukan'),
            backgroundColor: Colors.green,
          ),
        );
        // Redirect to main page after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pushReplacementNamed('/home');
        });
      } else {
        String errorMessage = 'Gagal mengajukan izin';
        try {
          final jsonData = jsonDecode(response.body);
          errorMessage = jsonData['message'] ?? errorMessage;
        } catch (e) {
          // If response body is not JSON, just use default message
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toString().split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text('Izin Sholat', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date field
              Text(
                'Tanggal',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateIndonesian(_selectedDate),
                      style: const TextStyle(color: Colors.black),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Colors.deepPurple.shade900,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Alasan Ijin dropdown
              Text(
                'Alasan Izin',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedJenisSholat.isEmpty
                    ? null
                    : _selectedJenisSholat,
                items: alasanijin.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedJenisSholat = value ?? '';
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Pilih alasan izin',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alasan izin harus dipilih';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Keterangan field
              Text(
                'Keterangan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                maxLines: 4,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Tuliskan keterangan tambahan (opsional)',
                ),
                onSaved: (value) {
                  _keterangan = value ?? '';
                },
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitIzin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Ajukan Izin',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
