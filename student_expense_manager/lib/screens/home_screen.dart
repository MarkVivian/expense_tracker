import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../utils/preferences.dart';
import '../utils/firebase_controller.dart';
import '../utils/AutoBackups.dart';
import 'user_preferences_page.dart';
import 'weekly_view_page.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, this.initialPage}) : super(key: key);

  final int? initialPage;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentPage;
  final FirebaseController _firebaseController = FirebaseController();
  final AutoBackups _autoBackups = AutoBackups();

  final List<String> _pageTitles = ['User Preferences', 'Weekly View'];
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? 1; // Default to Weekly View unless specified
    _pages = [
      const UserPreferencesPage(),
      const WeeklyViewPage(),
    ];
  }

  @override
  void dispose() {
    _autoBackups.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Preferences.backgroundColor,
      appBar: AppBar(
        backgroundColor: Preferences.primaryColor,
        title: Text(_pageTitles[_currentPage], style: Preferences.headlineStyle),
        actions: [
          // User profile icon
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Preferences.accentColor,
              child: Text(
                _firebaseController.getUserDisplayName()?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(color: Colors.white),
              ),
              backgroundImage: _firebaseController.getUserPhotoUrl() != null
                  ? NetworkImage(_firebaseController.getUserPhotoUrl()!)
                  : null,
            ),
            onPressed: () {
              _showProfileMenu(context);
            },
          ),
        ],
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

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Preferences.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Preferences.accentColor,
                  child: Text(
                    _firebaseController.getUserDisplayName()?.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundImage: _firebaseController.getUserPhotoUrl() != null
                      ? NetworkImage(_firebaseController.getUserPhotoUrl()!)
                      : null,
                ),
                title: Text(
                  _firebaseController.getUserDisplayName() ?? 'User',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _firebaseController.getUserEmail() ?? '',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Divider(color: Colors.white24),
              ListTile(
                leading: Icon(Icons.logout, color: Preferences.accentColor),
                title: Text('Logout', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet
                  await _firebaseController.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

