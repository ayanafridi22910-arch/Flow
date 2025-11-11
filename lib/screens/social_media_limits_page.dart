import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SocialMediaLimitsPage extends StatefulWidget {
  const SocialMediaLimitsPage({super.key});

  @override
  State<SocialMediaLimitsPage> createState() => _SocialMediaLimitsPageState();
}

class _SocialMediaLimitsPageState extends State<SocialMediaLimitsPage> {
  static const platform = MethodChannel('app.blocker/channel');
  bool _isReelsBlocked = false;

  @override
  void initState() {
    super.initState();
    _getReelsBlockedState();
  }

  Future<void> _getReelsBlockedState() async {
    try {
      final bool isBlocked = await platform.invokeMethod('isReelsBlocked');
      setState(() {
        _isReelsBlocked = isBlocked;
      });
    } on PlatformException catch (e) {
      print("Failed to get Reels blocked state: '${e.message}'.");
    }
  }

  Future<void> _setReelsBlockedState(bool value) async {
    try {
      await platform.invokeMethod('setReelsBlocked', {'blocked': value});
      setState(() {
        _isReelsBlocked = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reels blocking is now ${value ? "ON" : "OFF"}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } on PlatformException catch (e) {
      print("Failed to set Reels blocked state: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Media Limits'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildInstagramExpansionTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramExpansionTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.camera_alt, color: Colors.white), // Placeholder icon
        title: const Text(
          'Instagram',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SwitchListTile(
              title: const Text(
                'Block Reels',
                style: TextStyle(color: Colors.white),
              ),
              value: _isReelsBlocked,
              onChanged: _setReelsBlockedState,
              activeColor: Colors.blueAccent,
            ),
          ),
        ],
      ),
    );
  }
}
