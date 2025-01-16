import 'dart:async';
import 'package:flutter/foundation.dart';
import 'weekly_storage_util.dart';
import 'storage_util.dart';

class AIUtility {
  // Variable to store the entire JSON data
  Map<String, dynamic>? allUserData;
  Map<String, dynamic>? weeklyData;

  // Constructor to initialize and load the JSON data
  AIUtility() {
    _initializeAllData();
  }

  void generate_meal_plans(){
    final proteins = _getCategoryData("proteins", allUserData);
    final carbs = _getCategoryData("carbohydrates", allUserData);
    final vegetables = _getCategoryData("vegetables", allUserData);
    final breakfast = _getCategoryData('breakfast combos', allUserData);
    final mealCombos = _getCategoryData("meal combos", allUserData);
    final expenses = _getCategoryData("extra expenses (e.g. fifa, drinking)", allUserData);
    final cost = weeklyData?["usage_price"];

    print(proteins);
  }

  // Function to load all data from the JSON file
  Future<void> _initializeAllData() async {
    try {
      allUserData = await StorageUtil.loadData();
      weeklyData = await WeeklyStorageUtil.loadData();
    } catch (e) {
      if (kDebugMode) {
        print("Error loading JSON data: $e");
      }
      allUserData = {};
    }
  }

  // Function to display all data
  void displayAllData() {
    if (allUserData != null) {
      if (kDebugMode) {
        // print("User Preferences Data: $weeklyData");
      }
    } else {
      if (kDebugMode) {
        print("Data has not been loaded yet.");
      }
    }
  }

  // Example function: Get data for a specific category
  Map<String, dynamic> _getCategoryData(String category, Map<String, dynamic>? container) {
    if (container != null && container.containsKey(category)) {
      return container[category];
    }
    return {"doesn't exist": "yeah its fucking empty"}; // Return an empty map if the category doesn't exist
  }

  // make a function to get proteins, carbs etc from the json input in allUserData.

}
