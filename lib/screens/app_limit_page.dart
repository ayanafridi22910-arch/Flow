import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:numberpicker/numberpicker.dart';

class AppLimitPage extends StatefulWidget {
  const AppLimitPage({super.key});

  @override
  State<AppLimitPage> createState() => _AppLimitPageState();
}

class _AppLimitPageState extends State<AppLimitPage> {
  List<Application> _apps = [];
  bool _isLoading = true;
  final Set<String> _selectedApps = {};
  int _hours = 0;
  int _minutes = 15;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: false, // Exclude system apps for a cleaner list
      onlyAppsWithLaunchIntent: true,
    );
    if (mounted) {
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    }
  }

  void _onAppSelected(String packageName, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedApps.add(packageName);
      } else {
        _selectedApps.remove(packageName);
      }
    });
  }

  void _setLimit() {
    if (_selectedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one app.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final duration = Duration(hours: _hours, minutes: _minutes);
    if (duration.inSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a duration greater than zero.'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.pop(context, {
      'apps': _selectedApps.toList(),
      'duration': duration,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        title: Text('Set App Limit', style: GoogleFonts.poppins()),
        backgroundColor: Colors.grey.shade900,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDurationPicker(),
                const Divider(color: Colors.white24),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Apps to Limit',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _apps.length,
                    itemBuilder: (context, index) {
                      final app = _apps[index];
                      return ListTile(
                        leading: app is ApplicationWithIcon ? Image.memory(app.icon, width: 40) : const Icon(Icons.apps),
                        title: Text(app.appName, style: GoogleFonts.poppins(color: Colors.white70)),
                        trailing: Switch(
                          value: _selectedApps.contains(app.packageName),
                          onChanged: (isSelected) => _onAppSelected(app.packageName, isSelected),
                          activeColor: Colors.blueAccent, // Keeping blue here for selection clarity
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _setLimit,
          icon: const Icon(Icons.timer_outlined),
          label: const Text('Set Limit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text('Hours', style: GoogleFonts.poppins(color: Colors.white70)),
              NumberPicker(
                value: _hours,
                minValue: 0,
                maxValue: 23,
                onChanged: (value) => setState(() => _hours = value),
                textStyle: GoogleFonts.poppins(color: Colors.white54),
                selectedTextStyle: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 22),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Text('Minutes', style: GoogleFonts.poppins(color: Colors.white70)),
              NumberPicker(
                value: _minutes,
                minValue: 0,
                maxValue: 59,
                step: 5,
                onChanged: (value) => setState(() => _minutes = value),
                textStyle: GoogleFonts.poppins(color: Colors.white54),
                selectedTextStyle: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 22),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
