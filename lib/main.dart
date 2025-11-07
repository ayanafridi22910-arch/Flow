import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flow/app_shell.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // <-- 1. YE LINE ADD KARO

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- YAHAN ADD KARO ---
  await MobileAds.instance.initialize(); // <-- 2. YE LINE ADD KARO
  // ---------------------

  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentsDir.path);
  
  // Hive boxes ko yahan open karna aadat bana lo
  await Hive.openBox('blockerState');
  await Hive.openBox('focusProfiles');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flow',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: Brightness.dark,
      ),
      debugShowCheckedModeBanner: false,
      home: const AppShell(), // Set AppShell as the home
    );
  }
}