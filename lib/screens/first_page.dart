import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flow/screens/home_page.dart';
import 'package:flow/native_blocker.dart';
import 'package:flow/screens/permission_page_redesigned.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flow/screens/schedule_timing_page.dart';
import 'package:device_apps/device_apps.dart';

// --- Custom Widgets for Zen Focus Theme ---

// Placeholder for Dynamic Background
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
      duration: const Duration(seconds: 20), // Slow, subtle animation
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant DynamicZenBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                  ? [ // Active state - keep it a bit more vibrant
                      Color.lerp(Colors.deepPurple.shade800, Colors.black, _animation.value)!,
                      Color.lerp(Colors.indigo.shade800, Colors.black, _animation.value)!,
                    ]
                  : [ // Idle state - make it darker
                      const Color(0xFF0A0A1A), // Deep, dark blue/black
                      Color.lerp(const Color(0xFF1A237E), Colors.black, 0.5)! // Dark indigo
                    ],
              stops: const [0.0, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// Placeholder for Focus Orb/Gem
class FocusOrb extends StatelessWidget {
  final Duration countdownDuration;
  final Duration totalDuration;
  final bool isActive;

  const FocusOrb({
    Key? key,
    required this.countdownDuration,
    required this.totalDuration,
    this.isActive = false,
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
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            isActive ? Colors.blue.shade300.withOpacity(0.8) : Colors.grey.shade600.withOpacity(0.6),
            isActive ? Colors.deepPurple.shade700.withOpacity(0.8) : Colors.grey.shade900.withOpacity(0.8),
          ],
          stops: [0.0, 1.0 - progress], // Visual progress
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
              style: GoogleFonts.spaceMono( // Futuristic font
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (countdownDuration.inDays > 0) // Show full format if days are present
              Text(
                '${countdownDuration.inHours.remainder(24).toString().padLeft(2, "0")}:${countdownDuration.inMinutes.remainder(60).toString().padLeft(2, "0")}:${countdownDuration.inSeconds.remainder(60).toString().padLeft(2, "0")}',
                style: GoogleFonts.spaceMono(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Focusing...',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
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

class _FirstPageState extends State<FirstPage> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('app.blocker/channel');

  // --- State Variables ---
  Duration _countdownDuration = Duration.zero;
  Timer? _countdownTimer;
  bool _isBlockingActive = false;
  Set<String> _selectedBlockedApps = {};
  int _streakCount = 0;
  Duration _currentSessionTotalDuration = Duration.zero; // Duration for the current active session
  Duration _totalFocusDuration = Duration.zero; // Overall cumulative focus duration
  List<Application> _blockedAppsDetails = [];
  List<Widget> _blockedAppIconWidgets = [];

  Map<String, Map<String, dynamic>> _schedules = {};
  final List<Color> _cardColors = [
    Colors.purple.shade300,
    Colors.grey.shade400,
    Colors.teal.shade300,
    Colors.orange.shade300,
    Colors.pink.shade300,
  ];
  final Random _random = Random();
  bool _isInitialized = false;

  // Motivational quotes
  final List<String> _motivationalQuotes = [
    "The quieter you become, the more you are able to hear.",
    "Focus on your goals, not your fear.",
    "The journey of a thousand miles begins with a single step.",
    "Your mind is a garden, your thoughts are the seeds. You can grow flowers or you can grow weeds.",
    "Concentration is the root of all the higher abilities in man.",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllData();
  }

  void _loadAllData() async {
    await Hive.openBox('schedules');
    await Hive.openBox('blockerState');
    await _checkAllCorePermissions();

    if (mounted) {
      await _loadBlockingState();
      await _loadStreakCount();
      await _loadTotalFocusDuration();
      await _loadSchedules();

      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadAllData();
    }
  }

  Future<void> _checkAllCorePermissions() async {
    final allPermissions = await Future.wait([
      Permission.notification.status,
      Permission.systemAlertWindow.status,
      _channel.invokeMethod('checkAccessibilityServiceEnabled').catchError((_) => false),
    ]);

    final notificationStatus = allPermissions[0] as PermissionStatus;
    final overlayStatus = allPermissions[1] as PermissionStatus;
    final accessibilityStatus = allPermissions[2] as bool;

    if (!notificationStatus.isGranted ||
        !overlayStatus.isGranted ||
        !accessibilityStatus) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PermissionPageRedesigned()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> _loadBlockingState() async {
    final blockerBox = Hive.box('blockerState');
    final savedIsBlockingActive = blockerBox.get('is_blocking_active') ?? false;
    final savedEndTimeMillis = blockerBox.get('blocker_end_time_millis');
    final savedBlockedApps = blockerBox.get('selected_blocked_apps');
    final savedTotalDurationSeconds = blockerBox.get('current_session_total_duration_seconds');

    if (savedIsBlockingActive && savedEndTimeMillis != null) {
      final savedEndTime = DateTime.fromMillisecondsSinceEpoch(savedEndTimeMillis);
      final remainingDuration = savedEndTime.difference(DateTime.now());

      if (remainingDuration.isNegative) {
        _stopBlocking();
      } else {
        if (mounted) {
          setState(() {
            _countdownDuration = remainingDuration;
            _isBlockingActive = true;
            _selectedBlockedApps = (savedBlockedApps as List?)?.cast<String>().toSet() ?? {};
            if (savedTotalDurationSeconds != null) {
              _currentSessionTotalDuration = Duration(seconds: savedTotalDurationSeconds);
            }
            if (_selectedBlockedApps.isNotEmpty) {
              _loadBlockedAppsDetails(_selectedBlockedApps.toList());
            }
          });
        }
        NativeBlocker.setBlockedApps(_selectedBlockedApps.toList());
        _startCountdownTimer();
      }
    }
  }

  Future<void> _loadBlockedAppsDetails(List<String> packageNames) async {
    List<Application> apps = [];
    List<Widget> iconWidgets = [];
    for (String packageName in packageNames) {
      final app = await DeviceApps.getApp(packageName, true);
      if (app != null) {
        apps.add(app as Application);
        iconWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Image.memory((app as ApplicationWithIcon).icon, width: 40, height: 40), // Smaller icons
                const SizedBox(height: 4),
                Text(
                  app.appName.length > 6 ? '${app.appName.substring(0, 5)}..' : app.appName, // Shorter truncation
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }
    }
    if (mounted) {
      setState(() {
        _blockedAppsDetails = apps;
        _blockedAppIconWidgets = iconWidgets;
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String days = d.inDays > 0 ? '${d.inDays}D : ' : '';
    String hours = twoDigits(d.inHours.remainder(24));
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return "$days$hours : $minutes : $seconds";
  }

  String _formatTotalFocusDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  Future<void> _loadStreakCount() async {
    final blockerBox = Hive.box('blockerState');
    if (mounted) {
      setState(() {
        _streakCount = blockerBox.get('streak_count') ?? 0;
      });
    }
  }

  Future<void> _loadTotalFocusDuration() async {
    final blockerBox = Hive.box('blockerState');
    if (mounted) {
      setState(() {
        _totalFocusDuration = Duration(seconds: blockerBox.get('total_focus_seconds') ?? 0);
      });
    }
  }

  Future<void> _loadSchedules() async {
    final schedulesBox = Hive.box('schedules');
    if (mounted) {
      setState(() {
        _schedules = schedulesBox.toMap().map(
              (key, value) => MapEntry(key.toString(), Map<String, dynamic>.from(value)),
            );
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownDuration.inSeconds <= 0) {
        _stopBlocking();
      } else {
        if (mounted) {
          setState(() {
            _countdownDuration = _countdownDuration - const Duration(seconds: 1);
          });
        }
      }
    });
  }

  Future<void> _stopBlocking() async {
    if (!_isBlockingActive) return;

    _countdownTimer?.cancel();
    NativeBlocker.setBlockedApps([]);

    final blockerBox = Hive.box('blockerState');
    await blockerBox.delete('is_blocking_active');
    await blockerBox.delete('blocker_end_time_millis');
    await blockerBox.delete('selected_blocked_apps');
    await blockerBox.delete('current_session_total_duration_seconds');

    if (_isBlockingActive) { // Only increment if session was actually active
      await _incrementStreak();
      await _addCurrentSessionToTotalFocus();
    }

    if (mounted) {
      setState(() {
        _countdownDuration = Duration.zero;
        _isBlockingActive = false;
        _currentSessionTotalDuration = Duration.zero;
        _selectedBlockedApps = {};
        _blockedAppsDetails = [];
        _blockedAppIconWidgets = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Focus session ended.'), backgroundColor: Colors.deepPurple),
      );
    }
    _loadTotalFocusDuration();
  }

  Future<void> _incrementStreak() async {
    final blockerBox = Hive.box('blockerState');
    int currentStreak = blockerBox.get('streak_count') ?? 0;
    await blockerBox.put('streak_count', currentStreak + 1);
    _loadStreakCount();
  }

  Future<void> _addCurrentSessionToTotalFocus() async {
    final blockerBox = Hive.box('blockerState');
    int currentTotalFocusSeconds = blockerBox.get('total_focus_seconds') ?? 0;
    int newTotal = currentTotalFocusSeconds + _currentSessionTotalDuration.inSeconds;
    await blockerBox.put('total_focus_seconds', newTotal);
    _loadTotalFocusDuration();
  }

  Future<void> _startBlocking(List<String> appsToBlock, Duration durationToBlock) async {
    if (appsToBlock.isEmpty || durationToBlock.inSeconds <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select apps and a valid duration.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    // Optional: Guided Breathing Prompt
    await _showGuidedBreathingDialog();

    final blockerBox = Hive.box('blockerState');
    final endTime = DateTime.now().add(durationToBlock);
    await blockerBox.put('is_blocking_active', true);
    await blockerBox.put('blocker_end_time_millis', endTime.millisecondsSinceEpoch);
    await blockerBox.put('selected_blocked_apps', appsToBlock.toList());
    await blockerBox.put('current_session_total_duration_seconds', durationToBlock.inSeconds);

    NativeBlocker.setBlockedApps(appsToBlock);

    if (mounted) {
      setState(() {
        _isBlockingActive = true;
        _countdownDuration = durationToBlock;
        _selectedBlockedApps = appsToBlock.toSet();
        _currentSessionTotalDuration = durationToBlock;
      });
      _loadBlockedAppsDetails(appsToBlock);
      _startCountdownTimer();

      // Show motivational quote
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _motivationalQuotes[_random.nextInt(_motivationalQuotes.length)],
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white, fontStyle: FontStyle.italic),
          ),
          backgroundColor: Colors.deepPurple.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showGuidedBreathingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.deepPurple.shade900.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Prepare for Focus',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Take a deep breath. Clear your mind.',
              style: GoogleFonts.poppins(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Breathing animation placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent, width: 2),
              ),
              child: Center(
                child: Text('🧘‍♂️', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                'Ready to Flow',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog() {
    final String newScheduleId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScheduleTimingPage(
          scheduleId: newScheduleId,
        ),
      ),
    ).then((_) => _loadSchedules());
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A1A), // Deeper background for loading
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by stack
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Flow',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          _buildAppBarMetric(Icons.local_fire_department, 'Streak: $_streakCount', Colors.orange.shade400),
          const SizedBox(width: 10),
          _buildAppBarMetric(Icons.hourglass_empty, 'Focus: ${_formatTotalFocusDuration(_totalFocusDuration)}', Colors.blue.shade400),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              // Navigate to settings page
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Dynamic Background
          DynamicZenBackground(isFocusActive: _isBlockingActive),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40), // Space below app bar

                  // --- Active Blocking Session Display ---
                  if (_isBlockingActive)
                    _buildActiveSessionDisplay()
                  else
                    // --- Idle State Display ---
                    _buildIdleStateDisplay(),

                  const SizedBox(height: 50),

                  // --- Your Flow Zones (Schedules) ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Flow Zones 🧘‍♀️', // New Section Title
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _schedules.isEmpty
                        ? Center(
                            child: Text(
                              'No Flow Zones yet. Tap + to create your focus routine!',
                              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _schedules.length,
                            itemBuilder: (context, index) {
                              final scheduleId = _schedules.keys.elementAt(index);
                              final scheduleData = _schedules[scheduleId];
                              final color = _cardColors[index % _cardColors.length];

                              return _buildScheduleCard(
                                scheduleId: scheduleId,
                                icon: _getScheduleIcon(scheduleData?['title']),
                                title: scheduleData?['title'] ?? 'Unnamed Zone',
                                scheduleData: scheduleData,
                                color: color,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddScheduleDialog,
        backgroundColor: Colors.blueAccent.shade400, // Vibrant blue for FAB
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- Helper Widgets and Functions ---

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
    return Column(
      children: [
        Text(
          'Focus Mode: Active',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 30),
        FocusOrb(
          countdownDuration: _countdownDuration,
          totalDuration: _currentSessionTotalDuration,
          isActive: true,
        ),
        const SizedBox(height: 30),
        if (_blockedAppIconWidgets.isNotEmpty)
          Column(
            children: [
              Text(
                'Blocking Flow Disrupters:',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _blockedAppIconWidgets,
                ),
              ),
            ],
          )
        else
          Text(
            'All distracting apps are currently blocked.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _stopBlocking,
          icon: const Icon(Icons.power_settings_new, color: Colors.white, size: 28), // Power off icon for stopping
          label: Text(
            'End Focus Session',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.shade400.withOpacity(0.8), // Softer red
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 8,
            shadowColor: Colors.redAccent.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildIdleStateDisplay() {
    return Column(
      children: [
        Text(
          'Your Space, Your Focus.',
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Ready to activate your Flow State?',
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.7),
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            ).then((result) {
              if (result != null && result is Map<String, dynamic>) {
                final List<String> selectedApps = List<String>.from(result['selectedApps']);
                final Duration duration = result['duration'] as Duration;
                _startBlocking(selectedApps, duration);
              }
              _loadAllData();
            });
          },
          icon: const Icon(Icons.stars, color: Colors.white, size: 28), // Star icon for 'Flow State'
          label: Text(
            'Start New Flow Session',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.shade700,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 8,
            shadowColor: Colors.blueAccent.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Future<void> _showBlockedAppsDialog(List<String> packageNames) async {
    List<Application> apps = [];
    for (String packageName in packageNames) {
      try {
        final app = await DeviceApps.getApp(packageName, true);
        if (app != null) {
          apps.add(app as Application);
        }
      } catch (e) {
        // App might be uninstalled
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Blocked Apps', style: GoogleFonts.poppins(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return ListTile(
                leading: Image.memory((app as ApplicationWithIcon).icon, width: 40, height: 40),
                title: Text(app.appName, style: GoogleFonts.poppins(color: Colors.white70)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  void _startManualSchedule(Map<String, dynamic>? scheduleData) {
    if (scheduleData == null) return;

    final List<String> appsToBlock = (scheduleData['blockedApps'] as List?)?.cast<String>() ?? [];
    if (appsToBlock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No apps selected for this schedule. Please edit the schedule to add apps.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final startTimeParts = scheduleData['startTime'].split(':');
    final endTimeParts = scheduleData['endTime'].split(':');
    final startTime = TimeOfDay(hour: int.parse(startTimeParts[0]), minute: int.parse(startTimeParts[1]));
    final endTime = TimeOfDay(hour: int.parse(endTimeParts[0]), minute: int.parse(endTimeParts[1]));

    final now = DateTime.now();
    final startDateTime = DateTime(now.year, now.month, now.day, startTime.hour, startTime.minute);
    var endDateTime = DateTime(now.year, now.month, now.day, endTime.hour, endTime.minute);

    if (endDateTime.isBefore(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    final duration = endDateTime.difference(startDateTime);

    if (duration.inSeconds <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid schedule duration.'), backgroundColor: Colors.red),
        );
        return;
    }

    _startBlocking(appsToBlock, duration);
  }

  IconData _getScheduleIcon(String? title) {
    if (title == null) return Icons.calendar_today;
    if (title.toLowerCase().contains('school') || title.toLowerCase().contains('class')) return Icons.school;
    if (title.toLowerCase().contains('work') || title.toLowerCase().contains('office')) return Icons.work;
    if (title.toLowerCase().contains('study') || title.toLowerCase().contains('learn')) return Icons.book;
    if (title.toLowerCase().contains('sleep') || title.toLowerCase().contains('night')) return Icons.bed;
    if (title.toLowerCase().contains('exercise') || title.toLowerCase().contains('gym')) return Icons.fitness_center;
    return Icons.calendar_today;
  }

  Widget _buildScheduleCard({
    required String scheduleId,
    required IconData icon,
    required String title,
    required Map<String, dynamic>? scheduleData,
    required Color color,
  }) {
    bool isScheduleSet = scheduleData != null &&
        scheduleData.containsKey('startTime') &&
        scheduleData.containsKey('endTime');

    bool isCurrentlyActive = false;
    if (isScheduleSet && (scheduleData!['isEnabled'] ?? false)) {
      final now = DateTime.now();
      final nowTime = TimeOfDay.fromDateTime(now);
      final startTimeParts = scheduleData['startTime'].split(':');
      final endTimeParts = scheduleData['endTime'].split(':');

      final startTime = TimeOfDay(hour: int.parse(startTimeParts[0]), minute: int.parse(startTimeParts[1]));
      final endTime = TimeOfDay(hour: int.parse(endTimeParts[0]), minute: int.parse(endTimeParts[1]));

      final List<bool> selectedDays = List<bool>.from(scheduleData['selectedDays'] ?? List.filled(7, false));
      final int currentDayIndex = now.weekday - 1;
      bool isTodayScheduled = selectedDays[currentDayIndex];

      if (isTodayScheduled) {
        if (startTime.hour < endTime.hour || (startTime.hour == endTime.hour && startTime.minute <= endTime.minute)) {
          if ((nowTime.hour > startTime.hour || (nowTime.hour == startTime.hour && nowTime.minute >= startTime.minute)) &&
              (nowTime.hour < endTime.hour || (nowTime.hour == endTime.hour && nowTime.minute < endTime.minute))) {
            isCurrentlyActive = true;
          }
        } else { // Overnight schedule
          if ((nowTime.hour > startTime.hour || (nowTime.hour == startTime.hour && nowTime.minute >= startTime.minute)) ||
              (nowTime.hour < endTime.hour || (nowTime.hour == endTime.hour && nowTime.minute < endTime.minute))) {
            isCurrentlyActive = true;
          }
        }
      }
    }

    String scheduleText = isScheduleSet
        ? '${scheduleData!['startTime']} - ${scheduleData['endTime']}'
        : 'Tap to set up';

    final List<bool> selectedDays = List<bool>.from(scheduleData?['selectedDays'] ?? List.filled(7, false));
    final List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<String> activeDays = [];
    for (int i = 0; i < selectedDays.length; i++) {
      if (selectedDays[i]) {
        activeDays.add(dayNames[i]);
      }
    }
    String daysText = activeDays.isEmpty ? 'No days selected' : activeDays.join(', ');
    if (activeDays.length == 7) daysText = 'Daily';
    else if (activeDays.length == 5 && activeDays.every((day) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].contains(day))) daysText = 'Weekdays';
    else if (activeDays.length == 2 && activeDays.every((day) => ['Sat', 'Sun'].contains(day))) daysText = 'Weekends';

    final List<String> blockedApps = (scheduleData?['blockedApps'] as List?)?.cast<String>() ?? [];

    return Card(
      color: isCurrentlyActive ? Colors.deepPurple.shade700.withOpacity(0.8) : Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isCurrentlyActive ? BorderSide(color: color, width: 1.5) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 15),
      elevation: isCurrentlyActive ? 8 : 2,
      shadowColor: isCurrentlyActive ? color.withOpacity(0.6) : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCurrentlyActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade400.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isScheduleSet) ...[
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    scheduleText,
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    daysText,
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.block, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${blockedApps.length} apps blocked',
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  const Spacer(),
                  if (blockedApps.isNotEmpty)
                    SizedBox(
                      height: 24,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: color.withOpacity(0.2),
                        ),
                        onPressed: () => _showBlockedAppsDialog(blockedApps),
                        child: Text('View', style: GoogleFonts.poppins(color: color.lighten(0.2), fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ] else
              Text(
                'Tap Edit to configure this Flow Zone.',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isScheduleSet)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-start', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                      Transform.scale(
                        scale: 0.8,
                        alignment: Alignment.centerLeft,
                        child: Switch(
                          value: scheduleData!['isEnabled'] ?? false,
                          onChanged: (val) async {
                            final schedulesBox = Hive.box('schedules');
                            scheduleData['isEnabled'] = val;
                            await schedulesBox.put(scheduleId, scheduleData);
                            _loadSchedules();
                          },
                          activeColor: color.lighten(0.1),
                          activeTrackColor: color.withOpacity(0.5),
                          inactiveThumbColor: Colors.grey[400],
                          inactiveTrackColor: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                if (isScheduleSet && !isCurrentlyActive)
                  ElevatedButton.icon(
                    onPressed: () => _startManualSchedule(scheduleData),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScheduleTimingPage(
                              scheduleId: scheduleId,
                              initialTitle: title,
                              initialStartTime: isScheduleSet ? scheduleData!['startTime'] : null,
                              initialEndTime: isScheduleSet ? scheduleData!['endTime'] : null,
                              initialSelectedDays: isScheduleSet ? List<bool>.from(scheduleData!['selectedDays'] ?? List.filled(7, false)) : List.filled(7, false),
                              initialBlockedApps: isScheduleSet ? (scheduleData!['blockedApps'] as List?)?.cast<String>().toSet() ?? {} : {},
                            ),
                          ),
                        ).then((_) => _loadSchedules());
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: Colors.grey.shade900,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              title: Text('Delete Flow Zone', style: GoogleFonts.poppins(color: Colors.white)),
                              content: Text('Are you sure you want to delete the "$title" Flow Zone?', style: GoogleFonts.poppins(color: Colors.white70)),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                TextButton(
                                  child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent)),
                                  onPressed: () async {
                                    final schedulesBox = Hive.box('schedules');
                                    await schedulesBox.delete(scheduleId);
                                    _loadSchedules();
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to lighten color (for switch activeColor)
extension ColorExtension on Color {
  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}