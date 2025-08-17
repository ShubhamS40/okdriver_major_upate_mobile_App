import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'android14_storage_helper.dart';

class PermissionTest {
  static Future<void> testStoragePermissions() async {
    print('=== Android 14 Storage Permission Test ===');
    print('Platform: ${Platform.operatingSystem}');
    print('OS Version: ${Platform.operatingSystemVersion}');
    print('Is Android 14: ${Android14StorageHelper.isAndroid14}');
    print('Is Android 13+: ${Android14StorageHelper.isAndroid13Plus}');

    if (Platform.isAndroid) {
      final storagePermissions = Android14StorageHelper.getStoragePermissions();
      print(
          'Required storage permissions: ${storagePermissions.map((p) => p.toString())}');

      // Check current status
      for (final permission in storagePermissions) {
        final status = await permission.status;
        print('${permission.toString()}: $status');
      }

      // Test permission request
      print('\n--- Testing Permission Request ---');
      final results = await Android14StorageHelper.requestStoragePermissions();
      for (final entry in results.entries) {
        print('${entry.key.toString()}: ${entry.value}');
      }

      // Check if all granted
      final allGranted =
          await Android14StorageHelper.areStoragePermissionsGranted();
      print('All storage permissions granted: $allGranted');

      // Test storage directory
      final storageDir = await Android14StorageHelper.getAppStorageDirectory();
      print('Storage directory: $storageDir');

      if (storageDir != null) {
        final dir = Directory(storageDir);
        final exists = await dir.exists();
        print('Directory exists: $exists');

        if (exists) {
          final files = await dir.list().toList();
          print('Files in directory: ${files.length}');
        }
      }
    } else {
      print('Not running on Android');
    }

    print('=== Test Complete ===');
  }
}
