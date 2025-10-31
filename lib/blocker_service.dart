import 'package:hive/hive.dart';
import 'package:flow/native_blocker.dart';

class BlockerService {
  static Future<void> updateNativeBlocker() async {
    final blockerBox = await Hive.openBox('blockerState');
    Set<String> appsToBlock = {};

    // 1. Add apps from the main focus session if it's active
    if (blockerBox.get('is_blocking_active') == true) {
      appsToBlock.addAll((blockerBox.get('selected_blocked_apps') as List?)?.cast<String>() ?? []);
    }

    // 2. Add apps from expired app limits (permanently blocked)
    appsToBlock.addAll((blockerBox.get('permanently_blocked_apps') as List?)?.cast<String>() ?? []);

    // 3. Add apps from total block mode if it's active
    if (blockerBox.get('is_total_block_active') == true) {
      appsToBlock.addAll((blockerBox.get('total_block_apps') as List?)?.cast<String>() ?? []);
    }

    // Send the final, combined list to the native side
    NativeBlocker.setBlockedApps(appsToBlock.toList());
  }
}
