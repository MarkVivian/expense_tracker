import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_wrapper.dart';
import 'screens/home_screen.dart';
import 'utils/preferences.dart';
import 'utils/AutoBackups.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize auto backups system
  await AutoBackups().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Planner',
      theme: ThemeData(
        primaryColor: Preferences.primaryColor,
        scaffoldBackgroundColor: Preferences.backgroundColor,
        colorScheme: ColorScheme.dark(
          primary: Preferences.primaryColor,
          secondary: Preferences.accentColor,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/home': (context) => HomeScreen(initialPage: ModalRoute.of(context)?.settings.arguments as int?),
      },
    );
  }
}

