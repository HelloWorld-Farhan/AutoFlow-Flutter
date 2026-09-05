import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'models/auto_task.dart';

// Top-level function for Workmanager background execution
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    
    // In a real app with native automation (AccessibilityService), 
    // we would trigger MethodChannels here to tell the native side to execute.
    // Since this is a Flutter-only stub, we just print and mark as done.
    
    if (task == "execute_auto_task") {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final isar = await Isar.open(
          [AutoTaskSchema],
          directory: dir.path,
        );

        final taskId = inputData?['taskId'] as int?;
        if (taskId != null) {
          final autoTask = await isar.autoTasks.get(taskId);
          if (autoTask != null) {
            print("Executing task: ${autoTask.title}");
            
            // Trigger the native Accessibility Service via MethodChannel
            if (autoTask.taskType == 'whatsapp' && autoTask.target != null && autoTask.payload != null) {
              const platform = MethodChannel('com.helloworld.autoflow/automation');
              try {
                await platform.invokeMethod('executeWhatsAppAutomation', {
                  'contact': autoTask.target,
                  'message': autoTask.payload,
                });
                print("Triggered Native WhatsApp Automation");
              } catch (e) {
                print("Failed to trigger native automation: \$e");
              }
            }
            
            // Mark as completed
            await isar.writeTxn(() async {
              autoTask.isCompleted = true;
              await isar.autoTasks.put(autoTask);
            });
          }
        }
        await isar.close();
      } catch (e) {
        print("Error in background task: $e");
      }
    }
    return Future.value(true);
  });
}

late Isar isar;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set status bar color
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Show notifications when task runs
  );

  // Initialize Isar
  final dir = await getApplicationDocumentsDirectory();
  isar = await Isar.open(
    [AutoTaskSchema],
    directory: dir.path,
  );

  runApp(const AutoFlowApp());
}

class AutoFlowApp extends StatelessWidget {
  const AutoFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoFlow',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: DashboardScreen(isar: isar),
    );
  }
}
