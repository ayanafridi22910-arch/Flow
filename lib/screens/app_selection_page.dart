import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // Glassmorphism ke liye

class AppSelectionPage extends StatefulWidget {
  final List<String> previouslySelectedApps;

  const AppSelectionPage({Key? key, required this.previouslySelectedApps})
      : super(key: key);

  @override
  _AppSelectionPageState createState() => _AppSelectionPageState();
}

class _AppSelectionPageState extends State<AppSelectionPage> {
  List<Application> _apps = [];
  Set<String> _selectedApps = {};
  bool _isLoading = true;
  String _searchQuery = '';
  List<Application> _filteredApps = [];

  @override
  void initState() {
    super.initState();
    _selectedApps = widget.previouslySelectedApps.toSet();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: true, 
      onlyAppsWithLaunchIntent: true, // Sirf wahi apps jo phone me dikhte hain
    );
    
    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    setState(() {
      _apps = apps;
      _filteredApps = apps;
      _isLoading = false;
    });
  }
  
  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _apps.where((app) {
        final appName = app.appName.toLowerCase();
        final packageName = app.packageName.toLowerCase();
        final search = query.toLowerCase();
        return appName.contains(search) || packageName.contains(search);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          title: Text('Select Apps', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedApps.toList());
              },
              child: Text(
                'Done',
                style: GoogleFonts.poppins(
                  color: Colors.blueAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  // --- YAHAN CHANGE HUA (Scrollbar add kiya) ---
                  : Scrollbar(
                      thumbVisibility: true, // Scrollbar hamesha dikhega
                      radius: const Radius.circular(8),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 10),
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final isSelected = _selectedApps.contains(app.packageName);
                          return _buildAppListTile(app, isSelected);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                hintText: 'Search apps...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              onChanged: _filterApps,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppListTile(Application app, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blueAccent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.blueAccent
                    : Colors.white.withOpacity(0.2),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: app is ApplicationWithIcon
                  ? Image.memory(app.icon, width: 40, height: 40)
                  : const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.apps, color: Colors.white),
                    ),
              title: Text(
                app.appName,
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // --- YAHAN CHANGE HUA (Package name hata diya) ---
              // subtitle: Text(
              //   app.packageName,
              //   style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              //   maxLines: 1,
              //   overflow: TextOverflow.ellipsis,
              // ),
              trailing: Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  _onAppTapped(app.packageName, value);
                },
                activeColor: Colors.blueAccent,
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
              ),
              onTap: () {
                _onAppTapped(app.packageName, !isSelected);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _onAppTapped(String packageName, bool? value) {
    setState(() {
      if (value == true) {
        _selectedApps.add(packageName);
      } else {
        _selectedApps.remove(packageName);
      }
    });
  }
}