import 'package:flow/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:ui'; // Glassmorphism ke liye

class ScheduleEditPage extends StatefulWidget {
  final String? profileId;

  const ScheduleEditPage({super.key, this.profileId});

  @override
  _ScheduleEditPageState createState() => _ScheduleEditPageState();
}

class _ScheduleEditPageState extends State<ScheduleEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<bool> _days = List.filled(7, false);
  List<String> _apps = [];
  int _selectedMode = 0; // 0: Normal, 1: Moderate, 2: Strict
  
  final List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    if (widget.profileId != null) {
      _loadScheduleData();
    }
  }

  // --- Data Logic (Koi change nahi) ---
  
  Future<void> _loadScheduleData() async {
    final profilesBox = Hive.box('focusProfiles');
    final profileData = profilesBox.get(widget.profileId) as Map?;
    if (profileData != null) {
      setState(() {
        _nameController.text = profileData['name'] ?? '';
        _apps = (profileData['apps'] as List?)?.cast<String>() ?? [];
        _days = (profileData['days'] as List?)?.cast<bool>() ?? List.filled(7, false);
        _selectedMode = profileData['mode'] ?? 0;
        if (profileData['startTime'] != null) {
          final timeParts = (profileData['startTime'] as String).split(':');
          _startTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
        }
        if (profileData['endTime'] != null) {
          final timeParts = (profileData['endTime'] as String).split(':');
          _endTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
        }
      });
    }
  }

  Future<void> _saveSchedule() async {
    if (_formKey.currentState!.validate()) {
      final profilesBox = Hive.box('focusProfiles');
      final profileId = widget.profileId ?? DateTime.now().millisecondsSinceEpoch.toString();

      final profileData = {
        'name': _nameController.text,
        'icon': _nameController.text.toLowerCase().split(' ').first,
        'startTime': _startTime != null ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}' : '00:00',
        'endTime': _endTime != null ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' : '00:00',
        'days': _days,
        'apps': _apps,
        'isEnabled': true,
        'mode': _selectedMode,
      };

      await profilesBox.put(profileId, profileData);
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- NAYA BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00020C), 
      appBar: AppBar(
        title: Text(
          widget.profileId == null ? 'Create Schedule' : 'Edit Schedule',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // --- BODY AB COLUMN/EXPANDED NAHI, SIRF SCROLL VIEW HAI ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              // --- Schedule Name (No change) ---
              _buildSectionHeader('Schedule Name'),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                decoration: _buildInputDecoration('e.g. "Office Work"'),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // --- Time Pickers (No change) ---
              _buildSectionHeader('Time'),
              Row(
                children: [
                  _buildGlassTimePicker(
                    'Start Time',
                    _startTime,
                    (time) => setState(() => _startTime = time),
                  ),
                  const SizedBox(width: 16),
                  _buildGlassTimePicker(
                    'End Time',
                    _endTime,
                    (time) => setState(() => _endTime = time),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Day Selector (No change) ---
              _buildSectionHeader('Repeat on'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  return _buildDayToggle(_dayLabels[index], index);
                }),
              ),
              const SizedBox(height: 24),

              // --- App Selector (No change) ---
              _buildSectionHeader('Apps'),
              _buildAppSelectorCard(),
              const SizedBox(height: 24),
              
              // --- YAHAN CHANGE HUA: Blocking Mode section ab form ka hissa hai ---
              _buildModeSection(),
              
              const SizedBox(height: 32), // Save button se pehle space
              
              // --- YAHAN CHANGE HUA: Save Button bhi ab form ka hissa hai ---
              _buildSaveButton(),
              
              const SizedBox(height: 40), // Scroll ke end me extra space
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  /// Section Header ke liye (No change)
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white.withOpacity(0.8),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Naya Glassy Time Picker Card (No change)
  Widget _buildGlassTimePicker(String label, TimeOfDay? time, Function(TimeOfDay) onTimeChanged) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final selectedTime = await showTimePicker(
            context: context,
            initialTime: time ?? TimeOfDay.now(),
            builder: (context, child) {
              return Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.blueAccent,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1A1C2A),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF0F111E),
                ),
                child: child!,
              );
            },
          );
          if (selectedTime != null) {
            onTimeChanged(selectedTime);
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    time?.format(context) ?? 'Not Set',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
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

  /// Naya Day Toggle Button (No change)
  Widget _buildDayToggle(String day, int index) {
    bool isSelected = _days[index];
    return GestureDetector(
      onTap: () {
        setState(() => _days[index] = !_days[index]);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.blueAccent : const Color(0xFF1A1C2A),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Center(
          child: Text(
            day,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// Naya Glassy App Selector Card (No change)
  Widget _buildAppSelectorCard() {
    return GestureDetector(
      onTap: () async {
        final selectedApps = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(builder: (context) => const HomePage(isSelectionMode: true)),
        );
        if (selectedApps != null && selectedApps['selectedApps'] is List) {
          setState(() {
            _apps = (selectedApps['selectedApps'] as List).cast<String>();
          });
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                        'Blocked Apps',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_apps.length} apps selected',
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
    );
  }

  /// Standard Input Field ka Style (No change)
  InputDecoration _buildInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      filled: true,
      fillColor: const Color(0xFF1A1C2A), 
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none, 
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      counterStyle: const TextStyle(color: Colors.white70),
    );
  }
  
  // --- YE FUNCTION HATA DIYA ---
  // Widget _buildBottomBar() { ... }
  
  // --- NAYA FUNCTION: Sirf Mode buttons ke liye ---
  Widget _buildModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Blocking Mode'),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildModeButton('Normal', 0, Colors.green),
            _buildModeButton('Moderate', 1, Colors.orange),
            _buildModeButton('Strict', 2, Colors.red),
          ],
        ),
      ],
    );
  }

  /// Mode Button (No change)
  Widget _buildModeButton(String label, int index, Color color) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFF1A1C2A),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Naya Gradient Save Button (No change)
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _saveSchedule,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.blueAccent, Color(0xFF007FFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'Save Schedule',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// --- CustomTimePicker Code (Ise chheda nahi hai) ---
class CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePicker({Key? key, required this.initialTime}) : super(key: key);

  @override
  _CustomTimePickerState createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late String _period;

  @override
  void initState() {
    super.initState();
    _hourController = TextEditingController(text: widget.initialTime.hourOfPeriod.toString());
    if (widget.initialTime.hourOfPeriod == 0) {
      _hourController.text = '12';
    }
    _minuteController = TextEditingController(text: widget.initialTime.minute.toString().padLeft(2, '0'));
    _period = widget.initialTime.period == DayPeriod.am ? 'AM' : 'PM';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: TextField(
              controller: _hourController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          const Text(':'),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _minuteController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 16),
          ToggleButtons(
            isSelected: [_period == 'AM', _period == 'PM'],
            onPressed: (index) {
              setState(() {
                _period = index == 0 ? 'AM' : 'PM';
              });
            },
            children: const [Text('AM'), Text('PM')],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            int hour = int.tryParse(_hourController.text) ?? 0;
            final int minute = int.tryParse(_minuteController.text) ?? 0;
            if (_period == 'PM' && hour != 12) {
              hour += 12;
            }
            if (_period == 'AM' && hour == 12) {
              hour = 0;
            }
            Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute));
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}