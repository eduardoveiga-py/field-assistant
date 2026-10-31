import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_theme.dart';
import '../core/feature_registry.dart';
import 'screens/today_screen.dart';
import 'screens/people_screen.dart';
import 'screens/phone_contacts_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/studies_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/experiences_screen.dart';
import 'screens/research_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/contacts_map_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  AppFeature _currentFeature = AppFeature.today;
  bool _showingSettings = false;

  void _onFeatureSelect(AppFeature feature) {
    setState(() {
      _currentFeature = feature;
      _showingSettings = false;
    });
  }

  void _onSelectSettings() {
    setState(() {
      _showingSettings = true;
    });
  }

  void _onLegacyTabChange(int index) {
    setState(() {
      switch (index) {
        case 0:
          _currentFeature = AppFeature.today;
          _showingSettings = false;
          break;
        case 1:
          _currentFeature = AppFeature.people;
          _showingSettings = false;
          break;
        case 2:
          _currentFeature = AppFeature.phones;
          _showingSettings = false;
          break;
        case 3:
          _currentFeature = AppFeature.agenda;
          _showingSettings = false;
          break;
        case 4:
          _currentFeature = AppFeature.studies;
          _showingSettings = false;
          break;
        case 5:
          _currentFeature = AppFeature.dashboard;
          _showingSettings = false;
          break;
        case 6:
          _currentFeature = AppFeature.experiences;
          _showingSettings = false;
          break;
        case 7:
          _currentFeature = AppFeature.notesResearch;
          _showingSettings = false;
          break;
        case 8:
          _showingSettings = true;
          break;
        default:
          _currentFeature = AppFeature.today;
          _showingSettings = false;
      }
    });
  }

  Widget _buildScreenForCurrentState() {
    if (_showingSettings) {
      return const SettingsScreen();
    }
    switch (_currentFeature) {
      case AppFeature.today:
        return TodayScreen(
          onFeatureNavigate: _onFeatureSelect,
          onTabChange: _onLegacyTabChange,
        );
      case AppFeature.people:
        return const PeopleScreen();
      case AppFeature.phones:
        return const PhoneContactsScreen();
      case AppFeature.agenda:
        return const AppointmentsScreen();
      case AppFeature.studies:
        return const StudiesScreen();
      case AppFeature.dashboard:
        return const DashboardScreen();
      case AppFeature.experiences:
        return const ExperiencesScreen();
      case AppFeature.notesResearch:
        return const ResearchScreen();
      case AppFeature.territoryMaps:
        return const ContactsMapScreen();
    }
  }

  void _showMoreMenuModal(BuildContext context, List<AppFeature> moreFeatures) {
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
              for (final feat in moreFeatures)
                _buildMoreMenuItem(
                  ctx,
                  feature: feat,
                  isSelected: !_showingSettings && _currentFeature == feat,
                  onTap: () {
                    Navigator.pop(ctx);
                    _onFeatureSelect(feat);
                  },
                ),
              // Ajustes é sempre exibido no menu mais
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF94A3B8) : Colors.blueGrey).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings, color: isDark ? const Color(0xFF94A3B8) : Colors.blueGrey, size: 24),
                ),
                title: Text(
                  'Ajustes & Backup',
                  style: TextStyle(
                    fontWeight: _showingSettings ? FontWeight.bold : FontWeight.w600,
                    color: _showingSettings ? AppTheme.primaryBlue : null,
                  ),
                ),
                subtitle: const Text(
                  'Sincronização, exportação de dados e configurações',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: _showingSettings
                    ? const Icon(Icons.check, color: AppTheme.primaryBlue, size: 20)
                    : const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.pop(ctx);
                  _onSelectSettings();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreMenuItem(
    BuildContext ctx, {
    required AppFeature feature,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    Color color;
    switch (feature) {
      case AppFeature.studies:
        color = const Color(0xFF7C3AED);
        break;
      case AppFeature.dashboard:
        color = AppTheme.primaryBlue;
        break;
      case AppFeature.experiences:
        color = const Color(0xFF059669);
        break;
      case AppFeature.notesResearch:
        color = const Color(0xFFD97706);
        break;
      case AppFeature.territoryMaps:
        color = const Color(0xFF0284C7);
        break;
      default:
        color = AppTheme.primaryBlue;
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(feature.icon, color: color, size: 24),
      ),
      title: Text(
        feature.title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? color : null,
        ),
      ),
      subtitle: Text(
        feature.description,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isSelected ? Icon(Icons.check, color: color, size: 20) : const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFeatures = ref.watch(activeFeaturesProvider);

    // Se a feature atual foi desativada e não estamos em ajustes, redireciona com segurança para Hoje
    if (!_showingSettings && !activeFeatures.contains(_currentFeature)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentFeature = AppFeature.today;
          });
        }
      });
    }

    final isTabletOrDesktop = MediaQuery.of(context).size.width >= 768;

    if (isTabletOrDesktop) {
      // Lista completa de destinos do NavigationRail para Desktop/Tablet
      // Mantém a ordem esperada pelos testes: Hoje, Pessoas, Telefones, Agenda, Estudos, Estatísticas, Experiências, Anotações, Ajustes
      final railDestinations = <NavigationRailDestination>[];
      final railFeatures = <AppFeature?>[];

      final railCandidates = [
        AppFeature.today,
        AppFeature.people,
        AppFeature.phones,
        AppFeature.agenda,
        AppFeature.studies,
        AppFeature.dashboard,
        AppFeature.experiences,
        AppFeature.notesResearch,
      ];

      for (final f in railCandidates) {
        if (!activeFeatures.contains(f)) continue;
        railDestinations.add(
          NavigationRailDestination(
            icon: Icon(f.icon),
            selectedIcon: Icon(f.icon),
            label: Text(f.title.split(' ').first), // Hoje, Pessoas, Telefones, Agenda, Estudos, Estatísticas, etc.
          ),
        );
        railFeatures.add(f);
      }

      // Adiciona Ajustes no final do Rail
      railDestinations.add(
        const NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Ajustes'),
        ),
      );
      railFeatures.add(null);

      int selectedRailIndex = _showingSettings
          ? railDestinations.length - 1
          : railFeatures.indexOf(_currentFeature);
      if (selectedRailIndex < 0) selectedRailIndex = 0;

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
                        selectedIndex: selectedRailIndex,
                        onDestinationSelected: (idx) {
                          if (idx >= 0 && idx < railFeatures.length) {
                            final targetFeat = railFeatures[idx];
                            if (targetFeat == null) {
                              _onSelectSettings();
                            } else {
                              _onFeatureSelect(targetFeat);
                            }
                          }
                        },
                        labelType: NavigationRailLabelType.all,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Icon(Icons.menu_book, color: AppTheme.primaryBlue, size: 30),
                        ),
                        destinations: railDestinations,
                      ),
                    ),
                  ),
                );
              },
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _buildScreenForCurrentState()),
          ],
        ),
      );
    }

    // Layout para Mobile: Barra inferior com recursos principais + botão "Mais"
    // Features primárias na barra: até 5 primeiros itens ativos
    // Por padrão: Hoje, Pessoas, Telefones, Agenda, Estudos
    final primaryBarFeatures = <AppFeature>[];
    final moreFeatures = <AppFeature>[];

    final primaryCandidates = [
      AppFeature.today,
      AppFeature.people,
      AppFeature.phones,
      AppFeature.agenda,
      AppFeature.studies,
    ];

    for (final cand in primaryCandidates) {
      if (activeFeatures.contains(cand) && primaryBarFeatures.length < 5) {
        primaryBarFeatures.add(cand);
      }
    }

    for (final f in activeFeatures) {
      if (!primaryBarFeatures.contains(f)) {
        moreFeatures.add(f);
      }
    }

    final barDestinations = <NavigationDestination>[];
    for (final f in primaryBarFeatures) {
      barDestinations.add(
        NavigationDestination(
          icon: Icon(f.icon, size: 22),
          selectedIcon: Icon(f.icon, size: 22),
          label: f.title.split(' ').first,
        ),
      );
    }

    // Botão Mais
    barDestinations.add(
      const NavigationDestination(
        icon: Icon(Icons.more_horiz, size: 22),
        selectedIcon: Icon(Icons.more_horiz, size: 22),
        label: 'Mais',
      ),
    );

    int barSelectedIndex;
    if (_showingSettings || moreFeatures.contains(_currentFeature)) {
      barSelectedIndex = primaryBarFeatures.length; // 'Mais'
    } else {
      barSelectedIndex = primaryBarFeatures.indexOf(_currentFeature);
      if (barSelectedIndex < 0) barSelectedIndex = 0;
    }

    return Scaffold(
      body: _buildScreenForCurrentState(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: barSelectedIndex,
        onDestinationSelected: (idx) {
          if (idx == primaryBarFeatures.length) {
            _showMoreMenuModal(context, moreFeatures);
          } else if (idx < primaryBarFeatures.length) {
            _onFeatureSelect(primaryBarFeatures[idx]);
          }
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
        destinations: barDestinations,
      ),
    );
  }
}
