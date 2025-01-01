import 'package:flutter/material.dart';

class Preferences {
  // Colors
  static const Color primaryColor = Color(0xFF4A148C); // Deep Purple
  static const Color secondaryColor = Color(0xFF7B1FA2); // Purple
  static const Color accentColor = Color(0xFFAB47BC); // Light Purple
  static const Color backgroundColor = Color(0xFF121212); // Dark background
  static const Color pastColor = Color(0xFF424242); // Grey for past days/meals
  static const Color currentColor = Color(0xFF6A1B9A); // Vivid Purple for current day/meal
  static const Color futureColor = Color(0xFF8E24AA); // Lighter Purple for future days/meals
  static const Color selectedNavColor = Color(0xFF3E2465); // Darker Purple for selected nav item

  // Text Styles
  static const TextStyle headlineStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
  );

  static const TextStyle majorTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  // Images
  static const String placeholderImage = 'assets/images/placeholder.png';
  // Add your actual image paths here when you have them
  
  // Icon paths for bottom navigation
  static const String userPreferencesIcon = 'assets/images/icons8-plan-96.png';
  static const String weeklyViewIcon = 'assets/images/icons8-schedule-96.png';
  static const String pageThreeIcon = 'assets/images/placeholder.png';

 // Sizes
  static const double splashImageSize = 200.0;

  // Durations
  static const Duration splashDuration = Duration(seconds: 3);

  // Gradient for splash screen
  static const LinearGradient splashGradient = LinearGradient(
    colors: [primaryColor, secondaryColor, accentColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Strings
  static const List<String> preferencesCategories = [
    'Proteins',
    'Carbohydrates',
    'Vegetables',
    'Breakfast',
    'Snacks',
    'Extra Expenses'
  ];

  static const List<String> servingOptions = [
    'NA',
    '1/2',
    '1',
    '1 1/2',
    '2',
    '2 1/2',
    '3',
    'All'
  ];

  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  static const List<String> mealTimes = [
    'Breakfast',
    'Lunch',
    'Dinner'
  ];
}

