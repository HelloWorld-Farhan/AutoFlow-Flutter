import 'package:isar/isar.dart';

part 'macro_model.g.dart';

@collection
class MacroModel {
  Id id = Isar.autoIncrement;

  late String name;
  
  /// JSON encoded list of gestures/actions
  /// Format: [{"x": 100, "y": 200, "delayMs": 500, "type": "tap"}, ...]
  late String actionsJson;

  DateTime createdAt = DateTime.now();
}
