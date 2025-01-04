import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

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
    return {
      'proteins': {},
      'carbohydrates': {},
      'vegetables': {},
      'breakfast combos': {},
      'meal combos': {},
      'extra expenses': {},
    };
  }

  // 'proteins': {
  // {"foodName": "Beans", "price": "60.0", "totalServings": "All", "eachServings": "All"},
  // {"foodName": "peas", "price": "60.0", "totalServings": "All", "eachServings": "All"},
  // {"foodName": "meat", "price": "200.0", "totalServings": "All", "eachServings": "All"},
  // {"foodName": "eggs", "price": "30.0", "totalServings": "All", "eachServings": "All"},
  // {"foodName": "sossi", "price": "90.0", "totalServings": "All", "eachServings": "All"}
  // },
  // 'carbohydrates': {
  // {"foodName": "rice" , "price": "120.0", "totalServings": 3, "eachServings": "1 1/2"},
  // {"foodName": "ugali", "price": "100.0", "totalServings": 1, "eachServings": "1/2"},
  // {"foodName": "chapati", "price": "40.0", "totalServings": "All", "eachServings": "All"}
  // },
  // 'vegetables': {
  // {"foodName": "cabbage", "price": "20.0", "totalServings": "All", "eachServings": "All"},
  // {"foodName": "spinach", "price": "20.0", "totalServings": "All", "eachServings": "All"}
  // },
  // 'breakfast combos': {},
  // 'meal combos': {},
  // 'extra expenses': {},

  /// Request storage permission for Android devices
  static Future<bool> _requestStoragePermission() async {
    return await checkAndRequestPermission();
  }

  /// Create the JSON file if it doesn't exist
  static Future<void> createJsonIfNotExists() async {
    if (kIsWeb) {
      // For web, check if the data exists in localStorage
      if (html.window.localStorage[fileName] == null) {
        html.window.localStorage[fileName] = json.encode(_initializeJson());
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (!await file.exists()) {
          await file.writeAsString(json.encode(_initializeJson()));
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Save data to the JSON file or web storage
  static Future<void> saveData(String category, Map<String, dynamic> data) async {
    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);
        } else {
          jsonData = _initializeJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Update the JSON data with the new item
    if (!jsonData.containsKey(category.toLowerCase())) {
      jsonData[category.toLowerCase()] = {};
    }
    jsonData[category.toLowerCase()][data['foodName']] = data;

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
    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      if (storedData != null) {
        return json.decode(storedData);
      } else {
        final initialData = _initializeJson();
        html.window.localStorage[fileName] = json.encode(initialData);
        return initialData;
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          return json.decode(contents);
        } else {
          final initialData = _initializeJson();
          await file.writeAsString(json.encode(initialData));
          return initialData;
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Delete an item from the JSON file or web storage
  static Future<void> deleteItem(String category, String itemName) async {
    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);
        } else {
          jsonData = _initializeJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Remove the item from the JSON data
    if (jsonData.containsKey(category.toLowerCase())) {
      jsonData[category.toLowerCase()].remove(itemName);

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
    Map<String, dynamic> jsonData;

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      jsonData = storedData != null ? json.decode(storedData) : _initializeJson();
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          jsonData = json.decode(contents);
        } else {
          jsonData = _initializeJson();
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }

    // Update the item in the JSON data
    if (jsonData.containsKey(category.toLowerCase())) {
      jsonData[category.toLowerCase()].remove(oldItemName);
      jsonData[category.toLowerCase()][newData['foodName']] = newData;

      // Save the updated JSON data
      if (kIsWeb) {
        html.window.localStorage[fileName] = json.encode(jsonData);
      } else {
        final file = await _storageFile;
        await file.writeAsString(json.encode(jsonData));
      }
    }
  }

  static Future<bool> checkAndRequestPermission() async {
    if (kIsWeb) {
      return true; // Web doesn't need storage permission
    }
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true; // For iOS and other platforms, assume permission is granted
  }
}

