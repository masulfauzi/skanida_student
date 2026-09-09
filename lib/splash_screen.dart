import 'package:flutter/material.dart';
import 'main.dart'; // To access SessionManager and other widgets
import 'login_page.dart';
import 'presensi_draft.dart';
import 'resume_presensi_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initTrackingThenNavigate();
    });
  }

  Future<void> _initTrackingThenNavigate() async {
    // Mobile Ads SDK is initialized lazily by AdsHelper right before the
    // first ad is actually loaded (see ads_helper.dart), not here on every
    // launch — this keeps memory usage lower right when the app may be
    // restarting after Android killed its process (e.g. returning from the
    // camera), which is exactly when extra memory pressure hurts most.
    await _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Load saved session first
    await SessionManager.loadSession();

    // Check for a presensi selfie that never made it to the server because
    // Android killed the app process (e.g. while the native camera app was
    // in the foreground). If one exists, resume it instead of silently
    // dropping the user on the dashboard.
    final draft = SessionManager.isLoggedIn ? await PresensiDraft.read() : null;

    await Future.delayed(const Duration(seconds: 2), () {});
    if (mounted) {
      final Widget destination;
      if (!SessionManager.isLoggedIn) {
        destination = const LoginPage();
      } else if (draft != null) {
        destination = ResumePresensiPage(
          photoPath: draft['path']!,
          siswaId: draft['siswaId']!,
        );
      } else {
        destination = const MyHomePage(title: 'Skanida Student');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (BuildContext context) => destination),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/skanida.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 30),
            // App title
            const Text(
              'Skanida',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              'Welcome',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 50),
            // Loading indicator
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.8),
                ),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
