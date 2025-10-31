import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NativeBlocker {
  // The MethodChannel used to communicate with the native platform.
  static const MethodChannel _channel = MethodChannel('app.blocker/channel');

  // Sends the list of blocked application package names to the native Android side.
  static Future<void> setBlockedApps(List<String> apps) async {
    try {
      debugPrint("NativeBlocker: Invoking 'setBlockedApps' with apps: $apps");
      await _channel.invokeMethod('setBlockedApps', {'apps': apps});
      debugPrint("NativeBlocker: 'setBlockedApps' invoked successfully.");
    } on PlatformException catch (e) {
      debugPrint("NativeBlocker: Failed to set blocked apps: '${e.message}'.");
    }
  }

  // --- Permission Handling ---

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool? isEnabled = await _channel.invokeMethod('checkAccessibilityServiceEnabled');
      debugPrint("NativeBlocker: isAccessibilityServiceEnabled: ${isEnabled ?? false}");
      return isEnabled ?? false;
    } on PlatformException catch (e) {
      debugPrint("NativeBlocker: Failed to check accessibility service: ${e.message}");
      return false;
    }
  }

  // Checks if the overlay permission is granted.
  static Future<bool> isOverlayPermissionGranted() async {
    try {
      final bool? isGranted = await _channel.invokeMethod('isOverlayPermissionGranted');
      debugPrint("NativeBlocker: isOverlayPermissionGranted: ${isGranted ?? false}");
      return isGranted ?? false;
    } on PlatformException catch (e) {
      debugPrint("NativeBlocker: Failed to check overlay permission: ${e.message}");
      return false;
    }
  }

  // Requests the SYSTEM_ALERT_WINDOW (overlay) permission.
  static Future<void> requestOverlayPermission() async {
    try {
      debugPrint("NativeBlocker: Invoking 'requestOverlayPermission'");
      await _channel.invokeMethod('requestOverlayPermission');
      debugPrint("NativeBlocker: 'requestOverlayPermission' invoked successfully.");
    } on PlatformException catch (e) {
      debugPrint("NativeBlocker: Failed to request overlay permission: ${e.message}");
    }
  }

  // Opens the accessibility settings page for the user to manually enable the service.
  static Future<void> openAccessibilitySettings() async {
    try {
        debugPrint("NativeBlocker: Invoking 'openAccessibilitySettings'");
        await _channel.invokeMethod('openAccessibilitySettings');
        debugPrint("NativeBlocker: 'openAccessibilitySettings' invoked successfully.");
    } on PlatformException catch (e) {
        debugPrint("NativeBlocker: Failed to open accessibility settings: '${e.message}'.");
    }
  }
  
  // A helper to open the app's settings page in the system settings.
  static Future<void> openSystemAppSettings() async {
    debugPrint("NativeBlocker: Opening system app settings.");
    await openAppSettings();
  }
}