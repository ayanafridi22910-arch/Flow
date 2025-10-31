import 'package:flow/screens/home_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
  bool _isEnabled = false;

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
        _isEnabled = profileData['isEnabled'] ?? false;
        _apps = (profileData['apps'] as List?)?.cast<String>() ?? [];
        _days = (profileData['days'] as List?)?.cast<bool>() ?? List.filled(7, false);
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
        'icon': _nameController.text.toLowerCase().split(' ').first, // Use first word as icon key
        'startTime': _startTime != null ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}' : '00:00',
        'endTime': _endTime != null ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' : '00:00',
        'days': _days,
        'apps': _apps,
        'isEnabled': _isEnabled,
      };

      await profilesBox.put(profileId, profileData);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profileId == null ? 'Create Schedule' : 'Edit Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSchedule,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Schedule Name'),
                maxLength: 50,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('Start Time'),
                      subtitle: Text(_startTime?.format(context) ?? 'Not Set'),
                      onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                        if (time != null) {
                          setState(() => _startTime = time);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('End Time'),
                      subtitle: Text(_endTime?.format(context) ?? 'Not Set'),
                      onTap: () async {
                        final time = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay.now());
                        if (time != null) {
                          setState(() => _endTime = time);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Repeat on'),
              Wrap(
                spacing: 8.0,
                children: List.generate(7, (index) {
                  final day = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index];
                  return FilterChip(
                    label: Text(day),
                    selected: _days[index],
                    onSelected: (selected) {
                      setState(() => _days[index] = selected);
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Blocked Apps'),
                subtitle: Text('${_apps.length} apps selected'),
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
              ),
              SwitchListTile(
                title: const Text('Enabled'),
                value: _isEnabled,
                onChanged: (value) => setState(() => _isEnabled = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
