import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;
import '../utils/firebase_controller.dart';

class StorageUtil {
// The name of the JSON file to store user preferences
  static const String fileName = 'user_preferences.json';

  /// Get the appropriate storage path based on the platform
  static Future<String> get _storagePath async {
    if (kIsWeb) {
      // For web, we'll use an empty string as we'll be using localStorage
      return '';
    } else if (Platform.isAndroid || Platform.isIOS) {
      // For mobile platforms, use the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      // For desktop platforms, use the home directory
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      return homeDir ?? '';
    }
  }

  /// Get the file object for storing/retrieving data
  static Future<File> get _storageFile async {
    final path = await _storagePath;
    return File('$path/$fileName');
  }

  /// Initialize the JSON structure for user preferences
  static Map<String, dynamic> _initializeJson() {
    return {};
  }

  /// Initialize the JSON structure for a specific user
  static Map<String, dynamic> _initializeUserJson() {
    return {
      'proteins': {},
      'carbohydrates': {},
      'vegetables': {},
      'breakfast': {},
      'snacks': {},
      'extra expenses': {},
      'settings': {
        'weeklySum': 0.0
      }
    };
  }

  /// Request storage permission for Android devices
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true; // Permission is assumed to be granted on other platforms
  }

  /// Get the current user ID
  static String? _getCurrentUserId() {
    return FirebaseController().currentUser?.uid;
  }

  /// Create the JSON file if it doesn't exist
  static Future<void> createJsonIfNotExists() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    if (kIsWeb) {
      // For web, check if the data exists in localStorage
      if (html.window.localStorage[fileName] == null) {
        final initialData = _initializeJson();
        initialData[userId] = _initializeUserJson();
        html.window.localStorage[fileName] = json.encode(initialData);
      } else {
        // If the file exists but the user doesn't have a section, add it
        final storedData = html.window.localStorage[fileName];
        final jsonData = json.decode(storedData!);
        if (!jsonData.containsKey(userId)) {
          jsonData[userId] = _initializeUserJson();
          html.window.localStorage[fileName] = json.encode(jsonData);
        }
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (!await file.exists()) {
          final initialData = _initializeJson();
          initialData[userId] = _initializeUserJson();
          await file.writeAsString(json.encode(initialData));
        } else {
          // If the file exists but the user doesn't have a section, add it
          final contents = await file.readAsString();
          final jsonData = json.decode(contents);
          if (!jsonData.containsKey(userId)) {
            jsonData[userId] = _initializeUserJson();
            await file.writeAsString(json.encode(jsonData));
          }
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Save data to the JSON file or web storage
  static Future<void> saveData(String category, String key, Map<String, dynamic> data) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();

      // Ensure the user section exists
      if (!jsonData.containsKey(userId)) {
        jsonData[userId] = _initializeUserJson();
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);

          // Ensure the user section exists
          if (!jsonData.containsKey(userId)) {
            jsonData[userId] = _initializeUserJson();
          }
        } else {
          jsonData = _initializeJson();
          jsonData[userId] = _initializeUserJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Update the JSON data with the new item
    if (!jsonData[userId].containsKey(category.toLowerCase())) {
      jsonData[userId][category.toLowerCase()] = {};
    }
    jsonData[userId][category.toLowerCase()][key] = data;

    // Save the updated JSON data
    if (kIsWeb) {
      html.window.localStorage[fileName] = json.encode(jsonData);
    } else {
      final file = await _storageFile;
      await file.writeAsString(json.encode(jsonData));
    }
  }

  /// Load data from the JSON file or web storage
  static Future<Map<String, dynamic>> loadData() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      if (storedData != null) {
        final allData = json.decode(storedData);
        if (allData.containsKey(userId)) {
          return allData[userId];
        } else {
          // Initialize user data if it doesn't exist
          final userData = _initializeUserJson();
          allData[userId] = userData;
          html.window.localStorage[fileName] = json.encode(allData);
          return userData;
        }
      } else {
        final initialData = _initializeJson();
        final userData = _initializeUserJson();
        initialData[userId] = userData;
        html.window.localStorage[fileName] = json.encode(initialData);
        return userData;
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          final allData = json.decode(contents);
          if (allData.containsKey(userId)) {
            return allData[userId];
          } else {
            // Initialize user data if it doesn't exist
            final userData = _initializeUserJson();
            allData[userId] = userData;
            await file.writeAsString(json.encode(allData));
            return userData;
          }
        } else {
          final initialData = _initializeJson();
          final userData = _initializeUserJson();
          initialData[userId] = userData;
          await file.writeAsString(json.encode(initialData));
          return userData;
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Delete an item from the JSON file or web storage
  static Future<void> deleteItem(String category, String itemName) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();

      // Ensure the user section exists
      if (!jsonData.containsKey(userId)) {
        jsonData[userId] = _initializeUserJson();
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);

          // Ensure the user section exists
          if (!jsonData.containsKey(userId)) {
            jsonData[userId] = _initializeUserJson();
          }
        } else {
          jsonData = _initializeJson();
          jsonData[userId] = _initializeUserJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Remove the item from the JSON data
    if (jsonData[userId].containsKey(category.toLowerCase())) {
      jsonData[userId][category.toLowerCase()].remove(itemName);

      // Save the updated JSON data
      if (kIsWeb) {
        html.window.localStorage[fileName] = json.encode(jsonData);
      } else {
        final file = await _storageFile;
        await file.writeAsString(json.encode(jsonData));
      }
    }
  }

  /// Update an item in the JSON file or web storage
  static Future<void> updateItem(String category, String oldItemName, Map<String, dynamic> newData) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();

      // Ensure the user section exists
      if (!jsonData.containsKey(userId)) {
        jsonData[userId] = _initializeUserJson();
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);

          // Ensure the user section exists
          if (!jsonData.containsKey(userId)) {
            jsonData[userId] = _initializeUserJson();
          }
        } else {
          jsonData = _initializeJson();
          jsonData[userId] = _initializeUserJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Update the item in the JSON data
    if (jsonData[userId].containsKey(category.toLowerCase())) {
      jsonData[userId][category.toLowerCase()].remove(oldItemName);
      jsonData[userId][category.toLowerCase()][newData['foodName'] ?? newData['itemName']] = newData;

      // Save the updated JSON data
      if (kIsWeb) {
        html.window.localStorage[fileName] = json.encode(jsonData);
      } else {
        final file = await _storageFile;
        await file.writeAsString(json.encode(jsonData));
      }
    }
  }

  /// Clear all data for the current user from the JSON file or web storage
  static Future<void> clearAllData() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      if (storedData != null) {
        final jsonData = json.decode(storedData);
        jsonData[userId] = _initializeUserJson();
        html.window.localStorage[fileName] = json.encode(jsonData);
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          final jsonData = json.decode(contents);
          jsonData[userId] = _initializeUserJson();
          await file.writeAsString(json.encode(jsonData));
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Save weekly sum to the JSON file or web storage
  static Future<void> saveWeeklySum(double sum) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();

      // Ensure the user section exists
      if (!jsonData.containsKey(userId)) {
        jsonData[userId] = _initializeUserJson();
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);

          if(kDebugMode){
            print(jsonData);
          }

          // Ensure the user section exists
          if (!jsonData.containsKey(userId)) {
            jsonData[userId] = _initializeUserJson();
          }
        } else {
          jsonData = _initializeJson();
          jsonData[userId] = _initializeUserJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Ensure settings section exists
    if (!jsonData[userId].containsKey('settings')) {
      jsonData[userId]['settings'] = {};
    }

    // Update weekly sum
    jsonData[userId]['settings']['weeklySum'] = sum;

    // Save the updated JSON data
    if (kIsWeb) {
      html.window.localStorage[fileName] = json.encode(jsonData);
    } else {
      final file = await _storageFile;
      await file.writeAsString(json.encode(jsonData));
    }
  }

  /// Get weekly sum from the JSON file or web storage
  static Future<double> getWeeklySum() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    Map<String, dynamic> userData = await loadData();

    // Check if settings and weeklySum exist
    if (userData.containsKey('settings') && userData['settings'].containsKey('weeklySum')) {
      return userData['settings']['weeklySum'].toDouble();
    }

    // Return default value if not found
    return 0.0;
  }
}

