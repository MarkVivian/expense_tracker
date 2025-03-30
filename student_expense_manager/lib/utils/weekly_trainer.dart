import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'training_storage.dart';
import 'storage_util.dart';
import 'preferences.dart';

class WeeklyTrainer {
  // Singleton pattern
  static final WeeklyTrainer _instance = WeeklyTrainer._internal();
  factory WeeklyTrainer() => _instance;
  WeeklyTrainer._internal();

  // Minimum requirements for each category
  static const Map<String, int> minimumRequirements = {
    'proteins': 3,
    'carbohydrates': 3,
    'vegetables and fruits': 1,
    'meal combos': 3,
    'breakfast combos': 2,
    'extra expenses': 0 // May be empty
  };

  // Initialize the trainer
  Future<bool> initialize() async {
    try {
      // Check if recommendation data file exists
      bool fileExists = await TrainingStorage.exists();

      // Create recommendation data file if it doesn't exist
      bool isNewFile = await TrainingStorage.createJsonIfNotExists();

      // Update recommendation weights based on user preferences
      await TrainingStorage.updateRecommendationWeights();

      // Return whether this is a new file (first time training)
      return isNewFile;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing weekly trainer: $e');
      }
      rethrow;
    }
  }

  // Check if user has enough items in each category
  Future<bool> hasMinimumRequirements() async {
    late var categoryData;
    try {
      final userPreferences = await StorageUtil.loadData();

      // Check each required category
      for (final entry in minimumRequirements.entries) {
        final category = entry.key;
        final minCount = entry.value;

        // Skip extra expenses which may be empty
        if (category == 'extra expenses') continue;

        // Get items in this category
        categoryData = userPreferences[category.toLowerCase()];
        if(kDebugMode){
          print('categoryData: ' + categoryData);
          print('Checking category $category with minCount $minCount');
        }
        if (categoryData == null) {
          if (kDebugMode) {
            print('Category $category not found in user preferences');
          }
          return false;
        }

        if (categoryData is! Map<String, dynamic>) {
          if (kDebugMode) {
            print('Category $category is not a map: $categoryData');
          }
          return false;
        }

        final items = categoryData as Map<String, dynamic>;
// todo : fix the issue where it still shows issue when category has been fulfilled.
        // Check if we have enough items
        if (items.length < minCount) {
          return false;
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking minimum requirements : $e');
      }
      return false;
    }
  }

  // Get missing requirements message
  Future<String> getMissingRequirementsMessage() async {
    try {
      final userPreferences = await StorageUtil.loadData();
      final List<String> missingItems = [];

      // Check each required category
      for (final entry in minimumRequirements.entries) {
        final category = entry.key;
        final minCount = entry.value;

        // Skip extra expenses which may be empty
        if (category == 'extra expenses') continue;

        // Get items in this category
        final items = userPreferences[category.toLowerCase()] as Map<String, dynamic>? ?? {};

        // Check if we have enough items
        if (items.length < minCount) {
          missingItems.add('$category: need at least $minCount items (currently have ${items.length})');
        }
      }

      if (missingItems.isEmpty) {
        return 'All requirements met!';
      } else {
        return 'Please add more items to the following categories:\n\n${missingItems.join('\n')}';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting missing requirements: $e');
      }
      return 'Error checking requirements. Please try again.';
    }
  }

  // Get category requirements status
  Future<Map<String, Map<String, dynamic>>> getCategoryRequirementsStatus() async {
    try {
      final userPreferences = await StorageUtil.loadData();
      final Map<String, Map<String, dynamic>> status = {};

      // Check each required category
      for (final entry in minimumRequirements.entries) {
        final category = entry.key;
        final minCount = entry.value;

        // Get items in this category
        final items = userPreferences[category.toLowerCase()] as Map<String, dynamic>? ?? {};

        // Calculate status
        bool isMet = items.length >= minCount;
        int remaining = isMet ? 0 : minCount - items.length;

        status[category] = {
          'isMet': isMet,
          'current': items.length,
          'required': minCount,
          'remaining': remaining
        };
      }

      return status;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting category requirements status: $e');
      }
      return {};
    }
  }

  // Show requirements dialog if needed
  Future<bool> showRequirementsDialogIfNeeded(BuildContext context) async {
    final hasRequirements = await hasMinimumRequirements();

    if (!hasRequirements && context.mounted) {
      final message = await getMissingRequirementsMessage();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('More Food Items Needed'),
          content: Text(
              'For the algorithm to recommend foods, please add more items to meet the following requirements:\n\n$message'
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Preferences.accentColor,
              ),
              child: Text('Go to User Preferences'),
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to User Preferences page
                Navigator.of(context).pushReplacementNamed('/home', arguments: 0); // Index 0 is User Preferences
              },
            ),
          ],
        ),
      );

      return false;
    }

    return true;
  }

  // Show first-time training dialog
  void showFirstTimeTrainingDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('AI Recommendation Ready'),
        content: Text(
            'Our AI recommendation system is ready to be trained with your food preferences. '
                'As you add more items and interact with the app, the recommendations will become more personalized to your taste!'
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Preferences.accentColor,
            ),
            child: Text('Got it!'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

