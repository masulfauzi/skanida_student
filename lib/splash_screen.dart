import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'main.dart'; // To access SessionManager and other widgets
import 'login_page.dart';

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
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('MobileAds init error: $e');
    }

    await _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // Load saved session first
    await SessionManager.loadSession();
    await Future.delayed(const Duration(seconds: 2), () {});
    if (mounted) {
      final destination = SessionManager.isLoggedIn
          ? const MyHomePage(title: 'Skanida Student')
          : const LoginPage();
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
