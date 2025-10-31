import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flow/app_shell.dart'; // Import the new AppShell

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentsDir.path);
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
      home: const AppShell(), // Set AppShell as the home
    );
  }
}