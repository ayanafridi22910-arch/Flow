import 'package:flow/screens/app_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:ui';

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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionHeader('Schedule Name'),
                    _buildNameField(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Time'),
                    Row(
                      children: [
                        _buildGlassTimePicker(
                          'Start Time',
                          _startTime,
                          Colors.greenAccent,
                          (time) => setState(() => _startTime = time),
                        ),
                        const SizedBox(width: 16),
                        _buildGlassTimePicker(
                          'End Time',
                          _endTime,
                          Colors.orangeAccent,
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
                  ],
                ),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: _nameController,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Office Work',
              hintStyle: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.5),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              counterText: "",
            ),
            maxLength: 50,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12.0,
        left: (title == 'Schedule Title') ? 4.0 : 0.0,
      ),
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

  Widget _buildGlassTimePicker(String label, TimeOfDay? time, Color tintColor, Function(TimeOfDay) onTimeChanged) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final selectedTime = await showTimePicker(
            context: context,
            initialTime: time ?? TimeOfDay.now(),
            initialEntryMode: TimePickerEntryMode.input,
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
                color: tintColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tintColor.withOpacity(0.3)),
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
        final selectedApps = await Navigator.push<List<String>>(
          context,
          MaterialPageRoute(
            builder: (context) => AppSelectionPage(
              previouslySelectedApps: _apps,
            ),
          ),
        );

        if (selectedApps != null) {
          setState(() {
            _apps = selectedApps;
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeSection(),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
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
    return ElevatedButton.icon(
      onPressed: _saveSchedule,
      icon: const Icon(Icons.save),
      label: const Text('Save Schedule'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
