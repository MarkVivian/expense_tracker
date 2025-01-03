class AIFunctionality {
  final Map<String, dynamic> userPreferences;

  AIFunctionality(this.userPreferences);

  void displayUserPreferences() {
    print('Displaying User Preferences:');
    userPreferences.forEach((category, items) {
      print('\nCategory: $category');
      if (items is Map<String, dynamic>) {
        items.forEach((itemName, itemData) {
          print('  Food Name: ${itemData['foodName']}');
          print('  Price: ${itemData['price']}');
          print('  Total Servings: ${itemData['totalServings']}');
          print('  Each Serving: ${itemData['eachServings']}');
        });
      }
    });
  }
}

