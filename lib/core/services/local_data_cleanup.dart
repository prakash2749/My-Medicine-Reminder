import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Only this app's named report files; never remove another plugin's cache.
Future<void> clearMedicineReports() async {
  if (kIsWeb) return;
  final root = await getTemporaryDirectory();
  for (final directory in [root, Directory(p.join(root.path, 'share'))]) {
    if (!await directory.exists()) continue;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File &&
          p.basename(entry.path).startsWith('medicine-report-') &&
          p.extension(entry.path) == '.pdf') {
        await entry.delete();
      }
    }
  }
}

Future<void> clearLocalMedicineArtifacts() async {
  if (!kIsWeb &&
      [TargetPlatform.android, TargetPlatform.iOS]
          .contains(defaultTargetPlatform)) {
    await FlutterLocalNotificationsPlugin().cancelAll();
  }
  await clearMedicineReports();
}
