import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'package:isar/isar.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.helloworld.autoflow/automation');
  
  bool _isAccessibilityGranted = false;
  bool _isOverlayGranted = false;
  bool _isContactsGranted = false;
  bool _isBatteryIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    _isAccessibilityGranted = await platform.invokeMethod('checkAccessibilityPermission');
    _isOverlayGranted = await Permission.systemAlertWindow.isGranted;
    _isContactsGranted = await Permission.contacts.isGranted;
    _isBatteryIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
    setState(() {});
  }

  void _requestAccessibility() async {
    await platform.invokeMethod('requestAccessibilityPermission');
  }

  void _requestOverlay() async {
    await Permission.systemAlertWindow.request();
    _checkAllPermissions();
  }

  void _requestContacts() async {
    await Permission.contacts.request();
    _checkAllPermissions();
  }

  void _requestBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
    _checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    bool allGranted = _isAccessibilityGranted && _isOverlayGranted && _isContactsGranted && _isBatteryIgnored;

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to AutoFlow',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'To automate your device hands-free, we need a few special permissions.',
                style: TextStyle(fontSize: 16, color: AppTheme.textLight),
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildPermissionItem(
                      icon: Icons.accessibility_new,
                      title: 'Accessibility Service',
                      description: 'Required to mimic clicks and send messages on WhatsApp.',
                      isGranted: _isAccessibilityGranted,
                      onTap: _requestAccessibility,
                    ),
                    _buildPermissionItem(
                      icon: Icons.contacts,
                      title: 'Contacts Access',
                      description: 'Required to pick a recipient for your automations.',
                      isGranted: _isContactsGranted,
                      onTap: _requestContacts,
                    ),
                    _buildPermissionItem(
                      icon: Icons.layers,
                      title: 'Draw Over Other Apps',
                      description: 'Required to show the countdown cancellation screen.',
                      isGranted: _isOverlayGranted,
                      onTap: _requestOverlay,
                    ),
                    _buildPermissionItem(
                      icon: Icons.battery_charging_full,
                      title: 'Ignore Battery Optimizations',
                      description: 'Ensures background tasks run exactly on time without Android killing them.',
                      isGranted: _isBatteryIgnored,
                      onTap: _requestBattery,
                    ),
                  ],
                ),
              ),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: allGranted ? () {
                    widget.onFinished();
                  } : () {
                    _checkAllPermissions();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allGranted ? AppTheme.primaryBlue : Colors.grey,
                  ),
                  child: Text(allGranted ? 'Continue' : 'Refresh Status'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: AppTheme.primaryBlue, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(description),
        ),
        trailing: isGranted 
            ? const Icon(Icons.check_circle, color: AppTheme.accentGreen) 
            : ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  foregroundColor: AppTheme.primaryBlue,
                  elevation: 0,
                ),
                child: const Text('ENABLE'),
              ),
      ),
    );
  }
}
