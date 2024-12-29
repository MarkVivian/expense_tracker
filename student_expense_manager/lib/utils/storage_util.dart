import 'dart:convert';
import 'dart:io';

class StorageUtil {
  // Get the local file
  static Future<File> get _localFile async {
    return File("./user_preferences.json");
  }

  // Initialize the JSON structure
  static Map<String, dynamic> _initializeJson() {
    return {
      'proteins': {},
      'carbohydrates': {},
      'vegetables': {},
      'breakfast': {},
      'snacks': {},
      'extra expenses': {},
    };
  }

  // Create the JSON file if it doesn't exist
  static Future<void> createJsonIfNotExists() async {
    final file = await _localFile;
    if (!await file.exists()) {
      final initialData = _initializeJson();
      await file.writeAsString(json.encode(initialData));
    }
  }

  // Save data to the JSON file
  static Future<void> saveData(String category, Map<String, dynamic> data) async {
    final file = await _localFile;
    Map<String, dynamic> jsonData;

    if (await file.exists()) {
      final contents = await file.readAsString();
      jsonData = json.decode(contents);
    } else {
      jsonData = _initializeJson();
    }

    if (!jsonData.containsKey(category.toLowerCase())) {
      jsonData[category.toLowerCase()] = {};
    }

    jsonData[category.toLowerCase()][data['foodName']] = data;

    await file.writeAsString(json.encode(jsonData));
  }

  // Load data from the JSON file
  static Future<Map<String, dynamic>> loadData() async {
    final file = await _localFile;
    if (await file.exists()) {
      final contents = await file.readAsString();
      return json.decode(contents);
    } else {
      final initialData = _initializeJson();
      await file.writeAsString(json.encode(initialData));
      return initialData;
    }
  }

  // Delete an item from the JSON file
  static Future<void> deleteItem(String category, String itemName) async {
    final file = await _localFile;
    if (await file.exists()) {
      final contents = await file.readAsString();
      Map<String, dynamic> jsonData = json.decode(contents);

      if (jsonData.containsKey(category.toLowerCase())) {
        jsonData[category.toLowerCase()].remove(itemName);
        await file.writeAsString(json.encode(jsonData));
      }
    }
  }

  // Update an item in the JSON file
  static Future<void> updateItem(String category, String oldItemName, Map<String, dynamic> newData) async {
    final file = await _localFile;
    if (await file.exists()) {
      final contents = await file.readAsString();
      Map<String, dynamic> jsonData = json.decode(contents);

      if (jsonData.containsKey(category.toLowerCase())) {
        jsonData[category.toLowerCase()].remove(oldItemName);
        jsonData[category.toLowerCase()][newData['foodName']] = newData;
        await file.writeAsString(json.encode(jsonData));
      }
    }
  }
}
