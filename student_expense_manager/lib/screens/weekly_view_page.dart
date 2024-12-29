import 'package:flutter/material.dart';
import '../utils/preferences.dart';

class WeeklyViewPage extends StatefulWidget {
  const WeeklyViewPage({Key? key}) : super(key: key);

  @override
  _WeeklyViewPageState createState() => _WeeklyViewPageState();
}

class _WeeklyViewPageState extends State<WeeklyViewPage> {
  late DateTime _currentDate;
  int _selectedMealIndex = -1;
  int _selectedFoodIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly View', style: Preferences.headlineStyle),
                  const SizedBox(height: 16),
                  ..._buildDayCards(),
                ],
              ),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Refresh functionality to be added later
            setState(() {
              _currentDate = DateTime.now();
            });
          },
          child: const Icon(Icons.refresh),
          style: ElevatedButton.styleFrom(
            backgroundColor: Preferences.accentColor,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
          ),
        ),
        const SizedBox(height: 16),
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
        title: Text(day, style: Preferences.majorTextStyle),
        initiallyExpanded: isCurrentDay,
        children: [
          ...List.generate(
            Preferences.mealTimes.length,
            (index) => _buildMealTile(dayIndex, index, isPastDay || (isCurrentDay && _isPassedMealTime(index))),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTile(int dayIndex, int mealIndex, bool isPast) {
    final meal = Preferences.mealTimes[mealIndex];
    final isCurrentMeal = dayIndex == _currentDate.weekday - 1 && 
                          mealIndex == _getCurrentMealIndex();

    return ExpansionTile(
      title: Text(meal, style: isPast ? Preferences.bodyStyle.copyWith(color: Preferences.pastColor) : Preferences.bodyStyle),
      initiallyExpanded: isCurrentMeal,
      children: [
        ...List.generate(
          3, // Number of food items per meal
          (index) => _buildFoodItem(dayIndex, mealIndex, index, isPast),
        ),
      ],
    );
  }

  Widget _buildFoodItem(int dayIndex, int mealIndex, int foodIndex, bool isPast) {
    final isSelected = _selectedMealIndex == mealIndex && _selectedFoodIndex == foodIndex;

    return GestureDetector(
      onTap: isPast ? null : () {
        setState(() {
          if (isSelected) {
            _selectedMealIndex = -1;
            _selectedFoodIndex = -1;
          } else {
            _selectedMealIndex = mealIndex;
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
            Text('Food Type', style: Preferences.bodyStyle),
            Text('Serving', style: Preferences.bodyStyle),
            Text('Price', style: Preferences.bodyStyle),
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

