import 'package:flutter/material.dart';
import 'app_state.dart';
import 'customer_home_screen.dart';
import 'home_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    switch (state.accountRole) {
      case AccountRole.stationOwner:
        return const HomeScreen();
      case AccountRole.customer:
        return const CustomerHomeScreen();
    }
  }
}
