import 'dart:async';
import 'dart:math';
import 'package:flow/blocker_service.dart';
import 'package:flow/screens/schedule_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flow/screens/home_page.dart';
import 'package:flow/native_blocker.dart';
import 'package:flow/screens/permission_page_redesigned.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_apps/device_apps.dart';

// --- Custom Widgets for Zen Focus Theme ---

class DynamicZenBackground extends StatefulWidget {
  final bool isFocusActive;
  const DynamicZenBackground({Key? key, this.isFocusActive = false}) : super(key: key);

  @override
  State<DynamicZenBackground> createState() => _DynamicZenBackgroundState();
}

class _DynamicZenBackgroundState extends State<DynamicZenBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isFocusActive
                  ? [
                      const Color(0xFF000820),
                      const Color(0xFF001C40),
                    ]
                  : [
                      const Color(0xFF00020C),
                      const Color(0xFF000820),
                    ],
              stops: const [0.0, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class FocusOrb extends StatelessWidget {
  final Duration countdownDuration;
  final Duration totalDuration;
  final bool isActive;
  final double size;

  const FocusOrb({
    Key? key,
    required this.countdownDuration,
    required this.totalDuration,
    this.isActive = false,
    this.size = 200,
  }) : super(key: key);

  String _formatOrbDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (d.inDays > 0) return '${d.inDays}D : ${twoDigits(d.inHours.remainder(24))}H';
    if (d.inHours > 0) return '${twoDigits(d.inHours)}H : ${twoDigits(d.inMinutes.remainder(60))}M';
    return '${twoDigits(d.inMinutes.remainder(60))}M : ${twoDigits(d.inSeconds.remainder(60))}S';
  }

  @override
  Widget build(BuildContext context) {
    double progress = totalDuration.inSeconds > 0
        ? countdownDuration.inSeconds / totalDuration.inSeconds
        : 1.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            isActive ? Colors.blue.shade300.withOpacity(0.8) : Colors.grey.shade600.withOpacity(0.6),
            isActive ? Colors.deepPurple.shade700.withOpacity(0.8) : Colors.grey.shade900.withOpacity(0.8),
          ],
          stops: [0.0, 1.0 - progress],
        ),
        boxShadow: [
          BoxShadow(
            color: isActive ? Colors.blue.withOpacity(0.4) : Colors.transparent,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatOrbDuration(countdownDuration),
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontSize: size * 0.20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Focusing...',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: size * 0.12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const MethodChannel _channel = MethodChannel('app.blocker/channel');

  Timer? _mainTimer;
  bool _isInitialized = false;

  // For main focus session
  Duration _focusCountdown = Duration.zero;
  bool _isFocusActive = false;
  Set<String> _focusSessionApps = {};
  Duration _currentFocusSessionTotalDuration = Duration.zero;
  List<Widget> _focusSessionAppIconWidgets = [];

  // For Focus Schedules
  Map<String, Map<String, dynamic>> _focusSchedules = {};

  // For UI behavior
  final ScrollController _scrollController = ScrollController();
  int _streakCount = 0;
  Duration _totalFocusDuration = Duration.zero;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  Future<void> _initializeAll() async {
    await Hive.openBox('blockerState');
    await Hive.openBox('focusProfiles'); // New box for profiles
    await _checkAllCorePermissions();

    if (mounted) {
      await _loadFocusState();
      await _loadFocusSchedules();
      setState(() {
        _isInitialized = true;
      });

      _startMainTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainTimer?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _initializeAll();
    }
  }

  void _startMainTimer() {
    _mainTimer?.cancel();
    _mainTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isFocusActive) {
        if (_focusCountdown.inSeconds <= 0) {
          _stopFocusSession();
        } else {
          setState(() {
            _focusCountdown = _focusCountdown - const Duration(seconds: 1);
          });
        }
      }
    });
  }

  Future<void> _checkAllCorePermissions() async {
    final allPermissions = await Future.wait([
      Permission.notification.status,
      Permission.systemAlertWindow.status,
      _channel.invokeMethod('checkAccessibilityServiceEnabled').catchError((_) => false),
    ]);

    final notificationStatus = allPermissions[0] as PermissionStatus;
    final overlayStatus = allPermissions[1] as PermissionStatus;
    final accessibilityServiceEnabled = allPermissions[2] as bool;

    if (!notificationStatus.isGranted || !overlayStatus.isGranted || !accessibilityServiceEnabled) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PermissionPageRedesigned()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> _loadFocusState() async {
    final blockerBox = Hive.box('blockerState');
    final savedIsBlockingActive = blockerBox.get('is_blocking_active') ?? false;
    final savedEndTimeMillis = blockerBox.get('blocker_end_time_millis');

    if (savedIsBlockingActive && savedEndTimeMillis != null) {
      final savedEndTime = DateTime.fromMillisecondsSinceEpoch(savedEndTimeMillis);
      final remainingDuration = savedEndTime.difference(DateTime.now());

      if (remainingDuration.isNegative) {
        _stopFocusSession();
      } else {
        final savedBlockedApps = blockerBox.get('selected_blocked_apps');
        final savedTotalDurationSeconds = blockerBox.get('current_session_total_duration_seconds');
        if (mounted) {
          setState(() {
            _focusCountdown = remainingDuration;
            _isFocusActive = true;
            _focusSessionApps = (savedBlockedApps as List?)?.cast<String>().toSet() ?? {};
            if (savedTotalDurationSeconds != null) {
              _currentFocusSessionTotalDuration = Duration(seconds: savedTotalDurationSeconds);
            }
            if (_focusSessionApps.isNotEmpty) {
              _loadFocusSessionAppIcons(_focusSessionApps.toList());
            }
          });
        }
        BlockerService.updateNativeBlocker();
      }
    }
  }

  Future<void> _loadFocusSchedules() async {
    final profilesBox = Hive.box('focusProfiles');
    final blockerBox = Hive.box('blockerState');
    final bool defaultSchedulesCreated = blockerBox.get('default_schedules_created') ?? false;

    if (!defaultSchedulesCreated && profilesBox.isEmpty) {
      // Create default profiles
      await profilesBox.put('work', {
        'name': 'School/Work',
        'icon': 'work',
        'startTime': '09:00',
        'endTime': '17:00',
        'days': [true, true, true, true, true, false, false], // Mon-Fri
        'apps': <String>['com.google.android.gm', 'com.google.android.apps.messaging'],
        'isEnabled': false,
      });
      await profilesBox.put('study', {
        'name': 'Study Focus',
        'icon': 'book',
        'startTime': '19:00',
        'endTime': '21:00',
        'days': [true, true, true, true, true, false, false],
        'apps': <String>['com.instagram.android', 'com.facebook.katana'],
        'isEnabled': false,
      });
      await profilesBox.put('free', {
        'name': 'Distraction Free',
        'icon': 'self_improvement',
        'startTime': '22:00',
        'endTime': '07:00',
        'days': List.filled(7, true),
        'apps': <String>['com.instagram.android', 'com.google.android.youtube', 'com.netflix.mediaclient'],
        'isEnabled': false,
      });
      await blockerBox.put('default_schedules_created', true);
    }

    if (mounted) {
      setState(() {
        _focusSchedules = profilesBox.toMap().map((key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value)));
      });
    }
  }

  Future<void> _loadFocusSessionAppIcons(List<String> packageNames) async {
    List<Widget> iconWidgets = [];
    for (String packageName in packageNames) {
      try {
        final app = await DeviceApps.getApp(packageName, true);
        if (app != null && app is ApplicationWithIcon) {
          iconWidgets.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Image.memory(app.icon, width: 32, height: 32),
          ));
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _focusSessionAppIconWidgets = iconWidgets;
      });
    }
  }

  Future<void> _startFocusSession(List<String> appsToBlock, Duration duration) async {
    if (appsToBlock.isEmpty || duration.inSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select apps and a valid duration.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final blockerBox = Hive.box('blockerState');
    final endTime = DateTime.now().add(duration);
    await blockerBox.put('is_blocking_active', true);
    await blockerBox.put('blocker_end_time_millis', endTime.millisecondsSinceEpoch);
    await blockerBox.put('selected_blocked_apps', appsToBlock.toList());
    await blockerBox.put('current_session_total_duration_seconds', duration.inSeconds);

    if (mounted) {
      setState(() {
        _isFocusActive = true;
        _focusCountdown = duration;
        _focusSessionApps = appsToBlock.toSet();
        _currentFocusSessionTotalDuration = duration;
      });
      _loadFocusSessionAppIcons(_focusSessionApps.toList());
      BlockerService.updateNativeBlocker();
    }
  }

  Future<void> _stopFocusSession() async {
    if (!_isFocusActive) return;

    final blockerBox = Hive.box('blockerState');
    await blockerBox.delete('is_blocking_active');
    await blockerBox.delete('blocker_end_time_millis');
    await blockerBox.delete('selected_blocked_apps');
    await blockerBox.delete('current_session_total_duration_seconds');

    if (mounted) {
      setState(() {
        _focusCountdown = Duration.zero;
        _isFocusActive = false;
        _currentFocusSessionTotalDuration = Duration.zero;
        _focusSessionApps = {};
        _focusSessionAppIconWidgets = [];
      });
      BlockerService.updateNativeBlocker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Flow', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          _buildAppBarMetric(Icons.local_fire_department, 'Streak: $_streakCount', Colors.orange.shade400),
          const SizedBox(width: 10),
          _buildAppBarMetric(Icons.hourglass_empty, 'Focus: ${_formatTotalFocusDuration(_totalFocusDuration)}', Colors.blue.shade400),
        ],
      ),
      body: Stack(
        children: [
          DynamicZenBackground(isFocusActive: _isFocusActive),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const CustomScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Removed SizedBox(height: 40) here as AppBar is back
                        if (_isFocusActive)
                          _buildActiveSessionDisplay()
                        else
                          _buildIdleStateDisplay(),
                        const SizedBox(height: 30), // Spacing between active/idle and profiles
                        _buildFocusSchedulesSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: BouncyButton(
        onTap: () async {
          // Navigate to add new profile
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleEditPage()));
          _loadFocusSchedules(); // Reload profiles after editing/adding
        },
        child: FloatingActionButton(
          onPressed: null, // Handled by BouncyButton
          backgroundColor: Colors.blueAccent.shade400,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildAppBarMetric(IconData icon, String text, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionDisplay() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text('Focus Mode: Active', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          FocusOrb(countdownDuration: _focusCountdown, totalDuration: _currentFocusSessionTotalDuration, isActive: true, size: 120),
          const SizedBox(height: 15),
          if (_focusSessionAppIconWidgets.isNotEmpty)
            Column(
              children: [
                Text('Blocking:', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: _focusSessionAppIconWidgets)),
              ],
            ),
          const SizedBox(height: 20),
          BouncyButton(
            onTap: _stopFocusSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent, width: 1.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.power_settings_new, size: 20, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('End Session', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleStateDisplay() {
    return Column(
      children: [
        Text('Ready to activate your Flow State?', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 20, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 30),
        BouncyButton(
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
            if (result != null && result is Map<String, dynamic>) {
              final List<String> selectedApps = List<String>.from(result['selectedApps']);
              final Duration duration = result['duration'] as Duration;
              _startFocusSession(selectedApps, duration);
            }
          },
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blueAccent.shade700,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text('Start Custom Session', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusSchedulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Focus Schedules', style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        ListView.builder(
          itemCount: _focusSchedules.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final profileId = _focusSchedules.keys.elementAt(index);
            final profileData = _focusSchedules[profileId]!;
            return _buildFocusScheduleCard(profileId, profileData);
          },
        ),
      ],
    );
  }

  Widget _buildFocusScheduleCard(String profileId, Map<String, dynamic> profileData) {
    final String name = profileData['name'] ?? 'Unnamed Profile';
    final Widget iconWidget = _getIconForSchedule(profileData['icon'] ?? '', name);
    final List<bool> days = List<bool>.from(profileData['days'] ?? List.filled(7, false));
    final String time = '${profileData['startTime'] ?? '--:--'} - ${profileData['endTime'] ?? '--:--'}';
    final List<String> apps = (profileData['apps'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconWidget,
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              BouncyButton(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => ScheduleEditPage(profileId: profileId)));
                  _loadFocusSchedules();
                },
                child: const Icon(Icons.edit, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              BouncyButton(
                onTap: () {
                  _showDeleteConfirmationDialog(profileId);
                },
                child: const Icon(Icons.delete, color: Colors.redAccent),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          Text('Schedule', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(time, style: GoogleFonts.spaceMono(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          _buildDayIndicators(days),
          const SizedBox(height: 15),
          Text('Blocked Apps (${apps.length})', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 10),
          if (apps.isNotEmpty)
            SizedBox(
              height: 32,
              child: FutureBuilder<List<Widget>>(
                future: _getAppIcons(apps),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return ListView(scrollDirection: Axis.horizontal, children: snapshot.data!);
                },
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BouncyButton(
                onTap: () {
                  final startTimeParts = (profileData['startTime'] as String).split(':');
                  final endTimeParts = (profileData['endTime'] as String).split(':');
                  final startTime = TimeOfDay(hour: int.parse(startTimeParts[0]), minute: int.parse(startTimeParts[1]));
                  var endHour = int.parse(endTimeParts[0]);
                  var endMinute = int.parse(endTimeParts[1]);

                  // Handle overnight schedules
                  if (endHour < startTime.hour || (endHour == startTime.hour && endMinute < startTime.minute)) {
                    endHour += 24; // Add 24 hours for the next day
                  }

                  final now = DateTime.now();
                  final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
                  final endDateTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

                  final duration = endDateTime.difference(startDateTime);
                  _startFocusSession(apps, duration);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 18, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Activate', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  const Text('Auto', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Switch(value: profileData['isEnabled'] ?? false, onChanged: (val) async {
                    final profilesBox = Hive.box('focusProfiles');
                    profileData['isEnabled'] = val;
                    await profilesBox.put(profileId, profileData);
                    _loadFocusSchedules();
                  }),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDayIndicators(List<bool> days) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        return CircleAvatar(
          radius: 14,
          backgroundColor: days[index] ? Colors.blueAccent : Colors.white.withOpacity(0.1),
          child: Text(dayLabels[index], style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        );
      }),
    );
  }

  Future<List<Widget>> _getAppIcons(List<String> packageNames) async {
    List<Widget> iconWidgets = [];
    for (String packageName in packageNames) {
      try {
        final app = await DeviceApps.getApp(packageName, true);
        if (app != null && app is ApplicationWithIcon) {
          iconWidgets.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Image.memory(app.icon, width: 32, height: 32),
          ));
        }
      } catch (_) {}
    }
    return iconWidgets;
  }

  Widget _getIconForSchedule(String iconName, String profileName) {
    switch (iconName) {
      case 'work':
        return const Icon(Icons.work, color: Colors.white, size: 28);
      case 'book':
        return const Icon(Icons.book, color: Colors.white, size: 28);
      case 'self_improvement':
        return const Icon(Icons.self_improvement, color: Colors.white, size: 28);
      default:
        if (profileName.isNotEmpty) {
          return CircleAvatar(
            radius: 14,
            backgroundColor: Colors.primaries[profileName.hashCode % Colors.primaries.length],
            child: Text(
              profileName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          );
        } else {
          return const Icon(Icons.shield_moon, color: Colors.white, size: 28);
        }
    }
  }

  String _formatTotalFocusDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  String _formatDurationToHourMinute(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    if (d.inHours > 0) return '${twoDigits(d.inHours)}h ${twoDigits(d.inMinutes.remainder(60))}m';
    return '${twoDigits(d.inMinutes)}m';
  }

  Future<void> _deleteSchedule(String profileId) async {
    final profilesBox = Hive.box('focusProfiles');
    await profilesBox.delete(profileId);
    _loadFocusSchedules();
  }

  Future<void> _showDeleteConfirmationDialog(String profileId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Schedule'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete this schedule?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await _deleteSchedule(profileId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class CustomScrollPhysics extends ScrollPhysics {
  const CustomScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  CustomScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);
    if ((velocity.abs() < tolerance.velocity) ||
        (velocity > 0.0 && position.pixels >= position.maxScrollExtent) ||
        (velocity < 0.0 && position.pixels <= position.minScrollExtent)) {
      return null;
    }
    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: 0.005, // lower friction -> longer scroll
      tolerance: tolerance,
    );
  }
}

class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BouncyButton({Key? key, required this.child, this.onTap}) : super(key: key);

  @override
  _BouncyButtonState createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
