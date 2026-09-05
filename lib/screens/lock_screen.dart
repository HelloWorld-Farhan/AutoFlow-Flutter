import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

class LockScreen extends StatefulWidget {
  final Widget child;
  const LockScreen({super.key, required this.child});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
      });
      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access AutoFlow',
        biometricOnly: false,
      );
      setState(() {
        _isAuthenticating = false;
      });
    } on PlatformException catch (e) {
      print("Auth error: \$e");
      setState(() {
        _isAuthenticating = false;
      });
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      // Check if it's first launch to show onboarding
      final prefs = await SharedPreferences.getInstance();
      bool hasOnboarded = prefs.getBool('has_onboarded') ?? false;

      if (!hasOnboarded) {
        prefs.setBool('has_onboarded', true);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(onFinished: () {
              Navigator.pop(context);
              setState(() {
                _isAuthenticated = true;
              });
            }),
          ),
        );
      } else {
        setState(() {
          _isAuthenticated = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'App Locked',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            if (_isAuthenticating)
              const CircularProgressIndicator(color: Colors.white)
            else
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, color: AppTheme.primaryBlue),
                label: const Text(
                  'Unlock AutoFlow',
                  style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
