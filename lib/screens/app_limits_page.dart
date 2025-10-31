import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flow/screens/app_limit_page.dart';
import 'package:flow/blocker_service.dart';

class AppLimitsPage extends StatefulWidget {
  const AppLimitsPage({super.key});

  @override
  State<AppLimitsPage> createState() => _AppLimitsPageState();
}

class _AppLimitsPageState extends State<AppLimitsPage> {
  Map<String, Map<String, dynamic>> _appLimits = {};
  Set<String> _permanentlyBlockedApps = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    await _loadAppLimits();
    await _loadPermanentlyBlockedApps();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // We just need to rebuild to update the countdown text
      setState(() {});
    });
  }

  Future<void> _loadAppLimits() async {
    final limitsBox = Hive.box('appLimits');
    if (mounted) {
      setState(() {
        _appLimits = limitsBox.toMap().map((key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value)));
      });
    }
  }

  Future<void> _loadPermanentlyBlockedApps() async {
    final blockerBox = Hive.box('blockerState');
    if (mounted) {
      setState(() {
        _permanentlyBlockedApps = (blockerBox.get('permanently_blocked_apps') as List?)?.cast<String>().toSet() ?? {};
      });
    }
  }

  Future<void> _navigateToAddAppLimit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppLimitPage()), // Navigates to the page for selecting apps
    );

    if (result != null && result is Map<String, dynamic>) {
      final List<String> apps = result['apps'];
      final Duration duration = result['duration'];
      final endTime = DateTime.now().add(duration);

      final limitsBox = Hive.box('appLimits');
      for (String packageName in apps) {
        final app = await DeviceApps.getApp(packageName, true);
        final limitData = {
          'endTime': endTime.millisecondsSinceEpoch,
          'totalDuration': duration.inSeconds,
          'appName': app?.appName ?? 'Unknown App',
          'icon': app is ApplicationWithIcon ? app.icon : null,
        };
        await limitsBox.put(packageName, limitData);
      }
      _loadAppLimits();
    }
  }

  Future<void> _removeAppLimit(String packageName) async {
    final limitsBox = Hive.box('appLimits');
    await limitsBox.delete(packageName);
    _loadAppLimits();
  }

  Future<void> _removePermanentBlock(String packageName) async {
    setState(() {
      _permanentlyBlockedApps.remove(packageName);
    });
    final blockerBox = Hive.box('blockerState');
    await blockerBox.put('permanently_blocked_apps', _permanentlyBlockedApps.toList());
    await BlockerService.updateNativeBlocker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00020C),
      appBar: AppBar(
        title: Text('App Limits', style: GoogleFonts.poppins()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildAppLimitSection(),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddAppLimit,
        backgroundColor: Colors.blueAccent.shade400,
        child: const Icon(Icons.add_alarm, color: Colors.white),
      ),
    );
  }

  Widget _buildAppLimitSection() {
    final allLimitedApps = {..._appLimits.keys, ..._permanentlyBlockedApps};

    if (allLimitedApps.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No active app limits. Tap the + button to set a timer for an app.',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allLimitedApps.length,
      itemBuilder: (context, index) {
        final packageName = allLimitedApps.elementAt(index);
        final limitData = _appLimits[packageName];
        final isPermanentlyBlocked = _permanentlyBlockedApps.contains(packageName);

        if (isPermanentlyBlocked) {
          return FutureBuilder<Application?>(
            future: DeviceApps.getApp(packageName, true),
            builder: (context, snapshot) {
              return _buildAppLimitCard(packageName, snapshot.data, null, true);
            },
          );
        } else {
          return _buildAppLimitCard(packageName, null, limitData, false);
        }
      },
    );
  }

  Widget _buildAppLimitCard(String packageName, Application? appData, Map<String, dynamic>? limitData, bool isBlocked) {
    final String appName = appData?.appName ?? limitData?['appName'] ?? 'Loading...';
    final Uint8List? icon = appData is ApplicationWithIcon ? appData.icon : limitData?['icon'];

    Duration remaining = Duration.zero;
    if (!isBlocked && limitData != null) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(limitData['endTime']);
      remaining = endTime.difference(DateTime.now());
      if (remaining.isNegative) remaining = Duration.zero;
    }

    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            if (icon != null) Image.memory(icon, width: 40, height: 40) else const Icon(Icons.apps, size: 40, color: Colors.white54),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  isBlocked
                      ? Text('Limit Reached', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 14))
                      : Text('${remaining.inMinutes}m ${remaining.inSeconds.remainder(60)}s remaining', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(isBlocked ? Icons.lock_open : Icons.cancel_outlined, color: isBlocked ? Colors.greenAccent : Colors.redAccent),
              onPressed: () {
                if (isBlocked) {
                  _removePermanentBlock(packageName);
                } else {
                  _removeAppLimit(packageName);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
