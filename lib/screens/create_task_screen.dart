import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../models/auto_task.dart';
import '../theme/app_theme.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class CreateTaskScreen extends StatefulWidget {
  final Isar isar;
  final String platformType;
  
  const CreateTaskScreen({super.key, required this.isar, required this.platformType});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _payloadController = TextEditingController();
  DateTime _scheduledDate = DateTime.now();
  TimeOfDay _scheduledTime = TimeOfDay.now().replacing(minute: TimeOfDay.now().minute + 5 > 59 ? 59 : TimeOfDay.now().minute + 5);
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _targetController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPickedContact();
    }
  }

  Future<void> _checkPickedContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final picked = prefs.getString('flutter_contact_picked');
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _targetController.text = picked;
      });
      await prefs.remove('flutter_contact_picked');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        _scheduledDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (pickedTime != null) {
      setState(() {
        _scheduledTime = pickedTime;
      });
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    DateTime finalScheduledTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );
    
    if (finalScheduledTime.isBefore(DateTime.now())) {
      finalScheduledTime = finalScheduledTime.add(const Duration(days: 1));
    }

    final task = AutoTask()
      ..title = _titleController.text.trim()
      ..taskType = widget.platformType
      ..scheduledTime = finalScheduledTime
      ..target = _targetController.text.trim()
      ..payload = _payloadController.text.trim()
      ..isRecurring = _isRecurring;

    await widget.isar.writeTxn(() async {
      await widget.isar.autoTasks.put(task);
    });

    final String actionPayload = '''
    {
      "taskType": "${task.taskType}",
      "target": "${task.target}",
      "payload": "${task.payload ?? ''}",
      "macroId": ${task.macroId ?? -1},
      "timestamp": ${DateTime.now().millisecondsSinceEpoch}
    }
    ''';

    const platform = MethodChannel('com.helloworld.autoflow/automation');
    try {
      await platform.invokeMethod('scheduleExactTask', {
        'taskId': task.id,
        'timeInMillis': finalScheduledTime.millisecondsSinceEpoch,
        'payload': actionPayload
      });
    } catch (e) {
      print("Failed to schedule exact task: $e");
    }

    final delay = finalScheduledTime.difference(DateTime.now());
    if (!delay.isNegative) {
      Workmanager().registerOneOffTask(
        "task_${task.id}",
        "execute_auto_task",
        initialDelay: delay,
        inputData: {'taskId': task.id},
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text('New ${widget.platformType[0].toUpperCase()}${widget.platformType.substring(1)} Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task Title', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Good Morning Message',
                filled: true,
                fillColor: AppTheme.cardWhite,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.platformType == 'whatsapp' ? Icons.message :
                    widget.platformType == 'instagram' ? Icons.camera_alt :
                    widget.platformType == 'snapchat' ? Icons.camera :
                    widget.platformType == 'sms' ? Icons.sms :
                    widget.platformType == 'call' ? Icons.call : Icons.touch_app,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Platform: ${widget.platformType[0].toUpperCase()}${widget.platformType.substring(1)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (widget.platformType != 'workflow') ...[
              Text('Target (Contact / Username)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  if (widget.platformType == 'whatsapp' || widget.platformType == 'instagram' || widget.platformType == 'snapchat') {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.cardWhite,
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppTheme.primaryBlue),
                            const SizedBox(height: 24),
                            Text(
                              'Opening ${widget.platformType[0].toUpperCase()}${widget.platformType.substring(1)}...',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap any contact to select it!',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );

                    final platform = const MethodChannel('com.helloworld.autoflow/automation');
                    try {
                      await platform.invokeMethod('startContactPicker', {'platform': widget.platformType});
                    } catch (e) {
                      print('Error launching contact picker: $e');
                    }

                    if (mounted) {
                      Navigator.pop(context); // Close the dialog
                    }
                  } else {
                    try {
                      if (await Permission.contacts.request().isGranted) {
                        final Contact? contact = await FlutterContacts.native.showPicker();
                        if (contact != null) {
                          setState(() {
                            _targetController.text = contact.displayName ?? '';
                          });
                        }
                      }
                    } catch (e) {
                      print('Error picking contact: \$e');
                    }
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.contacts, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _targetController.text.isEmpty ? 'Select Recipient' : _targetController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: _targetController.text.isEmpty ? Colors.grey.shade500 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text('Payload / Message', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _payloadController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'What should the automation do or send?',
                  filled: true,
                  fillColor: AppTheme.cardWhite,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Text('Schedule', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppTheme.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM dd, yyyy').format(_scheduledDate),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: AppTheme.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _scheduledTime.format(context),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.repeat, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Repeat Daily'),
                const Spacer(),
                Switch(
                  value: _isRecurring,
                  activeColor: AppTheme.primaryBlue,
                  onChanged: (val) {
                    setState(() {
                      _isRecurring = val;
                    });
                  },
                )
              ],
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveTask,
                child: const Text('Schedule Automation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
