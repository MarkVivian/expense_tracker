import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;

class WeeklyStorageUtil {
  static const String fileName = 'weekly_data.json';

  static Future<String> get _storagePath async {
    if (kIsWeb) {
      return '';
    } else if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      return homeDir ?? '';
    }
  }

  static Future<File> get _storageFile async {
    final path = await _storagePath;
    return File('$path/$fileName');
  }

  static Map<String, dynamic> _initializeJson() {
    return {
      'usage_price': 0,
      'days': {
        'Monday': _initializeDayData(),
        'Tuesday': _initializeDayData(),
        'Wednesday': _initializeDayData(),
        'Thursday': _initializeDayData(),
        'Friday': _initializeDayData(),
        'Saturday': _initializeDayData(),
        'Sunday': _initializeDayData(),
      }
    };
  }

  static Map<String, dynamic> _initializeDayData() {
    return {
      'breakfast': [
        ['food type', 'serving', 'price'],
        ['food type', 'serving', 'price'],
        ['food type', 'serving', 'price']
      ],
      'lunch': [
        ['food type', 'serving', 'price'],
        ['food type', 'serving', 'price'],
        ['food type', 'serving', 'price']
      ],
      'dinner': [
        ['food type', 'serving', 'price'],
        ['food type', 'serving', 'price'],
        ['food type', 'serving', 'price']
      ],
    };
  }

  static Future<bool> _requestStoragePermission() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true;
  }

  static Future<void> createJsonIfNotExists() async {
    if (kIsWeb) {
      if (html.window.localStorage[fileName] == null) {
        html.window.localStorage[fileName] = json.encode(_initializeJson());
      }
    } else {
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

  static Future<void> saveData(Map<String, dynamic> data) async {
    if (kIsWeb) {
      html.window.localStorage[fileName] = json.encode(data);
    } else {
      if (await _requestStoragePermission()) {
        final file = await _storageFile;
        await file.writeAsString(json.encode(data));
      } else {
        throw Exception('Storage permission not granted');
      }
    }
  }

  static Future<Map<String, dynamic>> loadData() async {
    if (kIsWeb) {
      final storedData = html.window.localStorage[fileName];
      if (storedData != null) {
        return json.decode(storedData);
      } else {
        final initialData = _initializeJson();
        html.window.localStorage[fileName] = json.encode(initialData);
        return initialData;
      }
    } else {
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

  static Future<void> updateUsagePrice(double price) async {
    Map<String, dynamic> data = await loadData();
    data['usage_price'] = price;
    await saveData(data);
  }

  static Future<void> updateMealData(String day, String meal, List<List<String>> mealData) async {
    Map<String, dynamic> data = await loadData();
    data['days'][day][meal] = mealData;
    await saveData(data);
  }
}

