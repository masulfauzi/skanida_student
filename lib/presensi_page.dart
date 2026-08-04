import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'selfie_camera_page.dart';
import 'rekap_presensi_page.dart';

class PresensiPage extends StatefulWidget {
  const PresensiPage({super.key});

  @override
  State<PresensiPage> createState() => _PresensiPageState();
}

class _PresensiPageState extends State<PresensiPage> {
  // SMKN 2 Semarang coordinates (example - replace with actual school coordinates)
  static const LatLng schoolLocation = LatLng(-6.9862587, 110.4338476);

  MapController? _mapController;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingLocation = true;
        });
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Layanan lokasi dimatikan. Presensi lokasi tidak tersedia.',
            ),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
          _currentLocation = null;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
          setState(() {
            _isLoadingLocation = false;
            _currentLocation = null;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin lokasi ditolak permanen. Presensi lokasi tidak tersedia.',
            ),
          ),
        );
        setState(() {
          _isLoadingLocation = false;
          _currentLocation = null;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      setState(() {
        _isLoadingLocation = false;
        _currentLocation = null;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Calculate distance in kilometers using Haversine formula via latlong2
    final Distance distance = Distance();
    return distance(point1, point2);
  }

  @override
  Widget build(BuildContext context) {
    final distanceToSchool = _currentLocation == null
        ? null
        : _calculateDistance(_currentLocation!, schoolLocation);
    final withinRange = distanceToSchool != null && distanceToSchool <= 25;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: const Text('Presensi', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Top section with school name and fingerprint icon
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Location label and reload icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lokasi Presensi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.deepPurple.shade900,
                      ),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // School name and fingerprint icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SMKN 2 Semarang',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade900,
                                ),
                          ),
                          if (distanceToSchool != null && !withinRange)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Anda berada diluar jangkauan',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Colors.red.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.fingerprint,
                        size: 32,
                        color: withinRange
                            ? Colors.deepPurple.shade900
                            : Colors.grey.shade500,
                      ),
                      tooltip: withinRange
                          ? 'Mulai presensi'
                          : 'Aktifkan lokasi dan pastikan berada di area sekolah',
                      onPressed: withinRange
                          ? () async {
                              final imagePath = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SelfieCameraPage(),
                                ),
                              );
                              if (imagePath != null && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Presensi Berhasil Dilakukan',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepPurple.shade100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isLoadingLocation
                              ? Colors.orange.shade600
                              : distanceToSchool == null
                              ? Colors.grey.shade500
                              : withinRange
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLoadingLocation
                              ? 'Memeriksa lokasi...'
                              : distanceToSchool == null
                              ? 'Lokasi belum tersedia'
                              : withinRange
                              ? 'Dalam jangkauan presensi'
                              : 'Di luar jangkauan presensi',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.deepPurple.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (distanceToSchool != null)
                        Text(
                          '${distanceToSchool.toStringAsFixed(0)} m',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.deepPurple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Center content with map
          Expanded(
            child: _isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : _currentLocation == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 48,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Lokasi tidak tersedia. Aktifkan izin lokasi untuk presensi.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController ??= MapController(),
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.skanida_student',
                      ),
                      MarkerLayer(
                        markers: [
                          // Current location marker
                          Marker(
                            point: _currentLocation!,
                            width: 80,
                            height: 80,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 40,
                                  color: Colors.deepPurple.shade900,
                                ),
                                const Text(
                                  'Lokasi Anda',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // School location marker
                          Marker(
                            point: schoolLocation,
                            width: 80,
                            height: 80,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.school,
                                  size: 40,
                                  color: Colors.red.shade700,
                                ),
                                const Text(
                                  'Sekolah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          // Distance label
          if (_currentLocation != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                border: Border(
                  top: BorderSide(color: Colors.deepPurple.shade300, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jarak ke SMKN 2 Semarang',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_calculateDistance(_currentLocation!, schoolLocation)).toStringAsFixed(0)} meter',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple.shade900,
                    ),
                  ),
                ],
              ),
            ),
          // Bottom section with 1 icon in a row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RekapPresensiPage(),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Icon(
                        Icons.list,
                        size: 32,
                        color: Colors.deepPurple.shade900,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rekap',
                        style: TextStyle(color: Colors.deepPurple.shade900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
