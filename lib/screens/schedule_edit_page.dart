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

  // --- Data Logic (No change) ---
  
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

  // --- Build Method (No change) ---

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              _buildSectionHeader('Schedule Name'),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
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

              _buildSectionHeader('Repeat on'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  return _buildDayToggle(_dayLabels[index], index);
                }),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Apps'),
              _buildAppSelectorCard(),
              const SizedBox(height: 24),
              
              _buildModeSection(),
              
              const SizedBox(height: 32),
              
              _buildSaveButton(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

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

  // --- YAHAN BADA CHANGE HUA ---
  /// Naya Glassy Time Picker Card (Ab Custom Dialog Kholega)
  Widget _buildGlassTimePicker(String label, TimeOfDay? time, Function(TimeOfDay) onTimeChanged) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          // --- Default showTimePicker ki jagah Custom showDialog ---
          final selectedTime = await showDialog<TimeOfDay>(
            context: context,
            builder: (BuildContext context) {
              return _CustomTimeSelectorDialog(initialTime: time ?? TimeOfDay.now());
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
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                    // Time ko 12-hour format me dikhane ke liye
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

  InputDecoration _buildInputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70),
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

// --- YAHAN POORA CHANGE HUA: Puraana CustomTimePicker hata kar naya spinner wala dialog ---

class _CustomTimeSelectorDialog extends StatefulWidget {
  final TimeOfDay initialTime;

  const _CustomTimeSelectorDialog({required this.initialTime});

  @override
  _CustomTimeSelectorDialogState createState() => _CustomTimeSelectorDialogState();
}

class _CustomTimeSelectorDialogState extends State<_CustomTimeSelectorDialog> {
  late int _selectedHour; // 1-12
  late int _selectedMinute;
  late bool _isAM;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  
  // Hour ko 12-format me convert karna
  int _getHourIn12(int hour) {
    if (hour == 0) return 12; // 12 AM
    if (hour > 12) return hour - 12; // PM hours
    return hour;
  }
  
  // AM hai ya PM check karna
  bool _isAm(int hour) {
    return hour < 12;
  }

  @override
  void initState() {
    super.initState();
    _selectedHour = _getHourIn12(widget.initialTime.hour);
    _selectedMinute = widget.initialTime.minute;
    _isAM = _isAm(widget.initialTime.hour);

    // Controller ko initial value pe set karna (index 0-based hota hai)
    _hourController = FixedExtentScrollController(initialItem: _selectedHour - 1); // 1-12 hai, isliye -1
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute);
  }
  
  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _onSave() {
    // Wapas 24-hour format me convert karna
    int hourIn24;
    if (_isAM) {
      hourIn24 = (_selectedHour == 12) ? 0 : _selectedHour; // 12 AM -> 0
    } else {
      hourIn24 = (_selectedHour == 12) ? 12 : _selectedHour + 12; // 12 PM -> 12, 1 PM -> 13
    }
    
    final selectedTime = TimeOfDay(hour: hourIn24, minute: _selectedMinute);
    Navigator.of(context).pop(selectedTime);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Background transparent rakha
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C2A).withOpacity(0.8), // Glassy color
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Time',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                // --- Spinner UI ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hour Spinner
                    _buildSpinner(
                      controller: _hourController,
                      itemCount: 12,
                      onChanged: (index) {
                        setState(() {
                          _selectedHour = index + 1; // 0-11 index -> 1-12 value
                        });
                      },
                      // List 1 se 12 tak
                      labels: List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')),
                    ),
                    Text(":", style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600)),
                    // Minute Spinner
                    _buildSpinner(
                      controller: _minuteController,
                      itemCount: 60,
                      onChanged: (index) {
                        setState(() {
                          _selectedMinute = index;
                        });
                      },
                      // List 00 se 59 tak
                      labels: List.generate(60, (i) => i.toString().padLeft(2, '0')),
                    ),
                    const SizedBox(width: 16),
                    // AM/PM Toggle
                    _buildAmPmToggle(),
                  ],
                ),
                const SizedBox(height: 24),
                // --- Action Buttons ---
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
  
  /// AM/PM Toggle ke liye
  Widget _buildAmPmToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAmPmButton('AM', _isAM),
        const SizedBox(height: 8),
        _buildAmPmButton('PM', !_isAM),
      ],
    );
  }
  
  Widget _buildAmPmButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAM = (label == 'AM');
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Spinner wheel ke liye
  Widget _buildSpinner({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onChanged,
    required List<String> labels,
  }) {
    return Container(
      width: 70,
      height: 120,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 50, // Har item ki height
        perspective: 0.005,
        diameterRatio: 1.2,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) {
            final label = labels[index];
            // Check if this item is selected
            final bool isSelected = (controller.hasClients && controller.selectedItem == index);
            
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: GoogleFonts.poppins(
                  fontSize: isSelected ? 28 : 22,
                  color: isSelected ? Colors.white : Colors.white54,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(label),
              ),
            );
          },
        ),
      ),
    );
  }
}