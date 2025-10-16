import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ResetService {
  static Future<void> clearAllData() async {
    try {
      await Hive.box('categoriesBox').clear();
      await Hive.box('skillsBox').clear();
      await Hive.box('statsBox').clear();
      await Hive.box('objectivesBox').clear();
      await Hive.box('statHistoryBox').clear();
      await Hive.box('milestonesBox').clear();
      debugPrint('✅ All Hive data cleared successfully.');
    } catch (e) {
      debugPrint('❌ Error clearing Hive data: $e');
    }
  }
}
