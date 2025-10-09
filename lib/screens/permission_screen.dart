
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flow/screens/home_page.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  bool _notificationPermission = false;
  bool _overlayPermission = false;
  bool _accessibilityPermission = false;
  bool _isCheckingPermissions = false;
  bool _navigatedToSettingsForAccessibility = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check when the screen loads
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // This is the key method that triggers when the app's state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When the user returns to the app, re-check the permissions
    if (state == AppLifecycleState.resumed && !_isCheckingPermissions) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() {
      _isCheckingPermissions = true;
    });

    // Check for standard permissions
    final notificationStatus = await Permission.notification.status;
    final overlayStatus = await Permission.systemAlertWindow.status;

    // For accessibility, we can't check directly.
    // We assume if the user was sent to settings and came back, they enabled it.
    if (_navigatedToSettingsForAccessibility) {
      // This is an assumption, as we cannot truly verify it without native code.
      _accessibilityPermission = true;
      _navigatedToSettingsForAccessibility = false; // Reset flag
    }

    setState(() {
      _notificationPermission = notificationStatus.isGranted;
      _overlayPermission = overlayStatus.isGranted;
      _isCheckingPermissions = false;
    });

    // If all permissions are now granted, navigate to the home page
    _navigateToHomeIfAllGranted();
  }

  void _navigateToHomeIfAllGranted() {
    if (_notificationPermission && _overlayPermission && _accessibilityPermission) {
      // Use a post-frame callback to avoid navigation during a build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
    _checkAllPermissions();
  }

  Future<void> _requestOverlayPermission() async {
    await Permission.systemAlertWindow.request();
    _checkAllPermissions();
  }

  Future<void> _requestAccessibilityPermission() async {
    // Set a flag before navigating to settings
    _navigatedToSettingsForAccessibility = true;

    // Show a dialog explaining the steps before opening settings
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Accessibility Service'),
        content: const Text('You will be taken to app settings. Please follow these steps:\n\n1. Tap on "Installed apps" or "Downloaded services".\n2. Find and tap on "Flow".\n3. Turn the service on.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Now, open the app settings
              openAppSettings();
            },
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
    // After returning from settings, didChangeAppLifecycleState will handle the check
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/app-logo.png',
                height: 100,
                width: 100,
              ),
              const SizedBox(height: 16),
              const Text(
                'Flow',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              _buildPermissionTile(
                title: 'Notification Permission',
                subtitle: 'Required to show notifications about app usage and blocked apps.',
                isGranted: _notificationPermission,
                onTap: _requestNotificationPermission,
              ),
              _buildPermissionTile(
                title: 'Draw Over Other Apps',
                subtitle: 'Required to show the blocking screen over other applications.',
                isGranted: _overlayPermission,
                onTap: _requestOverlayPermission,
              ),
              _buildPermissionTile(
                title: 'Accessibility Permission',
                subtitle: 'Required to detect which app is currently running and block it if necessary.',
                isGranted: _accessibilityPermission,
                onTap: _requestAccessibilityPermission,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: isGranted ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: isGranted
              ? const Icon(Icons.check_circle, color: Colors.green, size: 30)
              : const Icon(Icons.chevron_right),
          onTap: isGranted ? null : onTap,
        ),
      ),
    );
  }
}
