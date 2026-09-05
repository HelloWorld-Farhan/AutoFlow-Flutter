import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'models/auto_task.dart';
import 'models/history_model.dart';
import 'models/macro_model.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: \$task");
    
    if (task == "execute_auto_task") {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final isar = await Isar.open(
          [AutoTaskSchema, TaskHistorySchema, MacroModelSchema],
          directory: dir.path,
        );

        final taskId = inputData?['taskId'] as int?;
        if (taskId != null) {
          final autoTask = await isar.autoTasks.get(taskId);
          if (autoTask != null) {
            print("Executing task: \${autoTask.title}");
            
            bool success = false;
            String? errorMsg;
            
            try {
              // We now use native ExactAlarmReceiver to trigger the actual automation!
              // Workmanager is only used to log to history and reschedule recurring tasks
              // because exact alarms can't easily write to Flutter's Isar DB.
              success = true;
            } catch (e) {
              print("Failed to trigger native automation: \$e");
              errorMsg = e.toString();
            }
            
            // Log History
            final log = TaskHistory()
              ..taskId = autoTask.id
              ..taskTitle = autoTask.title
              ..taskType = autoTask.taskType
              ..success = success
              ..errorMessage = errorMsg
              ..executedAt = DateTime.now();
              
            await isar.writeTxn(() async {
              await isar.taskHistorys.put(log);
              
              if (autoTask.isRecurring) {
                // Reschedule for tomorrow
                autoTask.scheduledTime = autoTask.scheduledTime.add(const Duration(days: 1));
                await isar.autoTasks.put(autoTask);
                
                // Re-register workmanager
                final delay = autoTask.scheduledTime.difference(DateTime.now());
                Workmanager().registerOneOffTask(
                  "task_\${autoTask.id}_\${DateTime.now().millisecondsSinceEpoch}",
                  "execute_auto_task",
                  initialDelay: delay,
                  inputData: {'taskId': autoTask.id},
                );
              } else {
                autoTask.isCompleted = true;
                await isar.autoTasks.put(autoTask);
              }
            });
          }
        }
        await isar.close();
      } catch (e) {
        print("Error in background task: \$e");
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [AutoTaskSchema, TaskHistorySchema, MacroModelSchema],
    directory: dir.path,
  );

  runApp(AutoFlowApp(isar: isar));
}

class AutoFlowApp extends StatelessWidget {
  final Isar isar;
  const AutoFlowApp({super.key, required this.isar});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: LockScreen(
        child: DashboardScreen(isar: isar),
      ),
    );
  }
}
