import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

class ScheduleTimingPage extends StatefulWidget {
  final String scheduleId;
  final String? initialTitle;
  final String? initialStartTime;
  final String? initialEndTime;
  final List<bool>? initialSelectedDays;
  final Set<String>? initialBlockedApps;

  const ScheduleTimingPage({
    super.key,
    required this.scheduleId,
    this.initialTitle,
    this.initialStartTime,
    this.initialEndTime,
    this.initialSelectedDays,
    this.initialBlockedApps,
  });

  @override
  State<ScheduleTimingPage> createState() => _ScheduleTimingPageState();
}

class _ScheduleTimingPageState extends State<ScheduleTimingPage> {
  final TextEditingController _titleController = TextEditingController();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<bool> _selectedDays = List.filled(7, false); // Mon to Sun
  Set<String> _blockedApps = {}; // Package names of blocked apps

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialStartTime != null) {
      _startTime = _timeOfDayFromString(widget.initialStartTime);
    }
    if (widget.initialEndTime != null) {
      _endTime = _timeOfDayFromString(widget.initialEndTime);
    }
    if (widget.initialSelectedDays != null) {
      _selectedDays = List.from(widget.initialSelectedDays!);
    }
    if (widget.initialBlockedApps != null) {
      _blockedApps = Set.from(widget.initialBlockedApps!);
    }
    _loadSchedule();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    final schedulesBox = Hive.box('schedules');
    final scheduleData = schedulesBox.get(widget.scheduleId);
    if (scheduleData != null && scheduleData is Map) {
      setState(() {
        _titleController.text = scheduleData['title'] ?? '';
        _startTime = _timeOfDayFromString(scheduleData['startTime']);
        _endTime = _timeOfDayFromString(scheduleData['endTime']);
        _selectedDays = List<bool>.from(scheduleData['selectedDays'] ?? List.filled(7, false));
        _blockedApps = (scheduleData['blockedApps'] as List?)?.cast<String>().toSet() ?? {};
      });
    }
  }

  TimeOfDay? _timeOfDayFromString(String? timeString) {
    if (timeString == null) return null;
    final parts = timeString.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _pickTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveSchedule() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the schedule.')),
      );
      return;
    }
    if (_startTime != null && _endTime != null) {
      final schedulesBox = Hive.box('schedules');
      final scheduleData = {
        'title': _titleController.text,
        'startTime': _startTime!.format(context),
        'endTime': _endTime!.format(context),
        'selectedDays': _selectedDays,
        'blockedApps': _blockedApps.toList(),
        'isEnabled': true, // Default to enabled when created
      };
      await schedulesBox.put(widget.scheduleId, scheduleData);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end times.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Set Schedule',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Schedule Title',
                labelStyle: GoogleFonts.poppins(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue.shade700),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Days:',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ToggleButtons(
              isSelected: _selectedDays,
              onPressed: (int index) {
                setState(() {
                  _selectedDays[index] = !_selectedDays[index];
                });
              },
              borderRadius: BorderRadius.circular(10),
              selectedColor: Colors.white,
              fillColor: Colors.blue.shade700,
              color: Colors.white70,
              borderColor: Colors.blue.shade700,
              selectedBorderColor: Colors.blue.shade700,
              children: const <Widget>[
                Padding(padding: EdgeInsets.all(8.0), child: Text('M')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('T')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('W')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('T')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('F')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('S')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('S')),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Select Start Time:',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _pickTime(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _startTime == null ? 'Pick Start Time' : _startTime!.format(context),
                style: GoogleFonts.poppins(fontSize: 18),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Select End Time:',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _pickTime(context, false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _endTime == null ? 'Pick End Time' : _endTime!.format(context),
                style: GoogleFonts.poppins(fontSize: 18),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Save Schedule',
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
