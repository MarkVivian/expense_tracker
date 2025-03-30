import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;
import '../utils/firebase_controller.dart';
import 'package:firebase_database/firebase_database.dart';
// Import StorageUtil to use in updateRecommendationWeights
import 'storage_util.dart';

class TrainingStorage {
  // Singleton pattern
  static final TrainingStorage _instance = TrainingStorage._internal();
  factory TrainingStorage() => _instance;
  TrainingStorage._internal();

  // File name for recommendation data
  static const String fileName = 'recommendation_data.json';

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

  /// Initialize the JSON structure
  static Map<String, dynamic> _initializeJson() {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    if (kDebugMode) {
      print('TrainingStorage: Initializing new recommendation data JSON structure');
    }

    return {
      'users': {
        userId: {
          'recommendation_weights': {
            'proteins': {},
            'carbohydrates': {},
            'vegetables': {},
            'breakfast': {},
            'snacks': {},
            'breakfast combos': {},
            'meal combos': {},
            'extra expenses': {}
          },
          'history': [],
          'last_trained': DateTime.now().toIso8601String()
        }
      }
    };
  }

  /// Check if the recommendation data file exists
  static Future<bool> exists() async {
    if (kIsWeb) {
      // For web, check if the data exists in localStorage
      return html.window.localStorage[fileName] != null;
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        return await file.exists();
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Check if recommendation data exists in Firebase
  static Future<bool> existsInFirebase() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      if (kDebugMode) {
        print('TrainingStorage: No user logged in, cannot check Firebase');
      }
      return false;
    }

    try {
      final database = FirebaseDatabase.instance;
      final recommendationRef = database.ref('backups/$userId/recommendation_data');

      final snapshot = await recommendationRef.get();
      final exists = snapshot.exists;

      if (kDebugMode) {
        print('TrainingStorage: Recommendation data ${exists ? "found" : "not found"} in Firebase');
      }

      return exists;
    } catch (e) {
      if (kDebugMode) {
        print('TrainingStorage: Error checking Firebase for recommendation data: $e');
      }
      return false;
    }
  }

  /// Create the JSON file if it doesn't exist
  static Future<bool> createJsonIfNotExists() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    bool isNewFile = false;

    // First check if file exists locally
    bool fileExists = await exists();

    if (!fileExists) {
      if (kDebugMode) {
        print('TrainingStorage: Recommendation data file not found locally');
      }

      // Check if data exists in Firebase
      bool existsInCloud = await existsInFirebase();

      if (existsInCloud) {
        if (kDebugMode) {
          print('TrainingStorage: Found recommendation data in Firebase, will be restored during next backup restore');
        }
        // We'll let the backup system handle the restore
      } else {
        if (kDebugMode) {
          print('TrainingStorage: Creating new recommendation data file');
        }

        // Create new file with default structure
        if (kIsWeb) {
          // For web, check if the data exists in localStorage
          if (html.window.localStorage[fileName] == null) {
            final initialData = _initializeJson();
            html.window.localStorage[fileName] = json.encode(initialData);
            isNewFile = true;

            if (kDebugMode) {
              print('TrainingStorage: Created new recommendation data in localStorage');
              print('TrainingStorage: Initial data: ${json.encode(initialData)}');
            }
          }
        } else {
          // For mobile and desktop
          if (await _requestStoragePermission()) {
            final file = await _storageFile;
            if (!await file.exists()) {
              final initialData = _initializeJson();
              await file.writeAsString(json.encode(initialData));
              isNewFile = true;

              if (kDebugMode) {
                print('TrainingStorage: Created new recommendation data file at ${file.path}');
                print('TrainingStorage: Initial data: ${json.encode(initialData)}');
              }
            }
          } else {
            throw Exception('Storage permission not granted');
          }
        }
      }
    } else {
      if (kDebugMode) {
        print('TrainingStorage: Recommendation data file already exists');
      }
    }

    return isNewFile;
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

        // Ensure user section exists
        if (!allData.containsKey('users')) {
          allData['users'] = {};
        }

        if (!allData['users'].containsKey(userId)) {
          allData['users'][userId] = {
            'recommendation_weights': {
              'proteins': {},
              'carbohydrates': {},
              'vegetables': {},
              'breakfast': {},
              'snacks': {},
              'breakfast combos': {},
              'meal combos': {},
              'extra expenses': {}
            },
            'history': [],
            'last_trained': DateTime.now().toIso8601String()
          };
          html.window.localStorage[fileName] = json.encode(allData);
        }

        return allData['users'][userId];
      } else {
        final initialData = _initializeJson();
        html.window.localStorage[fileName] = json.encode(initialData);
        return initialData['users'][userId];
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        if (await file.exists()) {
          final contents = await file.readAsString();
          final allData = json.decode(contents);

          // Ensure user section exists
          if (!allData.containsKey('users')) {
            allData['users'] = {};
          }

          if (!allData['users'].containsKey(userId)) {
            allData['users'][userId] = {
              'recommendation_weights': {
                'proteins': {},
                'carbohydrates': {},
                'vegetables': {},
                'breakfast': {},
                'snacks': {},
                'breakfast combos': {},
                'meal combos': {},
                'extra expenses': {}
              },
              'history': [],
              'last_trained': DateTime.now().toIso8601String()
            };
            await file.writeAsString(json.encode(allData));
          }

          return allData['users'][userId];
        } else {
          final initialData = _initializeJson();
          await file.writeAsString(json.encode(initialData));
          return initialData['users'][userId];
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Save data to the JSON file or web storage
  static Future<void> saveData(Map<String, dynamic> userData) async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      throw Exception('No user logged in');
    }

    if (kIsWeb) {
      // For web, use localStorage
      final storedData = html.window.localStorage[fileName];
      Map<String, dynamic> allData;

      if (storedData != null) {
        allData = json.decode(storedData);
      } else {
        allData = {'users': {}};
      }

      // Ensure users section exists
      if (!allData.containsKey('users')) {
        allData['users'] = {};
      }

      // Update user data
      allData['users'][userId] = userData;

      // Save back to localStorage
      html.window.localStorage[fileName] = json.encode(allData);

      if (kDebugMode) {
        print('TrainingStorage: Saved recommendation data to localStorage');
      }
    } else {
      // For mobile and desktop
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        Map<String, dynamic> allData;

        if (await file.exists()) {
          final contents = await file.readAsString();
          allData = json.decode(contents);
        } else {
          allData = {'users': {}};
        }

        // Ensure users section exists
        if (!allData.containsKey('users')) {
          allData['users'] = {};
        }

        // Update user data
        allData['users'][userId] = userData;

        // Save back to file
        await file.writeAsString(json.encode(allData));

        if (kDebugMode) {
          print('TrainingStorage: Saved recommendation data to file: ${file.path}');
        }
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  /// Update recommendation weights based on user preferences
  static Future<void> updateRecommendationWeights() async {
    try {
      // Load user preferences
      final userPreferences = await StorageUtil.loadData();

      // Load training data
      final userData = await loadData();
      final weights = userData['recommendation_weights'] as Map<String, dynamic>;

      if (kDebugMode) {
        print('TrainingStorage: Updating recommendation weights based on user preferences');
      }

      // Update weights for each category in user preferences
      userPreferences.forEach((category, items) {
        if (items is Map<String, dynamic>) {
          // Ensure category exists in weights
          final lowerCategory = category.toLowerCase();
          if (!weights.containsKey(lowerCategory)) {
            weights[lowerCategory] = {};
            if (kDebugMode) {
              print('TrainingStorage: Created new category in weights: $lowerCategory');
            }
          }

          // Add each item with default weight if not already present
          items.forEach((itemName, itemData) {
            // Skip if itemData is not a map
            if (itemData is! Map<String, dynamic>) {
              if (kDebugMode) {
                print('TrainingStorage: Skipping non-map item data: $itemName: $itemData');
              }
              return;
            }

            final foodName = itemData['foodName'] ?? itemData['itemName'] ?? itemName;
            if (!weights[lowerCategory].containsKey(foodName)) {
              weights[lowerCategory][foodName] = 5; // Default weight
              if (kDebugMode) {
                print('TrainingStorage: Added new item to weights: $lowerCategory > $foodName');
              }
            }
          });
        }
      });

      // Update last trained timestamp
      userData['last_trained'] = DateTime.now().toIso8601String();

      // Save updated weights
      await saveData(userData);

      if (kDebugMode) {
        print('TrainingStorage: Successfully updated recommendation weights');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TrainingStorage: Error updating recommendation weights: $e');
      }
      rethrow;
    }
  }

  /// Add an entry to history
  static Future<void> addToHistory(Map<String, dynamic> entry) async {
    try {
      final userData = await loadData();
      final history = userData['history'] as List<dynamic>;

      // Add timestamp to entry
      entry['timestamp'] = DateTime.now().toIso8601String();

      // Add to history
      history.add(entry);

      // Limit history to last 100 entries
      if (history.length > 100) {
        history.removeAt(0);
      }

      userData['history'] = history;
      await saveData(userData);

      if (kDebugMode) {
        print('TrainingStorage: Added entry to history: ${entry['timestamp']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('TrainingStorage: Error adding to history: $e');
      }
      rethrow;
    }
  }
}


