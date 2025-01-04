import 'dart:async';
import 'package:flutter/foundation.dart';

import 'storage_util.dart';

class AIUtility {
  // Variable to store the entire JSON data
  Map<String, dynamic>? allUserData;

  // Constructor to initialize and load the JSON data
  AIUtility() {
    _initializeAllData();
  }

  // Function to load all data from the JSON file
  Future<void> _initializeAllData() async {
    try {
      allUserData = await StorageUtil.loadData();
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
        print("User Preferences Data: $allUserData");
      }
    } else {
      if (kDebugMode) {
        print("Data has not been loaded yet.");
      }
    }
  }

  // Example function: Get data for a specific category
  Map<String, dynamic> getCategoryData(String category) {
    if (allUserData != null && allUserData!.containsKey(category)) {
      return allUserData![category];
    }
    return {"empty": "yeah its fucking empty"}; // Return an empty map if the category doesn't exist
  }
}
