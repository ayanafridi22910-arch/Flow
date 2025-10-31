import 'dart:async';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added import for kDebugMode
import 'package:google_fonts/google_fonts.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Added import
import 'package:hive_flutter/hive_flutter.dart'; // Added import for Hive
import '../native_blocker.dart';
import '../blocker_service.dart';

class HomePage extends StatefulWidget {
  final Duration? initialDuration;
  final bool isSelectionMode; // New parameter

  const HomePage({super.key, this.initialDuration, this.isSelectionMode = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // --- State Variables ---
  Duration _countdownDuration = Duration.zero;
  Timer? _countdownTimer;
  bool _isBlockingActive = false;

  List<Application> _distractiveApps = [];
  Set<String> _selectedBlockedApps = {}; // Apps selected by the user via switches
  bool _isLoading = true;

  final Set<String> _targetPackageNames = {
    'com.instagram.android',
    'com.google.android.youtube',
    'com.snapchat.android',
    'com.netflix.mediaclient',
    'com.sonyliv',
    'com.facebook.katana',
    'com.android.chrome',
  };

  // Banner Ad variables
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  // Rewarded Ad variables
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  // --- Lifecycle & Data Loading ---
  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBannerAd(); // Load banner ad
    _loadRewardedAd(); // Load rewarded ad
    _loadBlockingState(); // Load persisted blocking state

    // If an initial duration is provided, start blocking immediately
    if (widget.initialDuration != null && !_isBlockingActive) {
      // We need to ensure apps are loaded before starting blocking
      // This might require a slight delay or a different flow
      // For now, we'll assume _loadData completes quickly enough
      // or that _startBlocking handles the case where _selectedBlockedApps is empty
      // (which it does by showing a SnackBar)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.initialDuration != null) {
          _startBlocking(widget.initialDuration!); // Start blocking with the provided duration
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bannerAd?.dispose(); // Dispose banner ad
    _rewardedAd?.dispose(); // Dispose rewarded ad
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-4968291987364468/5607208296', // Tumhara real Banner Ad Unit ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          // Handle the error. For debugging, you can print it.
          if (kDebugMode) {
            print('Error loading banner ad: $err');
          }
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-4968291987364468/1741821766', // Tumhara real Rewarded Ad Unit ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (err) {
          if (kDebugMode) {
            print('Error loading rewarded ad: $err');
          }
          setState(() {
            _isRewardedAdLoaded = false;
          });
        },
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allApps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true, includeSystemApps: true, onlyAppsWithLaunchIntent: true);

    final foundApps = allApps.where((app) => _targetPackageNames.contains(app.packageName)).toList();

    final blockerBox = Hive.box('blockerState');
    final savedBlockedApps = blockerBox.get('selected_blocked_apps');

    setState(() {
      _distractiveApps = foundApps;
      _selectedBlockedApps = (savedBlockedApps as List?)?.cast<String>().toSet() ?? {};
      _isLoading = false;
    });
  }

  // --- App Selection Logic ---
  Future<void> _toggleAppSelection(String packageName, bool isSelected) async {
    setState(() {
      if (isSelected) {
        _selectedBlockedApps.add(packageName);
      } else {
        _selectedBlockedApps.remove(packageName);
      }
    });
    final blockerBox = Hive.box('blockerState');
    await blockerBox.put('selected_blocked_apps', _selectedBlockedApps.toList());
  }

  // --- Blocker Activation & Timer Logic ---
  Future<void> _startBlocking(Duration duration) async {
    if (_isBlockingActive) return;

    debugPrint("HomePage: _startBlocking called.");

    // --- Permission Check ---
    final hasOverlayPerm = await NativeBlocker.isOverlayPermissionGranted();
    final hasAccessibilityPerm = await NativeBlocker.isAccessibilityServiceEnabled();
    debugPrint("HomePage: Overlay permission granted: $hasOverlayPerm");
    debugPrint("HomePage: Accessibility permission granted: $hasAccessibilityPerm");
    if ((!hasOverlayPerm || !hasAccessibilityPerm) && mounted) {
      await _showPermissionDialog();
      // After dialog, re-check if permission was granted
      final recheckOverlayPerm = await NativeBlocker.isOverlayPermissionGranted();
      final recheckAccessibilityPerm = await NativeBlocker.isAccessibilityServiceEnabled();
      if (!recheckOverlayPerm || !recheckAccessibilityPerm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Overlay or Accessibility permission not granted. Blocker cannot activate.'), backgroundColor: Colors.red),
        );
        debugPrint("HomePage: Permissions still not granted after request.");
        return;
      }
    }

    if (_selectedBlockedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select apps to block first.'), backgroundColor: Colors.orange),
      );
      debugPrint("HomePage: No apps selected for blocking.");
      return;
    }

    debugPrint("HomePage: Calling BlockerService.updateNativeBlocker");
    BlockerService.updateNativeBlocker();
    setState(() {
      _countdownDuration = duration;
      _isBlockingActive = true;
    });

    final blockerBox = Hive.box('blockerState');
    await blockerBox.put('is_blocking_active', true);
    await blockerBox.put('blocker_end_time_millis', DateTime.now().add(duration).millisecondsSinceEpoch);
    await blockerBox.put('total_block_duration_seconds', duration.inSeconds); // Add this line
    debugPrint("HomePage: Blocker state saved to Hive.");

    _startCountdownTimer();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Blocker activated!'), backgroundColor: Colors.green));
    debugPrint("HomePage: Blocker activated successfully.");
  }
  

  void _stopBlocking() {
    if (!_isBlockingActive) return;

    _countdownTimer?.cancel();
    BlockerService.updateNativeBlocker();
    setState(() {
      _countdownDuration = Duration.zero;
      _isBlockingActive = false;
    });

    final blockerBox = Hive.box('blockerState');
    blockerBox.delete('is_blocking_active');
    blockerBox.delete('blocker_end_time_millis');

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blocker deactivated.'), backgroundColor: Colors.red));
  }

  void _startCountdownTimer() {
    if (kDebugMode) {
      print('[_startCountdownTimer] Timer started with duration: $_countdownDuration');
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownDuration.inSeconds <= 0) {
        _stopBlocking();
      } else {
        setState(() {
          _countdownDuration = _countdownDuration - const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _loadBlockingState() async {
    final blockerBox = Hive.box('blockerState');
    final savedIsBlockingActive = blockerBox.get('is_blocking_active') ?? false;
    final savedEndTimeMillis = blockerBox.get('blocker_end_time_millis');

    if (kDebugMode) {
      print('[_loadBlockingState] savedIsBlockingActive: $savedIsBlockingActive');
      print('[_loadBlockingState] savedEndTimeMillis: $savedEndTimeMillis');
    }

    if (savedIsBlockingActive && savedEndTimeMillis != null) {
      final savedEndTime = DateTime.fromMillisecondsSinceEpoch(savedEndTimeMillis);
      final remainingDuration = savedEndTime.difference(DateTime.now());

      if (kDebugMode) {
        print('[_loadBlockingState] savedEndTime: $savedEndTime');
        print('[_loadBlockingState] remainingDuration: $remainingDuration');
      }

      if (remainingDuration.isNegative) {
        // Blocker expired while app was closed
        if (kDebugMode) {
          print('[_loadBlockingState] Blocker expired, stopping.');
        }
        _stopBlocking();
      } else {
        setState(() {
          _countdownDuration = remainingDuration;
          _isBlockingActive = true;
        });
        if (kDebugMode) {
          print('[_loadBlockingState] Resuming blocker with duration: $_countdownDuration');
        }

        _startCountdownTimer(); // Start the timer with the loaded duration
      }
    }
  }

  // --- Permission Dialog ---
  Future<void> _showPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text('To block apps, please grant Overlay and Accessibility permissions.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
          TextButton(
              onPressed: () {
                NativeBlocker.requestOverlayPermission();
                NativeBlocker.openAccessibilitySettings();
                Navigator.of(context).pop();
              },
              child: const Text('Grant')),
        ],
      ),
    );
  }

  // --- Time Setting Dialog ---
  Future<void> _showTimeSettingDialog() async {
    int selectedHours = 0;
    int selectedDays = 0;
    DateTime? startDate;
    DateTime? endDate;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Blocking Duration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Block for Hours:'),
                NumberPicker(
                  value: selectedHours,
                  minValue: 0,
                  maxValue: 24,
                  onChanged: (value) => selectedHours = value,
                ),
                const SizedBox(height: 20),
                const Text('Block for Days:'),
                NumberPicker(
                  value: selectedDays,
                  minValue: 0,
                  maxValue: 30,
                  onChanged: (value) => selectedDays = value,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      startDate = picked.start;
                      endDate = picked.end;
                      // Optionally update UI to show selected range
                    }
                  },
                  child: const Text('Select Date Range'),
                ),
                if (startDate != null && endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('${startDate!.toLocal().toString().split(' ')[0]} to ${endDate!.toLocal().toString().split(' ')[0]}'),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () { Navigator.of(context).pop(); },
            ),
            TextButton(
              child: const Text('Set'),
              onPressed: () async {
                Duration duration = Duration.zero;
                if (selectedHours > 0) {
                  duration += Duration(hours: selectedHours);
                }
                if (selectedDays > 0) {
                  duration += Duration(days: selectedDays);
                }
                if (startDate != null && endDate != null) {
                  duration = endDate!.difference(startDate!) + const Duration(days: 1); // Include end day
                }

                if (duration.inSeconds > 0) {
                  await _startBlocking(duration);
                }
                if(context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  

  // --- Time Setting Dialog ---
 
  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    final days = _countdownDuration.inDays.toString().padLeft(2, '0');
    final hours = (_countdownDuration.inHours % 24).toString().padLeft(2, '0');
    final minutes = (_countdownDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_countdownDuration.inSeconds % 60).toString().padLeft(2, '0');
    final formattedCountdown = '$days:$hours:$minutes:$seconds';

    return Scaffold(
      appBar: AppBar(title: const Text('Flow App'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Countdown Timer Display
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(formattedCountdown, style: GoogleFonts.robotoMono(fontSize: 42, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(thickness: 1),
                // App List Section
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Select Distractive Apps to Block', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _distractiveApps.isEmpty
                      ? const Center(child: Text('No specified distractive apps found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          itemCount: _distractiveApps.length,
                          itemBuilder: (context, index) {
                            final app = _distractiveApps[index];
                            final isSelected = _selectedBlockedApps.contains(app.packageName);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 5.0),
                              elevation: _isBlockingActive ? 0 : 2, // Reduce elevation when blocking
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                              color: _isBlockingActive && isSelected ? Theme.of(context).colorScheme.errorContainer : null,
                              child: ListTile(
                                leading: app is ApplicationWithIcon ? Image.memory(app.icon, width: 40) : const Icon(Icons.apps, size: 40),
                                title: Text(app.appName),
                                trailing: Switch(
                                  value: isSelected,
                                  onChanged: _isBlockingActive ? null : (value) => _toggleAppSelection(app.packageName, value),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Activate/Stop Blocker Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: widget.isSelectionMode
                      ? ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context, {'selectedApps': _selectedBlockedApps.toList()});
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Select Apps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        )
                      : _isBlockingActive
                          ? ElevatedButton.icon(
                              onPressed: _stopBlocking,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('Stop Blocker'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.error,
                                foregroundColor: Theme.of(context).colorScheme.onError,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _showTimeSettingDialog,
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Activate Blocker'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                ),
                // Banner Ad
                if (_isBannerAdLoaded && _bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
    );
  }
}
