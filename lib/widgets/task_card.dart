import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/auto_task.dart';
import '../theme/app_theme.dart';

class TaskCard extends StatelessWidget {
  final AutoTask task;
  final Isar isar;
  final VoidCallback onRefresh;

  const TaskCard({super.key, required this.task, required this.isar, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;

    switch (task.taskType) {
      case 'whatsapp':
        icon = Icons.chat;
        iconColor = Colors.green;
        break;
      case 'instagram':
        icon = Icons.camera_alt;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.api;
        iconColor = AppTheme.primaryBlue;
    }

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Target: ${task.target ?? "None"}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
            ),
            const SizedBox(height: 2),
            Text(
              'Scheduled: ${TimeOfDay.fromDateTime(task.scheduledTime).format(context)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.isCompleted)
              const Icon(Icons.check_circle, color: AppTheme.accentGreen),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Task'),
                    content: const Text('Are you sure you want to delete this task?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await isar.writeTxn(() async {
                            await isar.autoTasks.delete(task.id);
                          });
                          onRefresh();
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
    );
  }
}
