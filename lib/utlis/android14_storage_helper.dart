import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class Android14StorageHelper {
  static bool get isAndroid14 {
    if (!Platform.isAndroid) return false;
    try {
      final version = Platform.operatingSystemVersion;
      print('Android version string: $version');

      // Handle different version string formats
      if (version.contains('release-keys') || version.contains('user')) {
        // This is a build fingerprint, not a version number
        // We'll assume it's a recent Android version
        print('Detected build fingerprint, assuming Android 14');
        return true;
      }

      // Try to extract API level from version string
      final parts = version.split(' ');
      for (final part in parts) {
        final apiLevel = int.tryParse(part);
        if (apiLevel != null && apiLevel >= 34) {
          print('Detected Android API level: $apiLevel');
          return true;
        }
      }

      // If we can't parse the version, assume it's a recent Android version
      print('Could not parse Android version, assuming Android 14');
      return true;
    } catch (e) {
      print('Error parsing Android version: $e');
      // Default to assuming Android 14 for safety
      return true;
    }
  }

  static bool get isAndroid13Plus {
    if (!Platform.isAndroid) return false;
    try {
      final version = Platform.operatingSystemVersion;
      print('Android version string: $version');

      // Handle different version string formats
      if (version.contains('release-keys') || version.contains('user')) {
        // This is a build fingerprint, not a version number
        // We'll assume it's a recent Android version
        print('Detected build fingerprint, assuming Android 13+');
        return true;
      }

      // Try to extract API level from version string
      final parts = version.split(' ');
      for (final part in parts) {
        final apiLevel = int.tryParse(part);
        if (apiLevel != null && apiLevel >= 33) {
          print('Detected Android API level: $apiLevel');
          return true;
        }
      }

      // If we can't parse the version, assume it's a recent Android version
      print('Could not parse Android version, assuming Android 13+');
      return true;
    } catch (e) {
      print('Error parsing Android version: $e');
      // Default to assuming Android 13+ for safety
      return true;
    }
  }

  /// Get the appropriate storage permissions based on Android version
  static List<Permission> getStoragePermissions() {
    if (isAndroid13Plus) {
      return [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ];
    } else {
      return [Permission.storage];
    }
  }

  /// Request storage permissions with proper error handling
  static Future<Map<Permission, PermissionStatus>>
      requestStoragePermissions() async {
    final permissions = getStoragePermissions();
    final results = <Permission, PermissionStatus>{};

    for (final permission in permissions) {
      try {
        final status = await permission.request();
        results[permission] = status;

        // Log the result for debugging
        print('Storage permission ${permission.toString()}: $status');
      } catch (e) {
        print('Error requesting ${permission.toString()}: $e');
        results[permission] = PermissionStatus.denied;
      }
    }

    return results;
  }

  /// Check if all storage permissions are granted
  static Future<bool> areStoragePermissionsGranted() async {
    final permissions = getStoragePermissions();

    for (final permission in permissions) {
      final status = await permission.status;
      if (status != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  /// Get a user-friendly message for storage permission issues
  static String getStoragePermissionMessage() {
    if (isAndroid14) {
      return 'For Android 14, please manually enable storage permissions in Settings > Apps > OK Driver > Permissions';
    } else if (isAndroid13Plus) {
      return 'For Android 13+, please enable Photos & Videos and Audio permissions';
    } else {
      return 'Please enable Storage permission to save files';
    }
  }

  /// Get step-by-step instructions for enabling permissions
  static List<String> getPermissionInstructions() {
    if (isAndroid14) {
      return [
        '1. Go to Settings > Apps > OK Driver',
        '2. Tap "Permissions"',
        '3. Enable "Photos and videos"',
        '4. Enable "Audio" if needed',
        '5. Restart the app',
      ];
    } else if (isAndroid13Plus) {
      return [
        '1. Go to Settings > Apps > OK Driver',
        '2. Tap "Permissions"',
        '3. Enable "Photos & Videos"',
        '4. Enable "Audio"',
        '5. Restart the app',
      ];
    } else {
      return [
        '1. Go to Settings > Apps > OK Driver',
        '2. Tap "Permissions"',
        '3. Enable "Storage"',
        '4. Restart the app',
      ];
    }
  }

  /// Check if the app has legacy external storage access
  static bool hasLegacyStorageAccess() {
    // This would need to be implemented with platform-specific code
    // For now, we'll assume it's available if we're not on Android 13+
    return !isAndroid13Plus;
  }

  /// Get the appropriate storage directory for the app
  static Future<String?> getAppStorageDirectory() async {
    try {
      if (isAndroid13Plus) {
        // For Android 13+, use app-specific directory
        final directory = Directory(
            '/storage/emulated/0/Android/data/com.example.okdriver/files');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory.path;
      } else {
        // For older versions, use external storage
        final directory = Directory('/storage/emulated/0/OKDriver');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory.path;
      }
    } catch (e) {
      print('Error getting storage directory: $e');
      return null;
    }
  }
}
