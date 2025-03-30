import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/firebase_controller.dart';
import 'preferences.dart';
import 'storage_util.dart';
import 'training_storage.dart';

class AutoBackups {
// Singleton pattern
  static final AutoBackups _instance = AutoBackups._internal();
  factory AutoBackups() => _instance;
  AutoBackups._internal();

// Firebase references
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseController _firebaseController = FirebaseController();

// Connectivity
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

// Backup state
  bool _isBackupScheduled = false;
  bool _isPendingBackup = false;
  DateTime? _lastBackupTime;
  Timer? _backupTimer;
  bool _isPerformingBackup = false;

// Constants
  static const String _lastBackupKey = 'last_backup_time';
  static const String _pendingBackupKey = 'pending_backup';

// Initialize the backup system
  Future<void> initialize() async {
    if (_firebaseController.currentUser == null) {
      if (kDebugMode) {
        print('AutoBackups: No user logged in, skipping initialization');
      }
      return;
    }

    await _loadBackupState();
    await _loadKeyMappings(); // Load key mappings
    _setupConnectivityListener();
    _scheduleBackup();

    if (_isPendingBackup) {
      _checkConnectivityAndBackup();
    }
  }

// Load backup state from SharedPreferences
  Future<void> _loadBackupState() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _firebaseController.currentUser?.uid;
    if (userId == null) return;

    final lastBackupTimeString = prefs.getString('${_lastBackupKey}_$userId');
    _lastBackupTime = lastBackupTimeString != null
        ? DateTime.parse(lastBackupTimeString)
        : null;
    _isPendingBackup = prefs.getBool('${_pendingBackupKey}_$userId') ?? false;

    if (kDebugMode) {
      print('AutoBackups: Last backup time for user $userId: $_lastBackupTime');
      print('AutoBackups: Pending backup for user $userId: $_isPendingBackup');
    }
  }

// Save backup state to SharedPreferences
  Future<void> _saveBackupState() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _firebaseController.currentUser?.uid;
    if (userId == null) return;

    if (_lastBackupTime != null) {
      await prefs.setString('${_lastBackupKey}_$userId', _lastBackupTime!.toIso8601String());
    }
    await prefs.setBool('${_pendingBackupKey}_$userId', _isPendingBackup);
  }

// Set up connectivity listener
  void _setupConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If any connection type is available and there's a pending backup
      if (results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none) &&
          _isPendingBackup) {
        _performBackup();
      }
    });
  }

// Schedule backup at midnight
  void _scheduleBackup() {
    if (_isBackupScheduled) return;

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = midnight.difference(now);

    if (kDebugMode) {
      print('AutoBackups: Scheduling backup in ${timeUntilMidnight.inHours} hours and ${timeUntilMidnight.inMinutes % 60} minutes');
    }

    _backupTimer?.cancel();
    _backupTimer = Timer(timeUntilMidnight, () {
      _checkConnectivityAndBackup();
      // Schedule next day's backup
      _isBackupScheduled = false;
      _scheduleBackup();
    });

    _isBackupScheduled = true;
  }

// Check connectivity and perform backup if connected
  Future<void> _checkConnectivityAndBackup() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.isNotEmpty &&
        connectivityResults.any((result) => result != ConnectivityResult.none)) {
      await _performBackup();
    } else {
      _isPendingBackup = true;
      await _saveBackupState();

      // Try again within the 12am-6am window
      _scheduleRetryWithinWindow();
    }
  }

// Schedule retry within the midnight to 6am window
  void _scheduleRetryWithinWindow() {
    final now = DateTime.now();
    final sixAM = DateTime(now.year, now.month, now.day, 6);

// If it's already past 6am, don't retry until next scheduled backup
    if (now.isAfter(sixAM)) {
      if (kDebugMode) {
        print('AutoBackups: Outside backup window (after 6am), waiting for next scheduled backup');
      }
      return;
    }

// Try again in 30 minutes if still within window
    final retryDelay = Duration(minutes: 30);
    _backupTimer?.cancel();
    _backupTimer = Timer(retryDelay, _checkConnectivityAndBackup);

    if (kDebugMode) {
      print('AutoBackups: Scheduling retry in 30 minutes (still within backup window)');
    }
  }

// Check if a backup is currently in progress
  bool get isPerformingBackup => _isPerformingBackup;

// Perform the actual backup
  Future<Map<String, dynamic>> _performBackup() async {
    if (_isPerformingBackup) {
      return {'success': false, 'message': 'Backup already in progress'};
    }

    _isPerformingBackup = true;

    try {
      if (_firebaseController.currentUser == null) {
        if (kDebugMode) {
          print('AutoBackups: No user logged in, skipping backup');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'No user logged in'};
      }

      final userId = _firebaseController.currentUser!.uid;

      if (kDebugMode) {
        print('AutoBackups: Starting backup process for user: $userId');
      }

      // Load local data
      Map<String, dynamic> localData;
      try {
        localData = await StorageUtil.loadData();
        if (kDebugMode) {
          print('AutoBackups: Loaded local data with ${_countItems(localData)} total items');
          print('AutoBackups: Data sample: ${_getSampleData(localData)}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('AutoBackups: Error loading local data: $e');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'Failed to load local data: $e'};
      }

      // Check if local data is empty
      if (localData.isEmpty) {
        if (kDebugMode) {
          print('AutoBackups: Local data is empty, skipping backup');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'Local data is empty'};
      }

      // Load recommendation data
      Map<String, dynamic> recommendationData;
      try {
        recommendationData = await TrainingStorage.loadData();
        if (kDebugMode) {
          print('AutoBackups: Loaded recommendation data successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('AutoBackups: Error loading recommendation data: $e');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'Failed to load recommendation data: $e'};
      }

      // Sanitize data to ensure it's Firebase-compatible
      try {
        localData = _sanitizeData(localData);
        recommendationData = _sanitizeData(recommendationData);
        if (kDebugMode) {
          print('AutoBackups: Data sanitized successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('AutoBackups: Error sanitizing data: $e');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'Failed to sanitize data: $e'};
      }

      // Initialize database reference
      try {
        if (kDebugMode) {
          print('AutoBackups: Initializing database reference for path: backups/$userId');
        }
        final userBackupsRef = _database.ref('backups/$userId');

        // Check if reference is valid
        final testSnapshot = await userBackupsRef.child('test').set('test');
        await userBackupsRef.child('test').remove();
        if (kDebugMode) {
          print('AutoBackups: Database reference is valid');
        }
      } catch (e) {
        if (kDebugMode) {
          print('AutoBackups: Error initializing database reference: $e');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'Failed to initialize database reference: $e'};
      }

      // Get Firebase data references
      final currentRef = _database.ref('backups/$userId/current');
      final previousRef = _database.ref('backups/$userId/previous');
      final recommendationRef = _database.ref('backups/$userId/recommendation_data');

      if (kDebugMode) {
        print('AutoBackups: Ready to save data to Firebase');
      }

      // Get current data from Firebase (if exists)
      try {
        final currentSnapshot = await currentRef.get();

        if (currentSnapshot.exists) {
          // Move current to previous
          if (kDebugMode) {
            print('AutoBackups: Moving current data to previous');
          }

          final currentData = currentSnapshot.value;
          await previousRef.set(currentData);

          if (kDebugMode) {
            print('AutoBackups: Successfully moved current data to previous');
          }
        } else if (kDebugMode) {
          print('AutoBackups: No existing backup found, creating first backup');
        }
      } catch (e) {
        if (kDebugMode) {
          print('AutoBackups: Error moving current data to previous: $e');
        }
        // Continue with backup even if this step fails
      }

      // Set new current data
      try {
        if (kDebugMode) {
          print('AutoBackups: Saving new data to Firebase current reference');
        }

        await currentRef.set(localData);

        if (kDebugMode) {
          print('AutoBackups: Successfully saved user data to Firebase');
        }

        // Save recommendation data
        await recommendationRef.set(recommendationData);

        if (kDebugMode) {
          print('AutoBackups: Successfully saved recommendation data to Firebase');
        }
      } catch (e) {
        if (kDebugMode) {
          print('AutoBackups: Error saving data to Firebase: $e');
        }
        _isPerformingBackup = false;
        return {'success': false, 'message': 'Failed to save data to Firebase: $e'};
      }

      // After successful backup, save key mappings
      await _saveKeyMappings();

      // Update backup state
      _lastBackupTime = DateTime.now();
      _isPendingBackup = false;
      await _saveBackupState();

      if (kDebugMode) {
        print('AutoBackups: Backup completed successfully at ${_lastBackupTime!.toIso8601String()}');
      }

      await _saveKeyMappings();
      _isPerformingBackup = false;
      return {'success': true, 'message': 'Backup completed successfully'};
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error during backup: $e');
      }
      _isPendingBackup = true;
      await _saveBackupState();
      _isPerformingBackup = false;
      return {'success': false, 'message': 'Error during backup: $e'};
    }
  }

// Get a sample of data for debugging
  String _getSampleData(Map<String, dynamic> data) {
    try {
      // Get one category and one item as sample
      if (data.isEmpty) return "Empty data";

      final firstCategory = data.keys.first;
      final categoryData = data[firstCategory];

      if (categoryData is! Map || (categoryData as Map).isEmpty) {
        return "First category ($firstCategory) is empty";
      }

      final firstItemKey = (categoryData as Map).keys.first;
      final firstItem = categoryData[firstItemKey];

      return "Sample: $firstCategory > $firstItemKey: $firstItem";
    } catch (e) {
      return "Error getting sample: $e";
    }
  }

// Sanitize data to ensure Firebase compatibility
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
// Create a new map to avoid modifying the original
    Map<String, dynamic> sanitized = {};

// Process each category
    data.forEach((category, items) {
      // Sanitize the category key
      String sanitizedCategory = _sanitizeKey(category);

      if (items is Map) {
        // Create a sanitized category
        sanitized[sanitizedCategory] = {};

        // Process each item in the category
        items.forEach((key, value) {
          // Sanitize the item key
          String sanitizedKey = _sanitizeKey(key.toString());

          if (value is Map) {
            // Convert the item to a sanitized Map<String, dynamic>
            Map<String, dynamic> sanitizedItem = {};

            value.forEach((k, v) {
              // Convert any non-supported types
              if (v is int || v is double || v is bool || v is String || v is List || v is Map) {
                sanitizedItem[k.toString()] = v;
              } else {
                // Convert other types to string representation
                sanitizedItem[k.toString()] = v.toString();
              }
            });

            sanitized[sanitizedCategory][sanitizedKey] = sanitizedItem;
          } else {
            sanitized[sanitizedCategory][sanitizedKey] = value;
          }
        });
      } else {
        sanitized[sanitizedCategory] = items;
      }
    });

    return sanitized;
  }

// Sanitize keys to make them Firebase-compatible
  String _sanitizeKey(String key) {
// Replace spaces with underscores
    String sanitized = key.replaceAll(' ', '_');

// Remove parentheses, commas, and other special characters
    sanitized = sanitized.replaceAll(RegExp(r'[$$$$,\.\#\$\/\[\]]'), '');

// Store the mapping for later desanitization
    _storeSanitizationMapping(key, sanitized);

    return sanitized;
  }

// Store mapping between original and sanitized keys
  final Map<String, String> _sanitizedToOriginalKeys = {};
  final Map<String, String> _originalToSanitizedKeys = {};

  void _storeSanitizationMapping(String original, String sanitized) {
    _originalToSanitizedKeys[original] = sanitized;
    _sanitizedToOriginalKeys[sanitized] = original;
  }

// Desanitize keys to restore original format
  String _desanitizeKey(String sanitizedKey) {
    return _sanitizedToOriginalKeys[sanitizedKey] ?? sanitizedKey;
  }

// Add a method to persist the key mappings between app sessions

// Save key mappings to SharedPreferences
  Future<void> _saveKeyMappings() async {
    try {
      final userId = _firebaseController.currentUser?.uid;
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sanitized_to_original_keys_$userId', json.encode(_sanitizedToOriginalKeys));
      await prefs.setString('original_to_sanitized_keys_$userId', json.encode(_originalToSanitizedKeys));

      if (kDebugMode) {
        print('AutoBackups: Saved key mappings for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error saving key mappings: $e');
      }
    }
  }

// Load key mappings from SharedPreferences
  Future<void> _loadKeyMappings() async {
    try {
      final userId = _firebaseController.currentUser?.uid;
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final sanitizedToOriginalString = prefs.getString('sanitized_to_original_keys_$userId');
      final originalToSanitizedString = prefs.getString('original_to_sanitized_keys_$userId');

      if (sanitizedToOriginalString != null) {
        final Map<String, dynamic> decoded = json.decode(sanitizedToOriginalString);
        decoded.forEach((key, value) {
          _sanitizedToOriginalKeys[key] = value.toString();
        });
      }

      if (originalToSanitizedString != null) {
        final Map<String, dynamic> decoded = json.decode(originalToSanitizedString);
        decoded.forEach((key, value) {
          _originalToSanitizedKeys[key] = value.toString();
        });
      }

      if (kDebugMode) {
        print('AutoBackups: Loaded key mappings for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error loading key mappings: $e');
      }
    }
  }

// Count total items in all categories
  int _countItems(Map<String, dynamic> data) {
    int count = 0;
    data.forEach((category, items) {
      if (items is Map) {
        count += items.length;
      }
    });
    return count;
  }

// Check if there's a first-time backup flag
  Future<bool> hasFirstTimeBackup() async {
    final userId = _firebaseController.currentUser?.uid;
    if (userId == null) return false;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_time_backup_$userId') ?? false;
  }

// Clear first-time backup flag
  Future<void> clearFirstTimeBackupFlag() async {
    final userId = _firebaseController.currentUser?.uid;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time_backup_$userId', false);
  }

// Flag first-time backup on new device
  Future<void> _flagFirstTimeBackup() async {
    final userId = _firebaseController.currentUser?.uid;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_time_backup_$userId', true);
  }

// Handle first-time backup on a new device
  Future<bool> handleFirstTimeBackup() async {
    if (_firebaseController.currentUser == null) return false;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.every((result) => result == ConnectivityResult.none)) {
      return false;
    }

    try {
      // Clear first-time backup flag
      await clearFirstTimeBackupFlag();

      // Restore from Firebase
      return await restoreFromFirebase();
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error handling first-time backup: $e');
      }
      return false;
    }
  }

// Force an immediate backup
  Future<Map<String, dynamic>> forceBackup() async {
    if (_firebaseController.currentUser == null) {
      return {'success': false, 'message': 'No user logged in'};
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.every((result) => result == ConnectivityResult.none)) {
      return {'success': false, 'message': 'No internet connection'};
    }

    return await _performBackup();
  }

// Get backup versions for rollback UI
  Future<Map<String, dynamic>> getBackupVersions() async {
    if (_firebaseController.currentUser == null) {
      return {
        'current': null,
        'previous': null,
        'lastBackupTime': null,
      };
    }

    try {
      final userId = _firebaseController.currentUser!.uid;
      final currentRef = _database.ref('backups/$userId/current');
      final previousRef = _database.ref('backups/$userId/previous');

      final currentSnapshot = await currentRef.get();
      final previousSnapshot = await previousRef.get();

      // Desanitize current backup data if it exists
      Map<String, dynamic>? currentData;
      if (currentSnapshot.exists) {
        currentData = Map<String, dynamic>.from(currentSnapshot.value as Map);
        currentData = _desanitizeData(currentData);
      }

      // Desanitize previous backup data if it exists
      Map<String, dynamic>? previousData;
      if (previousSnapshot.exists) {
        previousData = Map<String, dynamic>.from(previousSnapshot.value as Map);
        previousData = _desanitizeData(previousData);
      }

      return {
        'current': currentData,
        'previous': previousData,
        'lastBackupTime': _lastBackupTime?.toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error getting backup versions: $e');
      }
      return {
        'current': null,
        'previous': null,
        'lastBackupTime': null,
      };
    }
  }

// Desanitize an entire data structure
  Map<String, dynamic> _desanitizeData(Map<String, dynamic> sanitizedData) {
    Map<String, dynamic> desanitized = {};

    sanitizedData.forEach((sanitizedCategory, items) {
      // Desanitize the category key
      String category = _desanitizeKey(sanitizedCategory);

      if (items is Map) {
        desanitized[category] = {};

        items.forEach((sanitizedKey, value) {
          // Desanitize the item key
          String key = _desanitizeKey(sanitizedKey);

          desanitized[category][key] = value;
        });
      } else {
        desanitized[category] = items;
      }
    });

    return desanitized;
  }

// Rollback to a specific version
  Future<bool> rollbackTo(String version) async {
    if (_firebaseController.currentUser == null) return false;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.every((result) => result == ConnectivityResult.none)) {
      return false;
    }

    try {
      final userId = _firebaseController.currentUser!.uid;
      final versionRef = _database.ref('backups/$userId/$version');
      final recommendationRef = _database.ref('backups/$userId/recommendation_data');

      final snapshot = await versionRef.get();
      if (!snapshot.exists) return false;

      final versionData = Map<String, dynamic>.from(snapshot.value as Map);

      // Clear existing local data
      await StorageUtil.clearAllData();

      // Update local storage with the selected version
      for (var sanitizedCategory in versionData.keys) {
        // Desanitize the category key
        String category = _desanitizeKey(sanitizedCategory);

        if (versionData[sanitizedCategory] is Map) {
          final categoryData = Map<String, dynamic>.from(versionData[sanitizedCategory] as Map);
          for (var sanitizedItemKey in categoryData.keys) {
            // Desanitize the item key
            String itemKey = _desanitizeKey(sanitizedItemKey);

            await StorageUtil.saveData(
                category,
                itemKey,
                Map<String, dynamic>.from(categoryData[sanitizedItemKey] as Map)
            );
          }
        }
      }

      // Restore recommendation data if available
      final recommendationSnapshot = await recommendationRef.get();
      if (recommendationSnapshot.exists) {
        final recommendationData = Map<String, dynamic>.from(recommendationSnapshot.value as Map);

        // Create a new recommendation data file
        await TrainingStorage.createJsonIfNotExists();

        // Load the current structure
        final currentRecommendationData = await TrainingStorage.loadData();

        // Update with the restored data
        // We need to be careful with the structure here
        if (recommendationData.containsKey('recommendation_weights')) {
          currentRecommendationData['recommendation_weights'] = recommendationData['recommendation_weights'];
        }

        if (recommendationData.containsKey('history')) {
          currentRecommendationData['history'] = recommendationData['history'];
        }

        if (recommendationData.containsKey('last_trained')) {
          currentRecommendationData['last_trained'] = recommendationData['last_trained'];
        }

        // Save the updated recommendation data
        await TrainingStorage.saveData(currentRecommendationData);

        if (kDebugMode) {
          print('AutoBackups: Successfully restored recommendation data');
        }
      } else {
        if (kDebugMode) {
          print('AutoBackups: No recommendation data found in backup');
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error during rollback: $e');
      }
      return false;
    }
  }

// Restore from Firebase to local if local is empty or corrupted
  Future<bool> restoreFromFirebase() async {
    if (_firebaseController.currentUser == null) return false;

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.isEmpty || connectivityResult.every((result) => result == ConnectivityResult.none)) {
      return false;
    }

    try {
      final userId = _firebaseController.currentUser!.uid;
      final currentRef = _database.ref('backups/$userId/current');
      final recommendationRef = _database.ref('backups/$userId/recommendation_data');

      final snapshot = await currentRef.get();
      if (!snapshot.exists) {
        if (kDebugMode) {
          print('AutoBackups: No user data backup found in Firebase');
        }
        return false;
      }

      // Clear existing local data
      await StorageUtil.clearAllData();

      // Restore user data from Firebase
      final success = await rollbackTo('current');

      // Check for recommendation data
      final recommendationSnapshot = await recommendationRef.get();
      if (recommendationSnapshot.exists) {
        if (kDebugMode) {
          print('AutoBackups: Found recommendation data in Firebase, restoring...');
        }

        // Recommendation data is handled in rollbackTo method
      } else {
        if (kDebugMode) {
          print('AutoBackups: No recommendation data found in Firebase');
        }
      }

      return success;
    } catch (e) {
      if (kDebugMode) {
        print('AutoBackups: Error during restore: $e');
      }
      return false;
    }
  }

// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _backupTimer?.cancel();
  }
}

