// This file acts as a bridge between the Flutter UI and the native Android code.
// It centralizes all MethodChannel communication and permission handling logic.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NativeBlocker {
  // The MethodChannel used to communicate with the native platform.
  static const MethodChannel _channel = MethodChannel('app.blocker/channel');

  // Sends the list of blocked application package names to the native Android side.
  static Future<void> setBlockedApps(List<String> apps) async {
    try {
      await _channel.invokeMethod('setBlockedApps', {'apps': apps});
    } on PlatformException catch (e) {
      // Handle potential errors, e.g., by logging them.
      debugPrint("Failed to set blocked apps: '${e.message}'.");
    }
  }

  // --- Permission Handling ---

  // Checks if the overlay permission is granted.
  static Future<bool> isOverlayPermissionGranted() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  // Requests the SYSTEM_ALERT_WINDOW (overlay) permission.
  static Future<PermissionStatus> requestOverlayPermission() async {
    return await Permission.systemAlertWindow.request();
  }

  // Opens the accessibility settings page for the user to manually enable the service.
  static Future<void> openAccessibilitySettings() async {
    try {
        await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
        debugPrint("Failed to open accessibility settings: '${e.message}'.");
    }
  }
  
  // A helper to open the app's settings page in the system settings.
  static Future<void> openSystemAppSettings() async {
    await openAppSettings();
  }
}