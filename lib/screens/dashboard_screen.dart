import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/auto_task.dart';
import '../models/history_model.dart';
import '../theme/app_theme.dart';
import 'create_task_screen.dart';
import 'onboarding_screen.dart';
import 'lockscreen_config_screen.dart';
import 'lock_screen.dart';
import '../widgets/task_card.dart';
import '../widgets/platform_selector_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final Isar isar;

  const DashboardScreen({super.key, required this.isar});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<AutoTask> _tasks = [];
  List<TaskHistory> _history = [];
  bool _allPermissionsGranted = true;
  static const platform = MethodChannel('com.helloworld.autoflow/automation');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final bool isAccessibility = await platform.invokeMethod('checkAccessibilityPermission');
      final bool isOverlay = await Permission.systemAlertWindow.isGranted;
      final bool isContacts = await Permission.contacts.isGranted;
      final bool isBattery = await Permission.ignoreBatteryOptimizations.isGranted;
      
      setState(() {
        _allPermissionsGranted = isAccessibility && isOverlay && isContacts && isBattery;
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

  Future<void> _loadData() async {
    final tasks = await widget.isar.autoTasks.where().sortByScheduledTimeDesc().findAll();
    final history = await widget.isar.taskHistorys.where().sortByExecutedAtDesc().findAll();
    setState(() {
      _tasks = tasks;
      _history = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_allPermissionsGranted) {
      return OnboardingScreen(
        onFinished: _checkPermissions,
      );
    }

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
            icon: const Icon(Icons.security_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OnboardingScreen(onFinished: () {
                    Navigator.pop(context);
                    _checkPermissions();
                  }),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LockScreen(
                    child: const LockscreenConfigScreen(),
                  ),
                ),
              );
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Upcoming Tasks'),
            Tab(text: 'History Logs'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TASKS TAB
                _tasks.isEmpty
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
                            child: TaskCard(task: task, isar: widget.isar, onRefresh: _loadData),
                          ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
                        },
                      ),
                
                // HISTORY TAB
                _history.isEmpty
                    ? Center(
                        child: Text(
                          'No history available yet.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final log = _history[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppTheme.cardWhite,
                            elevation: 2,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Icon(
                                log.success ? Icons.check_circle : Icons.error,
                                color: log.success ? Colors.green : Colors.red,
                              ),
                              title: Text(log.taskTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                log.success ? 'Executed Successfully' : (log.errorMessage ?? 'Failed'),
                                style: TextStyle(color: log.success ? Colors.green : Colors.red),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${log.executedAt.hour}:${log.executedAt.minute.toString().padLeft(2, '0')}\n${log.executedAt.day}/${log.executedAt.month}",
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete History'),
                                          content: const Text('Are you sure you want to delete this log?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                await widget.isar.writeTxn(() async {
                                                  await widget.isar.taskHistorys.delete(log.id);
                                                });
                                                _loadData();
                                              },
                                              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fade().slideY(begin: 0.1, end: 0);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final String? platformType = await PlatformSelectorSheet.show(context, widget.isar);
          if (platformType != null && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateTaskScreen(isar: widget.isar, platformType: platformType),
              ),
            );
            _loadData();
          }
        },
      ).animate().scale(delay: 300.ms),
    );
  }
}
