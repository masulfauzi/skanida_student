import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart'; // To access AuthService and SessionManager

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.loginWithAPI(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (result['success']) {
      // Login successful, save session
      SessionManager.login(
        _usernameController.text,
        token: result['token'],
        userName: result['userName'],
        id: result['userId'],
        siswaIdValue: result['siswaId'],
      );

      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/skanida.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 30),
                // Title
                const Text(
                  'Skanida',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Student Portal',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                // Username TextField
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.person, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Password TextField
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.lock, color: Colors.white70),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.deepPurple,
                              ),
                            ),
                          )
                        : Text(
                            'Login',
                            style: TextStyle(
                              color: Colors.deepPurple.shade900,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Forgot Password
                GestureDetector(
                  onTap: () {
                    launchUrl(
                      Uri.parse('https://apps.smkn2semarang.sch.id/forgot-password'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: 'Lupa password? ',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Klik disini',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
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
