import 'package:flutter/material.dart';
import '../utils/preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Preferences.splashDuration, () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Preferences.splashGradient,
        ),
        child: Center(
          child: Image.asset(
            Preferences.placeholderImage,
            width: Preferences.splashImageSize,
            height: Preferences.splashImageSize,
          ),
        ),
      ),
    );
  }
}

