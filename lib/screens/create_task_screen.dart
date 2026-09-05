import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/auto_task.dart';
import '../theme/app_theme.dart';

class CreateTaskScreen extends StatefulWidget {
  final Isar isar;
  const CreateTaskScreen({super.key, required this.isar});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _payloadController = TextEditingController();
  String _selectedType = 'whatsapp';
  DateTime _scheduledTime = DateTime.now().add(const Duration(minutes: 5));

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
    );
    if (pickedTime != null) {
      final now = DateTime.now();
      setState(() {
        _scheduledTime = DateTime(
          now.year, now.month, now.day, pickedTime.hour, pickedTime.minute,
        );
        // If time is in the past, schedule for tomorrow
        if (_scheduledTime.isBefore(now)) {
          _scheduledTime = _scheduledTime.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final task = AutoTask()
      ..title = _titleController.text.trim()
      ..taskType = _selectedType
      ..scheduledTime = _scheduledTime
      ..target = _targetController.text.trim()
      ..payload = _payloadController.text.trim();

    await widget.isar.writeTxn(() async {
      await widget.isar.autoTasks.put(task);
    });

    // Schedule background task using Workmanager
    final delay = _scheduledTime.difference(DateTime.now());
    if (delay.isNegative) return;

    Workmanager().registerOneOffTask(
      "task_${task.id}",
      "execute_auto_task",
      initialDelay: delay,
      inputData: {'taskId': task.id},
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('New Automation'),
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
            
            Text('Platform', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                    DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                    DropdownMenuItem(value: 'workflow', child: Text('Custom Workflow')),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Target (Contact / Username)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                try {
                  if (await FlutterContacts.requestPermission()) {
                    final Contact? contact = await FlutterContacts.openExternalPick();
                    if (contact != null) {
                      setState(() {
                        _targetController.text = contact.displayName;
                      });
                    }
                  }
                } catch (e) {
                  print('Error picking contact: \$e');
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
                        _targetController.text.isEmpty ? 'Select Recipient from Contacts' : _targetController.text,
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

            Text('Scheduled Time', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
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
                    const Icon(Icons.access_time, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Text(
                      TimeOfDay.fromDateTime(_scheduledTime).format(context),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
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
