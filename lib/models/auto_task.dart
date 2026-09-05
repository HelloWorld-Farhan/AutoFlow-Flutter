import 'package:isar/isar.dart';

part 'auto_task.g.dart';

@collection
class AutoTask {
  Id id = Isar.autoIncrement;

  late String title;
  
  /// e.g. "whatsapp", "instagram", "custom_workflow"
  late String taskType;

  /// The time it should be executed
  late DateTime scheduledTime;

  /// e.g. the phone number, or the instagram username
  String? target;

  /// e.g. the message to send
  String? payload;

  bool isCompleted = false;
  
  /// True if this task repeats daily
  bool isRecurring = false;
  
  /// If taskType is custom_workflow, this points to the recorded macro
  int? macroId;

  DateTime createdAt = DateTime.now();
}
