import 'package:isar/isar.dart';

part 'history_model.g.dart';

@collection
class TaskHistory {
  Id id = Isar.autoIncrement;

  late int taskId;
  late String taskTitle;
  late String taskType;
  
  late bool success;
  String? errorMessage;
  
  DateTime executedAt = DateTime.now();
}
