import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'siswa_detail_page.dart';
import 'login_page.dart';
import 'splash_screen.dart';
import 'presensi_page.dart';
import 'ijin_online_page.dart';
import 'daftar_ijin_page.dart';
import 'keluar_kelas_page.dart';
import 'riwayat_izin_page.dart';
import 'presensi_sholat_page.dart';
import 'ijin_sholat_page.dart';

// API Configuration
const String API_BASE_URL = 'https://apps.smkn2semarang.sch.id/api';
const String LOGIN_ENDPOINT = '/login';

class AuthService {
  static Future<Map<String, dynamic>> loginWithAPI(
    String username,
    String password,
  ) async {
    try {
      final url = '$API_BASE_URL$LOGIN_ENDPOINT';
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final body = jsonEncode({'username': username, 'password': password});

      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        String? userName =
            jsonResponse['user']?['name'] ?? jsonResponse['name'];
        String? userId = jsonResponse['user']?['id'];
        String? siswaId =
            jsonResponse['user']?['siswaId'] ?? jsonResponse['siswaId'];

        return {
          'success': true,
          'message': 'Login successful',
          'data': jsonResponse,
          'token': jsonResponse['token'] ?? null,
          'userName': userName,
          'userId': userId,
          'siswaId': siswaId,
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Invalid username or password'};
      } else if (response.statusCode == 422) {
        final jsonResponse = jsonDecode(response.body);

        return {
          'success': false,
          'message': jsonResponse['message'] ?? 'Validation error',
        };
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

class SessionManager {
  static bool isLoggedIn = false;
  static String? currentUsername;
  static String? currentUserName; // Full name of the user
  static String? userId; // Store user ID from API
  static String? authToken; // Store the auth token from API
  static String? siswaId; // Store siswa ID from API

  // SharedPreferences keys
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _usernameKey = 'username';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  static const String _authTokenKey = 'auth_token';
  static const String _siswaIdKey = 'siswa_id';

  // Save session to local storage
  static Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, isLoggedIn);
    if (currentUsername != null) {
      await prefs.setString(_usernameKey, currentUsername!);
    }
    if (currentUserName != null) {
      await prefs.setString(_userNameKey, currentUserName!);
    }
    if (userId != null) {
      await prefs.setString(_userIdKey, userId!);
    }
    if (authToken != null) {
      await prefs.setString(_authTokenKey, authToken!);
    }
    if (siswaId != null) {
      await prefs.setString(_siswaIdKey, siswaId!);
    }
  }

  // Load session from local storage
  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    currentUsername = prefs.getString(_usernameKey);
    currentUserName = prefs.getString(_userNameKey);
    userId = prefs.getString(_userIdKey);
    authToken = prefs.getString(_authTokenKey);
    siswaId = prefs.getString(_siswaIdKey);
  }

  // Clear session from local storage
  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_siswaIdKey);
  }

  static void login(
    String username, {
    String? token,
    String? userName,
    String? id,
    String? siswaIdValue,
  }) {
    isLoggedIn = true;
    currentUsername = username;
    currentUserName = userName;
    userId = id;
    authToken = token;
    siswaId = siswaIdValue;
    _saveSession(); // Save to local storage
  }

  static void logout() {
    isLoggedIn = false;
    currentUsername = null;
    currentUserName = null;
    userId = null;
    authToken = null;
    siswaId = null;
    _clearSession(); // Clear from local storage
  }
}

// Helper function to format date to Indonesian format
String formatDateIndonesian(DateTime date) {
  const List<String> monthsIndonesian = [
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

  return '${date.day} ${monthsIndonesian[date.month - 1]} ${date.year}';
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skanida Student',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const MyHomePage(title: 'Skanida Student'),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _fetchPesanHarian();
  }

  void _showPesanHarianDialog(String pesan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.campaign, color: Colors.amber.shade800, size: 28),
            const SizedBox(width: 10),
            const Text('Pesan Hari Ini'),
          ],
        ),
        content: Text(pesan, style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchPesanHarian() async {
    try {
      final headers = {
        'Accept': 'application/json',
        if (SessionManager.authToken != null)
          'Authorization': 'Bearer ${SessionManager.authToken}',
      };
      final response = await http
          .get(Uri.parse('$API_BASE_URL/pesan-harian'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final pesan =
            json['pesan'] ?? json['message'] ?? json['data']?.toString();
        if (pesan != null && pesan.toString().isNotEmpty && mounted) {
          _showPesanHarianDialog(pesan.toString());
        }
      }
    } catch (e) {
      // silently ignore
    }
  }

  Widget _buildIconCard(IconData icon, String label, {VoidCallback? onTap}) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (onTap == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: child,
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Colors.deepPurple.shade900,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              SessionManager.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.deepPurple.shade900,
                  Colors.deepPurple.shade500,
                  Colors.purple.shade400,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, ${SessionManager.currentUserName ?? 'User'}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hari ini: ${formatDateIndonesian(DateTime.now())}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          // Icons Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildIconCard(
                  Icons.account_circle,
                  'Data Siswa',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SiswaDetailPage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.map,
                  'Presensi',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PresensiPage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.mail,
                  'Izin Presensi',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const IjinOnlinePage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.list,
                  'Daftar Izin',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DaftarIjinPage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.exit_to_app,
                  'Izin Meninggalkan Kelas',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const KeluarKelasPage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.history,
                  'Riwayat Izin',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const RiwayatIzinPage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.mosque,
                  'Presensi Sholat',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PresensiSholatPage(),
                      ),
                    );
                  },
                ),
                _buildIconCard(
                  Icons.event_note,
                  'Izin Sholat',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const IjinSholatPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
