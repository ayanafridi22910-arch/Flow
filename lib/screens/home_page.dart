import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flow/screens/app_selection_page.dart'; 
import 'dart:ui'; 

import '../native_blocker.dart';
import '../blocker_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  
  Duration _countdownDuration = Duration.zero; 
  Duration _selectedDuration = Duration.zero; 
  Timer? _countdownTimer;
  bool _isBlockingActive = false;
  
  Set<String> _quickBlockApps = {}; 
  bool _isLoading = true;

  int _selectedQuickMode = 0; // 0: Normal, 1: Strict
  int _activeFocusMode = 0;   // 0: Normal, 1: Strict

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  InterstitialAd? _interstitialAd;
  
  late TabController _tabController;

  static const Color _quickFocusColor = Colors.cyan;
  static const Color _deepFocusColor = Color(0xFF8b5cf6); 
  static const Color _activeColor = Colors.blueAccent;

  static const Color _normalColor = Colors.green;
  static const Color _strictColor = Colors.red;

  static const Duration _unlimitedDuration = Duration(days: 999);


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); 
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // Rebuild
        });
      }
    });
    
    _loadData();
    _loadBannerAd();
    _loadRewardedAd();
    _loadInterstitialAd(); 
    _loadBlockingState();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bannerAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _tabController.dispose(); 
    super.dispose();
  }

  // --- Ad Logic ---
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) { setState(() { _isBannerAdLoaded = true; }); },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (kDebugMode) { print('Error loading banner ad: $err'); }
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
          });
        },
        onAdFailedToLoad: (err) {
          if (kDebugMode) { print('Error loading rewarded ad: $err'); }
          setState(() { _isRewardedAdLoaded = false; });
          Future.delayed(const Duration(seconds: 10), _loadRewardedAd);
        },
      ),
    );
  }
  
  void _loadInterstitialAd() {
    String adUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Google Test ID

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (err) {
          if (kDebugMode) { print('Error loading interstitial ad: $err'); }
          Future.delayed(const Duration(seconds: 10), _loadInterstitialAd);
        }
      )
    );
  }


  void _showRewardAdForTime(BuildContext context) {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadRewardedAd(); },
        onAdFailedToShowFullScreenContent: (ad, err) { ad.dispose(); _loadRewardedAd(); }
      );
      _rewardedAd!.show( onUserEarnedReward: (ad, reward) {
        _addBlockerTime(context, const Duration(minutes: 15));
      });
      _rewardedAd = null; 
      _isRewardedAdLoaded = false;
    } else {
      ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Ad not ready yet. Try again.')));
      if (!_isRewardedAdLoaded) _loadRewardedAd(); 
    }
  }
  
  void _showAdToStop(BuildContext context) {
    if (_rewardedAd != null) {
       _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) { ad.dispose(); _loadRewardedAd(); },
        onAdFailedToShowFullScreenContent: (ad, err) { ad.dispose(); _loadRewardedAd(); }
      );
      _rewardedAd!.show( onUserEarnedReward: (ad, reward) {
        _stopBlocking(context: context); 
      });
      _rewardedAd = null; 
      _isRewardedAdLoaded = false;
    } 
    else if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); 
          _stopBlocking(context: context); 
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose();
          _loadInterstitialAd();
          _stopBlocking(context: context); 
        }
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('No Ad available. Stopping session.'), backgroundColor: Colors.grey)
      );
      _stopBlocking(context: context); 
      _loadRewardedAd();
      _loadInterstitialAd();
    }
  }

  Future<void> _addBlockerTime(BuildContext context, Duration durationToAdd) async {
    if (!_isBlockingActive) return;
    setState(() {
      _countdownDuration += durationToAdd;
    });
    
    final blockerBox = Hive.box('blockerState');
    await blockerBox.put('blocker_end_time_millis', DateTime.now().add(_countdownDuration).millisecondsSinceEpoch);
    await blockerBox.put('total_block_duration_seconds', _countdownDuration.inSeconds);

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+15 minutes added!'), backgroundColor: Colors.green));
    }
  }


  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final blockerBox = Hive.box('blockerState');
    final savedBlockedApps = blockerBox.get('quick_block_apps');
    setState(() {
      _quickBlockApps = (savedBlockedApps as List?)?.cast<String>().toSet() ?? {};
      _isLoading = false;
    });
  }

  Future<void> _showAppSelectionPage() async {
    final selectedApps = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => AppSelectionPage(
          previouslySelectedApps: _quickBlockApps.toList(),
        ),
      ),
    );
    if (selectedApps != null) {
      setState(() { _quickBlockApps = selectedApps.toSet(); });
      final blockerBox = Hive.box('blockerState');
      await blockerBox.put('quick_block_apps', _quickBlockApps.toList());
    }
  }
  
  void _updateSelectedDuration(Duration d) {
    setState(() {
      _selectedDuration = d;
    });
  }
  
  Future<void> _showCustomTimePicker() async {
    final selectedTime = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return _CustomTimeSelectorDialog(initialTime: TimeOfDay.now());
      },
    );

    if (selectedTime != null) {
      final duration = Duration(hours: selectedTime.hour, minutes: selectedTime.minute);
      if (duration.inSeconds > 0) {
        _updateSelectedDuration(duration);
      }
    }
  }

  Future<void> _startBlocking(BuildContext context) async {
    if (_isBlockingActive) return;
    
    if (_selectedDuration.inSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a duration first.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final hasOverlayPerm = await NativeBlocker.isOverlayPermissionGranted();
    final hasAccessibilityPerm = await NativeBlocker.isAccessibilityServiceEnabled();
    if ((!hasOverlayPerm || !hasAccessibilityPerm) && mounted) {
      await _showPermissionDialog();
      return;
    }

    if (_quickBlockApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select apps to block first.'), backgroundColor: Colors.orange),
      );
      Future.delayed(const Duration(milliseconds: 500), _showAppSelectionPage);
      return;
    }
    
    final blockerBox = Hive.box('blockerState');
    await blockerBox.put('selected_blocked_apps', _quickBlockApps.toList()); 
    BlockerService.updateNativeBlocker();
    
    setState(() {
      setState(() {
      _countdownDuration = _selectedDuration;
      _isBlockingActive = true;
      _activeFocusMode = _selectedQuickMode;
      _selectedDuration = Duration.zero;
    });

    // Enter immersive mode
    });

    await blockerBox.put('is_blocking_active', true);
    await blockerBox.put('blocker_end_time_millis', DateTime.now().add(_countdownDuration).millisecondsSinceEpoch);
    await blockerBox.put('total_block_duration_seconds', _countdownDuration.inSeconds);
    await blockerBox.put('focus_mode', _activeFocusMode); 

    _startCountdownTimer();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Focus activated!'), backgroundColor: Colors.green));
    }
  }
  
  void _stopBlocking({BuildContext? context}) {
    if (!_isBlockingActive) return;
    _countdownTimer?.cancel();
    BlockerService.updateNativeBlocker();
    setState(() {
      _countdownDuration = Duration.zero;
      _isBlockingActive = false;
      _activeFocusMode = 0; 
    });
    final blockerBox = Hive.box('blockerState');
    blockerBox.delete('is_blocking_active');
    blockerBox.delete('blocker_end_time_millis');
    blockerBox.delete('focus_mode'); 
    
    if (context != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blocker deactivated.'), backgroundColor: Colors.red));
    }
  }

  void _startCountdownTimer() {
    if (_countdownDuration.inDays > 900) return;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) { timer.cancel(); return; }
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
    
    if (savedIsBlockingActive && savedEndTimeMillis != null) {
      final savedEndTime = DateTime.fromMillisecondsSinceEpoch(savedEndTimeMillis);
      final remainingDuration = savedEndTime.difference(DateTime.now());
      if (remainingDuration.isNegative) {
        _stopBlocking(); 
      } else {
        setState(() {
          _countdownDuration = remainingDuration;
          _isBlockingActive = true;
          _activeFocusMode = blockerBox.get('focus_mode') ?? 0; 
        });
        
        if (_countdownDuration.inDays < 900) {
          _startCountdownTimer();
        }
      }
    }
  }

  Future<void> _showPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C2A),
        title: Text('Permissions Required', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('To block apps, please grant Overlay and Accessibility permissions.', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Later', style: GoogleFonts.poppins(color: Colors.white70))),
          TextButton(
              onPressed: () {
                NativeBlocker.requestOverlayPermission();
                NativeBlocker.openAccessibilitySettings();
                Navigator.of(context).pop();
              },
              child: Text('Grant', style: GoogleFonts.poppins(color: _activeColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContextCtxt) { 
    final durationToDisplay = _isBlockingActive ? _countdownDuration : _selectedDuration;
    
    String formattedCountdown;
    final days = durationToDisplay.inDays;
    final hours = durationToDisplay.inHours.remainder(24);
    final minutes = durationToDisplay.inMinutes.remainder(60);
    final seconds = durationToDisplay.inSeconds.remainder(60);

    if (days > 900) {
      formattedCountdown = "DEEP FOCUS"; 
    } else if (days > 0) {
      formattedCountdown = "${days}d ${hours.toString().padLeft(2, '0')}h"; 
    } else if (hours > 0) {
      formattedCountdown = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"; 
    } else {
      formattedCountdown = "00:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"; 
    }
    
    if (_isBlockingActive && _countdownDuration.inDays > 900) {
      formattedCountdown = "DEEP FOCUS";
    }
    

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF030A24), Color(0xFF00020C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Start Focus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: _isBlockingActive ? null : TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
            unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            tabs: [
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.timer_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Quick Focus'),
                ]),
              ),
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.all_inclusive_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Deep Focus'),
                ]),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // --- FIX: Timer card yahan se HATA diya ---
                  
                  Expanded(
                    child: _isBlockingActive
                        // --- FIX: Argument yahan pass kiya ---
                        ? Builder(builder: (context) => _buildBlockingActiveView(context, formattedCountdown)) 
                        : TabBarView(
                            controller: _tabController,
                            // --- FIX: Slide physics change kiya ---
                            physics: const BouncingScrollPhysics(), 
                            children: [
                              // --- FIX: Argument yahan pass kiya ---
                              Builder(builder: (context) => _buildQuickFocusView(context, formattedCountdown)), 
                              Builder(builder: (context) => _buildDeepFocusView(context)), 
                            ],
                          ),
                  ),
                  
                  if (_isBannerAdLoaded && _bannerAd != null)
                    Container(
                      color: Colors.black,
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                ],
              ),
      ),
    );
  }

  // --- NAYA LAYOUT ---
  Widget _buildQuickFocusView(BuildContext context, String formattedCountdown) {
    // --- FIX: Ab SingleChildScrollView use kar rahe hain ---
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 
                     (Scaffold.of(context).appBarMaxHeight ?? 0) - 
                     (MediaQuery.of(context).padding.top + MediaQuery.of(context).padding.bottom) - 
                     (_isBannerAdLoaded ? 50 : 0) - 
                     100, // Extra buffer
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- FIX: Timer card yahan ADD kiya ---
                _buildTimerDisplay(context, formattedCountdown, key: const ValueKey('quick_timer')),
                
                const SizedBox(height: 20),
                _buildSectionHeader('1. Select Duration', _quickFocusColor),
                _buildTimePresetButtons(), 
                
                const SizedBox(height: 24),
                
                _buildSectionHeader('2. Select Apps', _quickFocusColor),
                _buildAppSelectorCard(_quickFocusColor), 
              ],
            ),
            
            Column(
              children: [
                const SizedBox(height: 24), // Extra space
                _buildSectionHeader('3. Select Mode', _quickFocusColor),
                _buildModeSelector(), 
                const SizedBox(height: 24),
                _buildStartButton(context), 
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModeSelector() {
    return Row(
      children: [
        _buildModeOption(
          'Normal', 
          Icons.lock_open_rounded, 
          _normalColor, 
          _selectedQuickMode == 0, 
          () => setState(() => _selectedQuickMode = 0),
        ),
        const SizedBox(width: 16),
        _buildModeOption(
          'Strict', 
          Icons.lock_rounded, 
          _strictColor, 
          _selectedQuickMode == 1, 
          () => setState(() => _selectedQuickMode = 1),
        ),
      ],
    );
  }
  
  Widget _buildModeOption(String title, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.white.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            )
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildDeepFocusView(BuildContext context) {
     return Padding(
       padding: const EdgeInsets.all(20),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
          const SizedBox(height: 20),
           _buildSectionHeader('1. Select Apps', _deepFocusColor),
           _buildAppSelectorCard(_deepFocusColor), 
           
           const Spacer(), 
           
           Center(
             child: Icon(
              Icons.all_inclusive_rounded, 
              color: _deepFocusColor.withOpacity(0.4), 
              size: 140
            ),
           ),
           
           const SizedBox(height: 16),
           
           Center(
             child: Text(
               'Deep Focus (Unlimited)',
               style: GoogleFonts.poppins(
                 color: Colors.white,
                 fontSize: 22,
                 fontWeight: FontWeight.w600,
               ),
             ),
           ),
           Center(
             child: Text(
               'Blocks selected apps until you stop manually.',
               style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
             ),
           ),
           
           const Spacer(), 
           
           GestureDetector(
             onTap: () {
               setState(() {
                 _selectedQuickMode = 1; 
                 _selectedDuration = _unlimitedDuration; 
               });
               _startBlocking(context);
             },
             child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _deepFocusColor,
                  boxShadow: [
                    BoxShadow(
                      color: _deepFocusColor.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Start Unlimited Session',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
           ),
           const SizedBox(height: 16),
         ],
       ),
     );
  }


  Widget _buildBlockingActiveView(BuildContext context, String formattedCountdown) {
    bool isDeepFocus = _countdownDuration.inDays > 900;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // --- FIX: Active timer yahan bhi dikhega ---
          _buildTimerDisplay(context, formattedCountdown, key: const ValueKey('active_timer')),
          const Spacer(),
          
          if (!isDeepFocus) ...[
            _buildRewardButton(context), 
            const SizedBox(height: 16),
          ],
          
          if (_activeFocusMode == 0) 
            _buildStopButton(context)
          else 
            _buildStopWithAdButton(context),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildStopWithAdButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0), // Full width
      child: GestureDetector(
        onTap: () => _showAdToStop(context),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.amber.withOpacity(0.2), 
            border: Border.all(color: Colors.amber),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Stop (Watch Ad)',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardButton(BuildContext context) {
    bool canShowAd = _isRewardedAdLoaded; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0), // Full width
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: canShowAd ? 1.0 : 0.5,
        child: GestureDetector(
          onTap: canShowAd ? () => _showRewardAdForTime(context) : null,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.green.withOpacity(0.2), 
              border: Border.all(color: Colors.green),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.slow_motion_video_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Watch Ad to Add 15 Min',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(BuildContext context, String formattedCountdown, {Key? key}) {
    bool isDeepFocus = _isBlockingActive && _countdownDuration.inDays > 900;
    bool isTimerSet = _selectedDuration > Duration.zero;
    
    // --- ACTIVE STATE ---
    if (_isBlockingActive) {
      return Padding(
        key: key, 
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 10), // Horizontal padding 0
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              decoration: BoxDecoration(
                color: isDeepFocus ? _deepFocusColor.withOpacity(0.2) : _activeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDeepFocus ? _deepFocusColor : _activeColor, width: 2),
              ),
              child: Column(
                children: [
                   Text(
                    isDeepFocus ? 'DEEP FOCUS ACTIVE' : (_activeFocusMode == 1 ? 'STRICT MODE ACTIVE' : 'FOCUS IS ACTIVE'),
                    style: GoogleFonts.poppins(fontSize: 12, color: isDeepFocus ? _deepFocusColor : (_activeFocusMode == 1 ? Colors.amber : Colors.white), fontWeight: FontWeight.w600, letterSpacing: 2),
                  ),
                  Text(
                    isDeepFocus ? "∞" : formattedCountdown,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // --- INACTIVE STATE ---
    return Padding(
      key: key, 
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10), // Horizontal padding 0
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isTimerSet ? _quickFocusColor : Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                 Text(
                  isTimerSet ? 'SESSION PREPARED' : 'SELECT DURATION', 
                  style: GoogleFonts.poppins(
                    fontSize: 12, 
                    color: isTimerSet ? _quickFocusColor : Colors.white70, 
                    fontWeight: FontWeight.w600, 
                    letterSpacing: 2
                  ),
                ),
                Text(
                  isTimerSet ? formattedCountdown : "00:00:00", 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: isTimerSet ? Colors.white : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePresetButtons() {
    final presets = [
      {'label': '30 min', 'duration': const Duration(minutes: 30)},
      {'label': '1 Hour', 'duration': const Duration(hours: 1)},
      {'label': '2 Hours', 'duration': const Duration(hours: 2)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          ...presets.map((preset) {
            final isSelected = _selectedDuration == preset['duration'];
            return _buildTimeChip(
              preset['label'] as String,
              isSelected,
              () => _updateSelectedDuration(preset['duration'] as Duration),
              _quickFocusColor, 
            );
          }),
          _buildTimeChip(
            'Custom',
            false, 
            _showCustomTimePicker,
            _quickFocusColor, 
            icon: Icons.edit,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, bool isSelected, VoidCallback onTap, Color accentColor, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), 
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.3) : const Color(0xFF1A1C2A), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : accentColor.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ) 
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSelectorCard(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 0.0),
      child: GestureDetector(
        onTap: _showAppSelectionPage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apps to Block', 
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${_quickBlockApps.length} apps selected',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStartButton(BuildContext context) {
    final Color buttonColor = _selectedQuickMode == 0 ? _normalColor : _strictColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0), 
      child: GestureDetector(
        onTap: () => _startBlocking(context),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [buttonColor, buttonColor.withOpacity(0.7)],
              begin: Alignment.centerLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: buttonColor.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Start Focus (${_selectedQuickMode == 0 ? "Normal" : "Strict"})',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildStopButton(BuildContext context) {
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GestureDetector(
        onTap: () => _stopBlocking(context: context),
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.red],
              begin: Alignment.centerLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Stop Focus',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Custom Time Selector Dialog ---

class _CustomTimeSelectorDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const _CustomTimeSelectorDialog({required this.initialTime});

  @override
  _CustomTimeSelectorDialogState createState() => _CustomTimeSelectorDialogState();
}

class _CustomTimeSelectorDialogState extends State<_CustomTimeSelectorDialog> {
  late int _selectedHour; 
  late int _selectedMinute;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  
  @override
  void initState() {
    super.initState();
    _selectedHour = 0; 
    _selectedMinute = 30; 

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }
  
  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _onSave() {
    final selectedTime = TimeOfDay(hour: _selectedHour, minute: _selectedMinute);
    Navigator.of(context).pop(selectedTime);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C2A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Duration', 
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSpinner(
                      controller: _hourController,
                      itemCount: 24, 
                      onChanged: (index) { setState(() { _selectedHour = index; }); },
                      labels: List.generate(24, (i) => i.toString().padLeft(2, '0')),
                      suffix: "hr", 
                    ),
                    Text(":", style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600)),
                    _buildSpinner(
                      controller: _minuteController,
                      itemCount: 60, 
                      onChanged: (index) { setState(() { _selectedMinute = index; }); },
                      labels: List.generate(60, (i) => i.toString().padLeft(2, '0')),
                      suffix: "min", 
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _onSave,
                        child: Text(
                          'OK',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSpinner({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onChanged,
    required List<String> labels,
    String? suffix,
  }) {
    return Container(
      width: 90, 
      height: 120,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 50,
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) {
            final label = labels[index];
            final bool isSelected = (controller.hasClients && controller.selectedItem == index);
            
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: GoogleFonts.poppins(
                  fontSize: isSelected ? 28 : 22,
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text('$label ${suffix ?? ''}'), 
              ),
            );
          },
        ),
      ),
    );
  }
}