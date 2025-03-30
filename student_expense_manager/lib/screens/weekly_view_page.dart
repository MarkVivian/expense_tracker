import 'package:flutter/material.dart';
import '../utils/preferences.dart';
import '../utils/storage_util.dart';
import '../utils/weekly_trainer.dart';
import 'package:flutter/foundation.dart';

class WeeklyViewPage extends StatefulWidget {
  const WeeklyViewPage({super.key});

  @override
  _WeeklyViewPageState createState() => _WeeklyViewPageState();
}

class _WeeklyViewPageState extends State<WeeklyViewPage> {
  final TextEditingController _weeklySumController = TextEditingController();
  bool _isLoadingWeeklySum = false;
  final WeeklyTrainer _weeklyTrainer = WeeklyTrainer();
  bool _isLoadingRecommendations = false;

  @override
  void initState() {
    super.initState();
    _initializeTrainer();
    _loadWeeklySum();
  }

  Future<void> _initializeTrainer() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      // Initialize trainer and check if it's first time
      final isFirstTime = await _weeklyTrainer.initialize();

      if (isFirstTime && mounted) {
        // Show first-time training dialog
        _weeklyTrainer.showFirstTimeTrainingDialog(context);
      }

      // Check if user has minimum requirements
      if (mounted) {
        await _weeklyTrainer.showRequirementsDialogIfNeeded(context);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing weekly trainer: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _weeklySumController.dispose();
    super.dispose();
  }

  Future<void> _loadWeeklySum() async {
    setState(() {
      _isLoadingWeeklySum = true;
    });

    try {
      final weeklySum = await StorageUtil.getWeeklySum();
      setState(() {
        _weeklySumController.text = weeklySum.toString();
        _isLoadingWeeklySum = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading weekly sum: $e');
      }
      setState(() {
        _weeklySumController.text = '0.0';
        _isLoadingWeeklySum = false;
      });
    }
  }

  Future<void> _saveWeeklySum() async {
    try {
      final sum = double.tryParse(_weeklySumController.text) ?? 0.0;
      await StorageUtil.saveWeeklySum(sum);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Weekly sum saved successfully'))
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error saving weekly sum: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save weekly sum'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Weekly Sum Input
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Preferences.secondaryColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Budget (KSh)',
                        style: Preferences.majorTextStyle,
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weeklySumController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Enter weekly budget',
                                hintStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(),
                                enabled: !_isLoadingWeeklySum,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _isLoadingWeeklySum ? null : _saveWeeklySum,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Preferences.accentColor,
                            ),
                            child: Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoadingRecommendations
                  ? Center(child: CircularProgressIndicator())
                  : Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 80,
                        color: Preferences.accentColor,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Weekly View',
                        style: Preferences.headlineStyle,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Add food items in the User Preferences page to see recommendations here.',
                        textAlign: TextAlign.center,
                        style: Preferences.bodyStyle,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/home', arguments: 0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Preferences.accentColor,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text('Go to User Preferences'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                });
                _initializeTrainer();
              },
              child: const Icon(Icons.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: Preferences.accentColor,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}

