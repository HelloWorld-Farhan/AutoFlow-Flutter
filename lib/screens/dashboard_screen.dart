import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/auto_task.dart';
import '../theme/app_theme.dart';
import 'create_task_screen.dart';
import '../widgets/task_card.dart';

class DashboardScreen extends StatefulWidget {
  final Isar isar;

  const DashboardScreen({super.key, required this.isar});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<AutoTask> _tasks = [];
  bool _isAccessibilityEnabled = true;
  static const platform = MethodChannel('com.helloworld.autoflow/automation');

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final bool isEnabled = await platform.invokeMethod('checkAccessibilityPermission');
      setState(() {
        _isAccessibilityEnabled = isEnabled;
      });
    } catch (e) {
      print("Error checking permissions: \$e");
    }
  }

  Future<void> _requestPermission() async {
    try {
      await platform.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      print("Error requesting permission: \$e");
    }
  }

  Future<void> _loadTasks() async {
    final tasks = await widget.isar.autoTasks.where().sortByScheduledTimeDesc().findAll();
    setState(() {
      _tasks = tasks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 12),
            const Text('AutoFlow'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Settings screen stub
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (!_isAccessibilityEnabled)
            Container(
              color: Colors.amber.shade100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Accessibility permission is required for background automation.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  TextButton(
                    onPressed: _requestPermission,
                    child: const Text('ENABLE'),
                  )
                ],
              ),
            ),
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 64, color: AppTheme.primaryBlue.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks scheduled',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textLight,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to create a new automation.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ).animate().fade(duration: 500.ms).scale(curve: Curves.easeOutBack),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskCard(task: task, isar: widget.isar, onRefresh: _loadTasks),
                      ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTaskScreen(isar: widget.isar),
            ),
          );
          _loadTasks();
        },
      ).animate().scale(delay: 300.ms),
    );
  }
}
