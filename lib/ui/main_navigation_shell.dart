import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'screens/today_screen.dart';
import 'screens/people_screen.dart';
import 'screens/phone_contacts_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/studies_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/experiences_screen.dart';
import 'screens/research_screen.dart';
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

  void _showMoreMenuModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mais Recursos do Ministério',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMoreMenuItem(
                ctx,
                icon: Icons.school,
                color: const Color(0xFF7C3AED),
                title: 'Estudos Bíblicos',
                subtitle: 'Acompanhamento do livro Seja Feliz Para Sempre!, lições e frequência',
                index: 4,
              ),
              _buildMoreMenuItem(
                ctx,
                icon: Icons.analytics,
                color: AppTheme.primaryBlue,
                title: 'Estatísticas & Progresso',
                subtitle: 'Relatório oficial de campo, métricas de estudos e progresso da obra',
                index: 5,
              ),
              _buildMoreMenuItem(
                ctx,
                icon: Icons.auto_stories,
                color: const Color(0xFF059669),
                title: 'Experiências de Campo',
                subtitle: 'Registro de ocasiões marcantes com fotos, áudios e exportação',
                index: 6,
              ),
              _buildMoreMenuItem(
                ctx,
                icon: Icons.note_alt_outlined,
                color: const Color(0xFFD97706),
                title: 'Anotações & Pesquisas',
                subtitle: 'Anotações rápidas, respostas bíblicas e apresentação da semana',
                index: 7,
              ),
              _buildMoreMenuItem(
                ctx,
                icon: Icons.settings,
                color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey,
                title: 'Ajustes & Backup',
                subtitle: 'Sincronização, exportação de dados e configurações',
                index: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? color : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isSelected ? Icon(Icons.check, color: color, size: 20) : const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        Navigator.pop(ctx);
        _onTabChange(index);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTabletOrDesktop = MediaQuery.of(context).size.width >= 768;

    final screens = [
      TodayScreen(onTabChange: _onTabChange), // 0
      const PeopleScreen(), // 1
      const PhoneContactsScreen(), // 2
      const AppointmentsScreen(), // 3
      const StudiesScreen(), // 4
      const DashboardScreen(), // 5
      const ExperiencesScreen(), // 6
      const ResearchScreen(), // 7
      const SettingsScreen(), // 8
    ];

    if (isTabletOrDesktop) {
      // Layout para Desktop / Web / iPad: NavigationRail lateral rolável sem risco de overflow
      return Scaffold(
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: _onTabChange,
                        labelType: NavigationRailLabelType.all,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Icon(Icons.menu_book, color: AppTheme.primaryBlue, size: 30),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.today_outlined),
                            selectedIcon: Icon(Icons.today),
                            label: Text('Hoje'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people),
                            label: Text('Pessoas'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.phone_outlined),
                            selectedIcon: Icon(Icons.phone),
                            label: Text('Telefones'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.calendar_month_outlined),
                            selectedIcon: Icon(Icons.calendar_month),
                            label: Text('Agenda'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.school_outlined),
                            selectedIcon: Icon(Icons.school),
                            label: Text('Estudos'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.analytics_outlined),
                            selectedIcon: Icon(Icons.analytics),
                            label: Text('Estatísticas'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.auto_stories_outlined),
                            selectedIcon: Icon(Icons.auto_stories),
                            label: Text('Experiências'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.note_alt_outlined),
                            selectedIcon: Icon(Icons.note_alt),
                            label: Text('Anotações'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: Text('Ajustes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      );
    }

    // Layout para Mobile (iPhone XR / Android): Bottom NavigationBar ergonômica com menu Mais
    final barSelectedIndex = _currentIndex <= 4 ? _currentIndex : 5;

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: barSelectedIndex,
        onDestinationSelected: (idx) {
          if (idx == 5) {
            _showMoreMenuModal(context);
          } else {
            _onTabChange(idx);
          }
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined, size: 22),
            selectedIcon: Icon(Icons.today, size: 22),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, size: 22),
            selectedIcon: Icon(Icons.people, size: 22),
            label: 'Pessoas',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_outlined, size: 22),
            selectedIcon: Icon(Icons.phone, size: 22),
            label: 'Telefones',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, size: 22),
            selectedIcon: Icon(Icons.calendar_month, size: 22),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined, size: 22),
            selectedIcon: Icon(Icons.school, size: 22),
            label: 'Estudos',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz, size: 22),
            selectedIcon: Icon(Icons.more_horiz, size: 22),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}
