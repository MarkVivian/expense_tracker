import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/preferences.dart';
import '../utils/weekly_storage_util.dart';
import '../utils/ai_functionality.dart';
// todo : using the weekly_view_page.dart i have provided. the 3 rectangles containing
// todo : food name, serving and price for each meal for each day .. i want when any of
// todo: the three rectangles are clicked it opens a dialog box containing the food items ,
// todo : and their price which in this case will be food item and price as the place holders
// todo : for the actual data . in this dialog box there will be a choose option and a cancel option
// todo: in the middle which when choose option is clicked will only leave the selected option as
// todo : colored but the rest 2 will have a grey background with white text. when cancel option is
// todo : clicked it then closes so that the user can select another option.
class WeeklyViewPage extends StatefulWidget {
  const WeeklyViewPage({Key? key}) : super(key: key);

  @override
  _WeeklyViewPageState createState() => _WeeklyViewPageState();
}

class _WeeklyViewPageState extends State<WeeklyViewPage> with SingleTickerProviderStateMixin {
  late DateTime _currentDate;
  int _selectedMealIndex = -1;
  int _selectedFoodIndex = -1;
  final TextEditingController _cashController = TextEditingController();
  Map<String, dynamic> _weeklyData = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _loadWeeklyData();
    _scheduleRefreshData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklyData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await WeeklyStorageUtil.loadData();
      setState(() {
        _weeklyData = data;
        _isLoading = false;
        _cashController.text = data['usage_price']?.toString() ?? '';
      });
    } catch (e) {
      print('Error loading weekly data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scheduleRefreshData() {
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    if (kDebugMode) {
      print("the current day is $currentWeekday");
    }
    if (currentWeekday != DateTime.monday) {
      // Calculate days until next Monday
      final daysUntilMonday = 8 - currentWeekday;

      // Schedule a timer to run on next Monday
      Timer(Duration(days: daysUntilMonday), () {
        _refreshData();
      });
      if (kDebugMode) {
        print("the value of monday is ${DateTime.monday} and days until "
            "monday are $daysUntilMonday");
      }
    } else {
      // If it's already Monday, refresh data immediately
      _refreshData();
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _currentDate = DateTime.now();
    });

    // AIUtility will be run when the user refreshes.
    AIUtility util = AIUtility();
    await Future.delayed(Duration(seconds: 1));
    util.displayAllData();

    // will load the data after it has been refreshed.
    await _loadWeeklyData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: FadeTransition(
          opacity: _animation,
          child: Text(
            'Loading...',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter cash (KSH)',
                    hintStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Preferences.accentColor),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: () async {
                  double? cash = double.tryParse(_cashController.text);
                  if (cash != null) {
                    await WeeklyStorageUtil.updateUsagePrice(cash);
                    await _refreshData();
                    print('Cash submitted: $cash'); // Log the submitted cash value
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Preferences.accentColor,
                ),
                child: Text(
                    'Submit',
                    style : Preferences.bodyStyle.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildDayCards(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildDayCards() {
    final List<Widget> cards = [];
    final int currentDayOfWeek = _currentDate.weekday;

    for (int i = 0; i < 7; i++) {
      final int dayIndex = (currentDayOfWeek - 1 + i) % 7;
      cards.add(_buildDayCard(dayIndex));
    }

    return cards;
  }

  Widget _buildDayCard(int dayIndex) {
    final DateTime date = _currentDate.subtract(Duration(days: _currentDate.weekday - 1 - dayIndex));
    final bool isCurrentDay = date.day == _currentDate.day && date.month == _currentDate.month && date.year == _currentDate.year;
    final bool isPastDay = date.isBefore(_currentDate);
    final String day = Preferences.daysOfWeek[dayIndex];

    return Card(
      color: isCurrentDay
          ? Preferences.currentColor
          : isPastDay
          ? Preferences.pastColor
          : Preferences.futureColor,
      child: ExpansionTile(
        title: Text(day, style: Preferences.majorTextStyle.copyWith(color: Colors.white)),
        initiallyExpanded: isCurrentDay,
        children: [
          ...List.generate(
            Preferences.mealTimes.length,
                (index) => _buildMealTile(day, index, isPastDay || (isCurrentDay && _isPassedMealTime(index))),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTile(String day, int mealIndex, bool isPast) {
    final meal = Preferences.mealTimes[mealIndex];
    final isCurrentMeal = day == Preferences.daysOfWeek[_currentDate.weekday - 1] &&
        mealIndex == _getCurrentMealIndex();

    return ExpansionTile(
      title: Text(meal, style: isPast ? Preferences.bodyStyle.copyWith(color: Colors.black) : Preferences.bodyStyle.copyWith(color: Colors.white)),
      initiallyExpanded: isCurrentMeal,
      children: [
        ...List.generate(
          3, // Number of food items per meal
              (index) => _buildFoodItem(day, meal.toLowerCase(), index, isPast),
        ),
      ],
    );
  }

  Widget _buildFoodItem(String day, String meal, int foodIndex, bool isPast) {
    final mealData = _weeklyData['days']?[day]?[meal] as List<dynamic>? ?? [];
    final foodItem = mealData.length > foodIndex ? mealData[foodIndex] as List<dynamic> : ['', '', ''];
    final isSelected = _selectedMealIndex == Preferences.mealTimes.indexOf(meal.capitalize()) && _selectedFoodIndex == foodIndex;

    return GestureDetector(
      onTap: isPast ? null : () {
        setState(() {
          if (isSelected) {
            _selectedMealIndex = -1;
            _selectedFoodIndex = -1;
          } else {
            _selectedMealIndex = Preferences.mealTimes.indexOf(meal.capitalize());
            _selectedFoodIndex = foodIndex;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isPast ? Preferences.pastColor : (isSelected ? Preferences.accentColor : Preferences.primaryColor),
          border: Border.all(color: Preferences.accentColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(foodItem[0], style: Preferences.bodyStyle.copyWith(color: Colors.white)),
            Text(foodItem[1], style: Preferences.bodyStyle.copyWith(color: Colors.white)),
            Text(foodItem[2], style: Preferences.bodyStyle.copyWith(color: Colors.white)),
            if (isSelected && !isPast)
              const Icon(Icons.check, color: Colors.white)
          ],
        ),
      ),
    );
  }

  int _getCurrentMealIndex() {
    final currentHour = _currentDate.hour;
    if (currentHour < 11) return 0; // Breakfast
    if (currentHour < 15) return 1; // Lunch
    return 2; // Dinner
  }

  bool _isPassedMealTime(int mealIndex) {
    final currentHour = _currentDate.hour;
    switch (mealIndex) {
      case 0: // Breakfast
        return currentHour >= 11;
      case 1: // Lunch
        return currentHour >= 15;
      case 2: // Dinner
        return false; // Dinner is never "passed" on the current day
      default:
        return false;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

