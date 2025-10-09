import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flow/app_open_ad_manager.dart';
import 'screens/home_page.dart';
import 'package:flow/screens/permission_screen.dart';

void main() {
  // Ensure that the Flutter binding is initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();

  

  MobileAds.instance.initialize();
  runApp(const AppBlocker());
}

class AppBlocker extends StatefulWidget {
  const AppBlocker({super.key});

  @override
  State<AppBlocker> createState() => _AppBlockerState();
}

class _AppBlockerState extends State<AppBlocker> with WidgetsBindingObserver {
  late AppOpenAdManager _appOpenAdManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appOpenAdManager = AppOpenAdManager('ca-app-pub-4968291987364468/8620384443'); // Tumhara real Ad Unit ID
    _appOpenAdManager.loadAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appOpenAdManager.showAdIfAvailable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Blocker',
      theme: ThemeData(
        // Use Material 3 design.
        useMaterial3: true,
        // Define the color scheme for the app.
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white
        )
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system, // Use system theme (light/dark)
      debugShowCheckedModeBanner: false,
      // The main screen of the app.
      home: const PermissionsScreen(),
    );
  }
}
