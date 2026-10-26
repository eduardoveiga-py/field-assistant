import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'screens/today_screen.dart';
import 'screens/people_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/studies_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isTabletOrDesktop = MediaQuery.of(context).size.width >= 768;

    final screens = [
      TodayScreen(onTabChange: _onTabChange),
      const PeopleScreen(),
      const AppointmentsScreen(),
      const StudiesScreen(),
      const DashboardScreen(),
      const SettingsScreen(),
    ];

    if (isTabletOrDesktop) {
      // Layout para iPad e Navegador Desktop: NavigationRail lateral expansível
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabChange,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Icon(Icons.menu_book, color: AppTheme.primaryBlue, size: 32),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.today), label: Text('Hoje')),
                NavigationRailDestination(icon: Icon(Icons.people), label: Text('Pessoas')),
                NavigationRailDestination(icon: Icon(Icons.calendar_month), label: Text('Agenda')),
                NavigationRailDestination(icon: Icon(Icons.school), label: Text('Estudos')),
                NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('Estatísticas')),
                NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Ajustes')),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      );
    }

    // Layout para iPhone XR: Barra de navegação inferior limpa e ergonômica
    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex > 4 ? 4 : _currentIndex,
        onDestinationSelected: _onTabChange,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Hoje'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Pessoas'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Estudos'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Estatísticas'),
        ],
      ),
    );
  }
}
