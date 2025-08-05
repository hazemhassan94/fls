import 'dart:async';
import 'package:flutter/material.dart';
import 'package:school_fls/login_page/auto_login_page.dart'; 

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AutoLoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF1E2B86);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top curved shape
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: themeBlue,
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(200),
                ),
              ),
            ),
          ),

          // Bottom curved shape
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade300,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(200),
                ),
              ),
            ),
          ),

          // Main content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // School logo
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 20),

              // WELCOME text
              Text(
                'WELCOME',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: themeBlue,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 20),

              // Loading circle
              CircularProgressIndicator(
                color: themeBlue,
                strokeWidth: 3,
              ),

              const Spacer(flex: 3),
            ],
          ),
        ],
      ),
    );
  }
}
