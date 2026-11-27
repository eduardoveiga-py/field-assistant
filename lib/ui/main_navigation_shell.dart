import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/i18n/app_locale_strings.dart';
import '../appointments/calendar_provider.dart';
import '../appointments/calendar_sync_coordinator.dart';
import '../navigation/app_navigation_controller.dart';
import '../sync/platform_sync_triggers.dart';
import '../sync/supabase_sync_service.dart';
import '../sync/sync_owner_guard.dart';
import 'providers.dart';
import '../core/feature_registry.dart';
import 'screens/today_screen.dart';
import 'screens/people_screen.dart';
import 'screens/phone_contacts_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/studies_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/experiences_screen.dart';
import 'screens/research_screen.dart';
import 'screens/ticuna_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/contacts_map_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/knowledge_base_screen.dart';
import 'screens/official_documents_screen.dart';
import 'screens/picture_bank_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with WidgetsBindingObserver {
  Timer? _syncTimer;
  Timer? _syncDebounce;
  StreamSubscription<({int pending, int failed, int conflict})>? _queueSub;
  PlatformSyncTriggersHandle? _platformTriggers;
  int _lastObservedPending = 0;
  bool _autoPushPausedOnStall = false;
  bool _autoSyncRunning = false;
  bool _syncRequestedWhileRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _autoSync(),
    );
    _platformTriggers = registerPlatformSyncTriggers(
      onSyncTrigger: () {
        _autoPushPausedOnStall = false;
        _scheduleSync(delay: const Duration(milliseconds: 650));
      },
    );
    _queueSub = ref.read(repositoryProvider).watchSyncQueueCounts().listen((
      counts,
    ) {
      if (counts.pending <= 0) {
        _lastObservedPending = 0;
        _autoPushPausedOnStall = false;
        return;
      }
      final grewOrChanged = counts.pending != _lastObservedPending;
      final increased = counts.pending > _lastObservedPending;
      _lastObservedPending = counts.pending;
      if (increased || (grewOrChanged && !_autoPushPausedOnStall)) {
        _autoPushPausedOnStall = false;
        _scheduleSync(delay: const Duration(milliseconds: 1400));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoSync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _autoPushPausedOnStall = false;
      _scheduleSync(delay: const Duration(milliseconds: 800));
    }
  }

  void _scheduleSync({Duration delay = const Duration(milliseconds: 900)}) {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(delay, _autoSync);
  }

  Future<void> _autoSync() async {
    if (!mounted) return;
    if (_autoSyncRunning) {
      _syncRequestedWhileRunning = true;
      return;
    }
    try {
      if (!SupabaseSyncService.isInitialized ||
          Supabase.instance.client.auth.currentSession == null) {
        return;
      }
      _autoSyncRunning = true;
      final repo = ref.read(repositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final guard = await SyncOwnerGuard.evaluate(
        db: repo.db,
        authenticatedUserId: userId,
      );
      if (!guard.isAllowed) return;
      if (!mounted) return;
      final syncService = ref.read(supabaseSyncServiceProvider);
      await syncService.ensureRealtimeStarted(
        onRemoteActivity: () {
          if (mounted) {
            _autoPushPausedOnStall = false;
            _scheduleSync(delay: const Duration(milliseconds: 450));
          }
        },
      );
      if (!mounted) return;
      final syncResult = await syncService.sync();
      final currentCounts = await repo.getPendingSyncOperations();
      if (currentCounts.isNotEmpty &&
          syncResult.successCount == 0 &&
          (!syncResult.success || syncResult.failureCount > 0)) {
        _autoPushPausedOnStall = true;
      } else {
        _autoPushPausedOnStall = false;
      }
      if (!mounted) return;
      final coordinator = ref.read(calendarSyncCoordinatorProvider);
      final connected = <CalendarProviderType>{};
      for (final provider in coordinator.allProviders) {
        if (!await provider.isAuthorized()) continue;
        if (provider.providerType == CalendarProviderType.appleEventKit &&
            await provider.getSelectedCalendarId() == null) {
          continue;
        }
        connected.add(provider.providerType);
      }
      if (connected.isNotEmpty && mounted) {
        await coordinator.syncAll(providers: connected);
      }
    } catch (error) {
      debugPrint('Sincronização automática adiada: $error');
    } finally {
      _autoSyncRunning = false;
      if (_syncRequestedWhileRunning && mounted) {
        _syncRequestedWhileRunning = false;
        _scheduleSync(delay: const Duration(milliseconds: 450));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _syncDebounce?.cancel();
    unawaited(_queueSub?.cancel());
    _platformTriggers?.dispose();
    super.dispose();
  }

  AppFeature _currentFeature = AppFeature.today;
  bool _showingSettings = false;
  final Map<AppFeature, int> _featureSubTabs = {};
  int _navEpoch = 0;

  void _onFeatureSelect(AppFeature feature, {int? subTabIndex}) {
    setState(() {
      _currentFeature = feature;
      _showingSettings = false;
      if (subTabIndex != null) {
        _featureSubTabs[feature] = subTabIndex;
        _navEpoch++;
      }
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
        case 9:
          _currentFeature = AppFeature.ticuna;
          _showingSettings = false;
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
      case AppFeature.ticuna:
        return const TicunaScreen();
      case AppFeature.territoryMaps:
        return const ContactsMapScreen();
      case AppFeature.inbox:
        return InboxScreen(
          initialTabIndex: _featureSubTabs[AppFeature.inbox],
          navigationEpoch: _navEpoch,
        );
      case AppFeature.tasksProjects:
        return TasksScreen(
          initialTabIndex: _featureSubTabs[AppFeature.tasksProjects],
          navigationEpoch: _navEpoch,
        );
      case AppFeature.knowledge:
        return KnowledgeBaseScreen(
          initialTabIndex: _featureSubTabs[AppFeature.knowledge],
          navigationEpoch: _navEpoch,
        );
      case AppFeature.pictureBank:
        return const PictureBankScreen();
      case AppFeature.officialDocuments:
        return const OfficialDocumentsScreen();
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _showingSettings
                        ? (isDark
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF2563EB))
                              .withValues(alpha: 0.14)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      _showingSettings
                          ? Icons.settings
                          : Icons.settings_outlined,
                      color: _showingSettings
                          ? (isDark
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF2563EB))
                          : (isDark
                                ? const Color(0xFF8B95A5)
                                : const Color(0xFF64748B)),
                      size: 22,
                    ),
                  ),
                ),
                title: Text(
                  'Ajustes & Backup',
                  style: TextStyle(
                    fontWeight: _showingSettings
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: _showingSettings
                        ? (isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF2563EB))
                        : (isDark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A)),
                  ),
                ),
                subtitle: Text(
                  'Sincronização, exportação de dados e configurações',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                trailing: _showingSettings
                    ? Icon(
                        Icons.check,
                        color: isDark
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF2563EB),
                        size: 20,
                      )
                    : Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? const Color(0xFF8B95A5)
                            : const Color(0xFF64748B),
                        size: 18,
                      ),
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

  static IconData _getFeatureIcon(
    AppFeature feature, {
    required bool isSelected,
  }) {
    switch (feature) {
      case AppFeature.today:
        return isSelected ? Icons.today : Icons.today_outlined;
      case AppFeature.people:
        return isSelected ? Icons.people : Icons.people_outline;
      case AppFeature.phones:
        return isSelected ? Icons.phone : Icons.phone_outlined;
      case AppFeature.agenda:
        return isSelected
            ? Icons.calendar_month
            : Icons.calendar_month_outlined;
      case AppFeature.studies:
        return isSelected ? Icons.school : Icons.school_outlined;
      case AppFeature.dashboard:
        return isSelected ? Icons.analytics : Icons.analytics_outlined;
      case AppFeature.experiences:
        return isSelected ? Icons.auto_stories : Icons.auto_stories_outlined;
      case AppFeature.notesResearch:
        return isSelected ? Icons.note_alt : Icons.note_alt_outlined;
      case AppFeature.ticuna:
        return isSelected ? Icons.translate : Icons.translate_outlined;
      case AppFeature.territoryMaps:
        return isSelected ? Icons.explore : Icons.explore_outlined;
      case AppFeature.inbox:
        return isSelected ? Icons.mail : Icons.mail_outline;
      case AppFeature.pictureBank:
        return isSelected ? Icons.photo_library : Icons.photo_library_outlined;
      case AppFeature.officialDocuments:
        return isSelected ? Icons.description : Icons.description_outlined;
      case AppFeature.tasksProjects:
        return isSelected ? Icons.task_alt : Icons.task_alt_outlined;
      case AppFeature.knowledge:
        return isSelected ? Icons.menu_book : Icons.menu_book_outlined;
    }
  }

  static Widget _buildNavIcon(
    BuildContext context, {
    required IconData icon,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final inactiveColor = isDark
        ? const Color(0xFF8B95A5)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: isSelected
          ? BoxDecoration(
              color: primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Icon(icon, size: 22, color: isSelected ? primary : inactiveColor),
    );
  }

  Widget _buildMoreMenuItem(
    BuildContext ctx, {
    required AppFeature feature,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
    final inactiveColor = isDark
        ? const Color(0xFF8B95A5)
        : const Color(0xFF64748B);
    final icon = _getFeatureIcon(feature, isSelected: isSelected);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.14)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Icon(
            icon,
            color: isSelected ? primary : inactiveColor,
            size: 22,
          ),
        ),
      ),
      title: Text(
        feature.title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected
              ? primary
              : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
        ),
      ),
      subtitle: Text(
        feature.description,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: primary, size: 20)
          : Icon(Icons.chevron_right, color: inactiveColor, size: 18),
      onTap: onTap,
    );
  }

  String _getFeatureLabel(AppFeature f, AppLocaleStrings strings) {
    switch (f) {
      case AppFeature.today:
        return strings.navToday;
      case AppFeature.people:
        return strings.navPeople;
      case AppFeature.phones:
        return strings.navPhones;
      case AppFeature.agenda:
        return strings.navAgenda;
      case AppFeature.studies:
        return strings.navStudies.split(' ').first;
      case AppFeature.dashboard:
        return strings.navDashboard.split(' ').first;
      case AppFeature.experiences:
        return strings.navExperiences.split(' ').first;
      case AppFeature.notesResearch:
        return strings.navNotes.split(' ').first;
      case AppFeature.ticuna:
        return strings.navLanguages.split(' ').first;
      case AppFeature.territoryMaps:
        return strings.navTerritoryMaps.split(' ').first;
      case AppFeature.inbox:
        return 'Inbox';
      case AppFeature.tasksProjects:
        return 'Tarefas';
      case AppFeature.knowledge:
        return 'Conhecimento';
      case AppFeature.pictureBank:
        return 'Gravuras';
      case AppFeature.officialDocuments:
        return 'Cartas & Atas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeFeatures = ref.watch(activeFeaturesProvider);
    final strings = ref.watch(appStringsProvider);

    ref.listen<AppNavigationRequest?>(appNavigationProvider, (_, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(appNavigationProvider.notifier).clearIfHandled(next.requestId);
        if (activeFeatures.contains(next.feature)) {
          _onFeatureSelect(next.feature, subTabIndex: next.subTabIndex);
        }
      });
    });

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
    final isMapFullscreen = ref.watch(isMapFullscreenProvider);

    if (isMapFullscreen &&
        _currentFeature == AppFeature.territoryMaps &&
        !_showingSettings) {
      return Scaffold(body: _buildScreenForCurrentState());
    }

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
        AppFeature.ticuna,
        AppFeature.territoryMaps,
        AppFeature.inbox,
        AppFeature.tasksProjects,
        AppFeature.knowledge,
        AppFeature.pictureBank,
        AppFeature.officialDocuments,
      ];

      for (final f in railCandidates) {
        if (!activeFeatures.contains(f)) continue;
        final iconUnselected = _getFeatureIcon(f, isSelected: false);
        final iconSelected = _getFeatureIcon(f, isSelected: true);
        railDestinations.add(
          NavigationRailDestination(
            icon: Semantics(
              label: 'Navegar para ${_getFeatureLabel(f, strings)}',
              child: _buildNavIcon(
                context,
                icon: iconUnselected,
                isSelected: false,
              ),
            ),
            selectedIcon: Semantics(
              selected: true,
              label: 'Navegar para ${_getFeatureLabel(f, strings)}',
              child: _buildNavIcon(
                context,
                icon: iconSelected,
                isSelected: true,
              ),
            ),
            label: Text(_getFeatureLabel(f, strings)),
          ),
        );
        railFeatures.add(f);
      }

      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Adiciona Ajustes no final do Rail
      railDestinations.add(
        NavigationRailDestination(
          icon: Semantics(
            label: 'Navegar para Ajustes e Backup',
            child: _buildNavIcon(
              context,
              icon: Icons.settings_outlined,
              isSelected: false,
            ),
          ),
          selectedIcon: Semantics(
            selected: true,
            label: 'Navegar para Ajustes e Backup',
            child: _buildNavIcon(
              context,
              icon: Icons.settings,
              isSelected: true,
            ),
          ),
          label: Text(strings.navSettings.split(' ').first),
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
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        backgroundColor: isDark
                            ? const Color(0xFF0E131F)
                            : const Color(0xFFF1F5F9),
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
                        selectedLabelTextStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF2563EB),
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF8B95A5)
                              : const Color(0xFF64748B),
                        ),
                        indicatorColor: Colors.transparent,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Icon(
                            Icons.menu_book,
                            color: isDark
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFF2563EB),
                            size: 28,
                          ),
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
      final label = _getFeatureLabel(f, strings);
      final iconUnselected = _getFeatureIcon(f, isSelected: false);
      final iconSelected = _getFeatureIcon(f, isSelected: true);
      barDestinations.add(
        NavigationDestination(
          icon: Semantics(
            label: 'Aba $label',
            child: _buildNavIcon(
              context,
              icon: iconUnselected,
              isSelected: false,
            ),
          ),
          selectedIcon: Semantics(
            selected: true,
            label: 'Aba $label',
            child: _buildNavIcon(context, icon: iconSelected, isSelected: true),
          ),
          label: label,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Botão Mais
    barDestinations.add(
      NavigationDestination(
        icon: Semantics(
          label: 'Abrir menu Mais recursos do ministério',
          child: _buildNavIcon(
            context,
            icon: Icons.more_horiz,
            isSelected: false,
          ),
        ),
        selectedIcon: Semantics(
          selected: true,
          label: 'Abrir menu Mais recursos do ministério',
          child: _buildNavIcon(
            context,
            icon: Icons.more_horiz,
            isSelected: true,
          ),
        ),
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
        backgroundColor: isDark
            ? const Color(0xFF0E131F)
            : const Color(0xFFF1F5F9),
        selectedIndex: barSelectedIndex,
        onDestinationSelected: (idx) {
          if (idx == primaryBarFeatures.length) {
            _showMoreMenuModal(context, [
              ...primaryBarFeatures,
              ...moreFeatures,
            ]);
          } else if (idx < primaryBarFeatures.length) {
            _onFeatureSelect(primaryBarFeatures[idx]);
          }
        },
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.transparent,
        destinations: barDestinations,
      ),
    );
  }
}
