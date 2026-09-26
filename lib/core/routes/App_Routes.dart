import 'package:devicelocunlock/screens/home_screen.dart';
import 'package:devicelocunlock/screens/login_screen.dart';
import 'package:devicelocunlock/screens/lock_screen.dart';
import 'package:flutter/material.dart';
import 'Routes_name.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    // '/' রুটটি সরানো হয়েছে যাতে এটি স্ট্যাকের নিচে জমা না থাকে
    RouteName.loginScreen: (context) => const LoginScreen(),
    RouteName.homeScreen: (context) => const HomeScreen(),
    RouteName.lockScreen: (context) => const LockScreen(),
  };
}
