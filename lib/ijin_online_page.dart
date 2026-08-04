import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'main.dart';
import 'ads_helper.dart';
import 'permission_guard.dart';

class IjinOnlinePage extends StatefulWidget {
  const IjinOnlinePage({super.key});

  @override
  State<IjinOnlinePage> createState() => _IjinOnlinePageState();
}

class _IjinOnlinePageState extends State<IjinOnlinePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedFile;
  String? _selectedFileName;
  bool _isSubmitting = false;

  final List<String> _typeOptions = ['Sakit', 'Ijin'];

  // Indonesian month names
  final List<String> _monthsIndonesian = [
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

  @override
  void initState() {
    super.initState();
    // Load interstitial ad when page initializes
    AdsHelper.loadInterstitialAd();
  }

  @override
  void dispose() {
    // Clean up ads
    AdsHelper.dispose();
    super.dispose();
  }

  // Format date to Indonesian format
  String _formatDate(DateTime date) {
    return '${date.day} ${_monthsIndonesian[date.month - 1]} ${date.year}';
  }

  // Show date picker for start date
  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple.shade900,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, clear end date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  // Show date picker for end date
  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple.shade900,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  // Pick file from device
  Future<void> _pickFile() async {
    final granted = await PermissionGuard.ensurePermission(
      context,
      RequiredPermission.file,
    );
    if (!granted) {
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: ${e.toString()}')),
        );
      }
    }
  }

  // Capture image using camera
  Future<void> _captureImage() async {
    final granted = await PermissionGuard.ensurePermission(
      context,
      RequiredPermission.camera,
    );
    if (!granted) {
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _selectedFileName = photo.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: ${e.toString()}')),
        );
      }
    }
  }

  // Show options to pick file or capture image
  void _showFileOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Pilih Sumber',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                  title: const Text('Ambil Foto'),
                  subtitle: const Text('Gunakan kamera untuk mengambil foto'),
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.folder_open,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                  title: const Text('Pilih File'),
                  subtitle: const Text('Pilih dari galeri atau file manager'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  // Submit form to API
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan tanggal akhir')),
      );
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih file surat')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare multipart request
      final endpoint = '$API_BASE_URL/ijin';
      var request = http.MultipartRequest('POST', Uri.parse(endpoint));

      // Add authorization header with bearer token
      if (SessionManager.authToken != null) {
        request.headers['Authorization'] = 'Bearer ${SessionManager.authToken}';
      }

      // Add form fields
      request.fields['type'] = _selectedType!;
      request.fields['start_date'] = _startDate!.toIso8601String();
      request.fields['end_date'] = _endDate!.toIso8601String();
      request.fields['siswa_id'] = SessionManager.siswaId ?? '';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('surat', _selectedFile!.path),
      );

      // Send request
      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ijin berhasil diajukan')),
          );
          // Show interstitial ad before navigating back (non-blocking)
          await AdsHelper.showInterstitialAd();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text('Ijin Online', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 60,
                        color: Colors.deepPurple.shade900,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Form Pengajuan Izin',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade900,
                            ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Dropdown for Type
                Text(
                  'Jenis Izin',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintText: 'Pilih jenis izin',
                  ),
                  items: _typeOptions.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedType = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Pilih jenis ijin';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Date Range Selection
                Text(
                  'Tanggal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Mulai',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _selectStartDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _startDate != null
                                  ? _formatDate(_startDate!)
                                  : 'Pilih',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple.shade900,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Akhir',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _startDate != null
                                ? _selectEndDate
                                : null,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _endDate != null
                                  ? _formatDate(_endDate!)
                                  : 'Pilih',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _startDate != null
                                  ? Colors.deepPurple.shade900
                                  : Colors.grey.shade400,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Display selected date range
                if (_startDate != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      border: Border.all(color: Colors.deepPurple.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          color: Colors.deepPurple.shade900,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _endDate != null
                                ? '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}'
                                : _formatDate(_startDate!),
                            style: TextStyle(
                              color: Colors.deepPurple.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_startDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // File Upload
                Text(
                  'Surat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showFileOptions,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Pilih Surat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_selectedFileName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade900,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                            'Kirim Pengajuan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
