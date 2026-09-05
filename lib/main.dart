import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'models/auto_task.dart';
import 'screens/dashboard_screen.dart';
import 'screens/lock_screen.dart';
import 'package:system_alert_window/system_alert_window.dart';

// Top-level function for Workmanager background execution
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    
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
            
            // Show Countdown Overlay
            SystemWindowHeader header = SystemWindowHeader(
              title: SystemWindowText(text: "Automation Starting", fontSize: 20, fontWeight: FontWeight.BOLD, textColor: Colors.black45),
              decoration: SystemWindowDecoration(startColor: Colors.grey[100]),
            );
            SystemWindowBody body = SystemWindowBody(
              rows: [
                EachRow(
                  columns: [
                    EachColumn(
                      text: SystemWindowText(text: "Executing: ${autoTask.title}", fontSize: 16, textColor: Colors.black45),
                    ),
                  ],
                  gravity: ContentGravity.CENTER,
                ),
              ],
              padding: SystemWindowPadding(left: 16, right: 16, bottom: 12, top: 12),
            );
            SystemWindowFooter footer = SystemWindowFooter(
              buttons: [
                SystemWindowButton(
                  text: SystemWindowText(text: "CANCEL", fontSize: 14, textColor: Colors.white),
                  tag: "cancel_automation",
                  width: 0,
                  height: SystemWindowButton.WRAP_CONTENT,
                  decoration: SystemWindowDecoration(startColor: Colors.red, endColor: Colors.redAccent, borderRadius: 12.0),
                )
              ],
              padding: SystemWindowPadding(left: 16, right: 16, bottom: 12),
              decoration: SystemWindowDecoration(startColor: Colors.white),
              buttonsPosition: ButtonPosition.CENTER
            );

            SystemAlertWindow.showSystemWindow(
                height: 230,
                header: header,
                body: body,
                footer: footer,
                margin: SystemWindowMargin(left: 8, right: 8, top: 100, bottom: 0),
                gravity: SystemWindowGravity.TOP,
                notificationTitle: "AutoFlow Running",
                notificationBody: "Automation is starting in 5 seconds...",
            );

            // Wait 5 seconds
            await Future.delayed(const Duration(seconds: 5));
            
            // Close overlay
            SystemAlertWindow.closeSystemWindow();
            
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
class AutoFlowApp extends StatelessWidget {
  const AutoFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoFlow',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: LockScreen(isar: isar),
    );
  }
}
