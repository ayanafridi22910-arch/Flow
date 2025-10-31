import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flow/blocker_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isTotalBlockActive = false;

  @override
  void initState() {
    super.initState();
    _loadTotalBlockState();
  }

  void _loadTotalBlockState() {
    final blockerBox = Hive.box('blockerState');
    setState(() {
      _isTotalBlockActive = blockerBox.get('is_total_block_active') ?? false;
    });
  }

  Future<void> _toggleTotalBlock(bool isActive) async {
    if (isActive) {
      await _activateTotalBlock();
    } else {
      await _deactivateTotalBlock();
    }
  }

  Future<void> _activateTotalBlock() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Activate Total Block?'),
        content: const Text('This will block ALL non-system applications on your phone. You will only be able to use system apps like the phone dialer and settings. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
      
      const String thisAppPackageName = 'com.example.flow';
      
      final List<String> allAppsToBlock = apps
          .map((app) => app.packageName)
          .where((name) => name != thisAppPackageName)
          .toList();

      final blockerBox = Hive.box('blockerState');
      await blockerBox.put('total_block_apps', allAppsToBlock);
      await blockerBox.put('is_total_block_active', true);
      await BlockerService.updateNativeBlocker();
      setState(() {
        _isTotalBlockActive = true;
      });
    }
  }

  Future<void> _deactivateTotalBlock() async {
    final blockerBox = Hive.box('blockerState');
    await blockerBox.delete('total_block_apps');
    await blockerBox.put('is_total_block_active', false);
    await BlockerService.updateNativeBlocker();
    setState(() {
      _isTotalBlockActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00020C),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildTotalBlockCard(),
          // Other settings can be added here
        ],
      ),
    );
  }

  Widget _buildTotalBlockCard() {
    return Card(
      color: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Block Mode',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Blocks all non-essential apps on your device. Use this for maximum focus when you cannot be distracted.',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isTotalBlockActive ? 'ACTIVE' : 'INACTIVE',
                  style: GoogleFonts.poppins(
                    color: _isTotalBlockActive ? Colors.redAccent : Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Switch(
                  value: _isTotalBlockActive,
                  onChanged: _toggleTotalBlock,
                  activeColor: Colors.redAccent,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
