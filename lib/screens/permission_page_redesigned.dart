import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:flow/screens/first_page.dart';
import 'package:flow/screens/home_page.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PermissionPageRedesigned extends StatefulWidget {
  const PermissionPageRedesigned({super.key});

  @override
  State<PermissionPageRedesigned> createState() => _PermissionPageRedesignedState();
}

class _PermissionPageRedesignedState extends State<PermissionPageRedesigned> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('app.blocker/channel');

  bool _notificationPermission = false;
  bool _overlayPermission = false;
  bool _accessibilityPermission = false;
  bool _batteryOptimizationPermission = false; // New state variable
  bool _isCheckingPermissions = false;

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
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isCheckingPermissions) {
      _checkAllPermissions();
    }
  }

  Future<bool> _checkAccessibilityServiceEnabled() async {
    try {
      final bool? isEnabled = await _channel.invokeMethod('checkAccessibilityServiceEnabled');
      return isEnabled ?? false;
    } on PlatformException catch (e) {
      debugPrint("Failed to check accessibility service status: ${e.message}");
      return false;
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() {
      _isCheckingPermissions = true;
    });

    final allPermissions = await Future.wait([
      Permission.notification.status,
      Permission.systemAlertWindow.status,
      _channel.invokeMethod('checkAccessibilityServiceEnabled').catchError((_) => false),
      Permission.ignoreBatteryOptimizations.status, // New permission check
    ]);

    final notificationStatus = allPermissions[0] as PermissionStatus;
    final overlayStatus = allPermissions[1] as PermissionStatus;
    final accessibilityServiceEnabled = allPermissions[2] as bool;
    final batteryStatus = allPermissions[3] as PermissionStatus; // New status

    setState(() {
      _notificationPermission = notificationStatus.isGranted;
      _overlayPermission = overlayStatus.isGranted;
      _accessibilityPermission = accessibilityServiceEnabled;
      _batteryOptimizationPermission = batteryStatus.isGranted; // Update state
      _isCheckingPermissions = false;
    });

    _navigateToFirstPageIfAllGranted();
  }

  void _navigateToFirstPageIfAllGranted() {
    if (_notificationPermission &&
        _overlayPermission &&
        _accessibilityPermission &&
        _batteryOptimizationPermission) { // Updated condition
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const FirstPage()),
        );
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
    _checkAllPermissions();
  }

  Future<void> _requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
    _checkAllPermissions();
  }

  Future<void> _openSystemAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint("Failed to open accessibility settings: ${e.message}");
    }
  }

  Future<void> _requestAccessibilityPermission() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Accessibility Service'),
        content: const Text('You will be taken to system accessibility settings. Please follow these steps:\n\n1. Find and tap on "Flow".\n2. Turn the service on.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSystemAccessibilitySettings();
            },
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  // New request function
  Future<void> _requestBatteryOptimizationPermission() async {
    await Permission.ignoreBatteryOptimizations.request();
    _checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Permissions Required',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To ensure Flow works correctly, please grant the following permissions:',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            _buildPermissionTile(
              context: context,
              title: 'Notification Access',
              subtitle: 'Allows Flow to show important alerts and notifications.',
              isGranted: _notificationPermission,
              onTap: _requestNotificationPermission,
              icon: Icons.notifications_active,
            ),
            _buildPermissionTile(
              context: context,
              title: 'Draw Over Other Apps',
              subtitle: 'Essential for displaying the blocking screen over other applications.',
              isGranted: _overlayPermission,
              onTap: _requestOverlayPermission,
              icon: Icons.picture_in_picture_alt,
            ),
            _buildPermissionTile(
              context: context,
              title: 'Accessibility Service',
              subtitle: 'Crucial for detecting which app is currently running and blocking it.',
              isGranted: _accessibilityPermission,
              onTap: _requestAccessibilityPermission,
              icon: Icons.accessibility_new,
            ),
            // New UI tile
            _buildPermissionTile(
              context: context,
              title: 'Ignore Battery Optimizations',
              subtitle: 'Needed for the background service to run reliably and track usage correctly.',
              isGranted: _batteryOptimizationPermission,
              onTap: _requestBatteryOptimizationPermission,
              icon: Icons.battery_charging_full,
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: _isCheckingPermissions ? null : _checkAllPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 10,
                ),
                child: _isCheckingPermissions
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Recheck Permissions',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildPermissionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Opacity(
      opacity: isGranted ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        color: isGranted ? Colors.green.shade800.withOpacity(0.3) : Colors.grey[800],
        elevation: isGranted ? 0 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: isGranted ? Colors.greenAccent : Colors.white70, size: 30),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: isGranted ? Colors.greenAccent : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: isGranted ? Colors.greenAccent.withOpacity(0.7) : Colors.white54,
            ),
          ),
          trailing: isGranted
              ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 30)
              : const Icon(Icons.chevron_right, color: Colors.white54),
          onTap: isGranted ? null : onTap,
        ),
      ),
    );
  }
}