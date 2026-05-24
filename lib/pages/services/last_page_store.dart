import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LastPageStore {
  static Future<void> saveLastPage(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_page', route);
  }

  static Future<String?> getLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_page');
  }
}

class LastPageObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    _saveRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) {
      _saveRoute(newRoute);
    }

    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _saveRoute(Route route) {
    final routeName = route.settings.name;

    if (routeName != null && routeName.isNotEmpty) {
      LastPageStore.saveLastPage(routeName);
    }
  }
}
