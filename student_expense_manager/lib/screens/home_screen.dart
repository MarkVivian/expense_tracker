import 'package:flutter/material.dart';
import '../utils/preferences.dart';
import 'user_preferences_page.dart';
import 'weekly_view_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentPage = 1;  // Change this line to start with Weekly View

  final List<String> _pageTitles = ['User Preferences', 'Weekly View'];
  final List<Widget> _pages = [
    const UserPreferencesPage(),
    const WeeklyViewPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Preferences.backgroundColor,
      appBar: AppBar(
        backgroundColor: Preferences.primaryColor,
        title: Text(_pageTitles[_currentPage], style: Preferences.headlineStyle),
      ),
      body: _pages[_currentPage],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        items: [
          _buildNavItem(Preferences.userPreferencesIcon, 0),
          _buildNavItem(Preferences.weeklyViewIcon, 1),
        ],
        selectedItemColor: Preferences.accentColor,
        unselectedItemColor: Preferences.secondaryColor,
        backgroundColor: Preferences.primaryColor,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(String iconPath, int index) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _currentPage == index ? Preferences.selectedNavColor : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Image.asset(iconPath, width: 24, height: 24),
      ),
      label: '',
    );
  }
}

