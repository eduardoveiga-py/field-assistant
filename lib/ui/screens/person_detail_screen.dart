import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../database/repository.dart';
import '../../appointments/availability_engine.dart';
import '../../appointments/schedule_release_coordinator.dart';
import '../../publications/publication_catalog.dart';
import '../../publications/publication_link_resolver.dart';
import '../../dashboard/counting_rules.dart';
import '../providers.dart';
import '../widgets/global_appointment_scheduling_section.dart';
import '../widgets/managed_text_controllers.dart';
import '../../media/person_photos_manager.dart';
import '../../media/media_picker_helper.dart';
import '../widgets/person_hand_off_dialog.dart';
import '../widgets/person_publications_tab.dart';
import '../widgets/person_family_ties_tab.dart';
import '../widgets/person_photos_tab.dart';
import '../../publications/lff_book_catalog.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/geocoding_service.dart';
import '../widgets/map_location_picker_dialog.dart';
import '../../territory/sector_manager.dart';
import 'contacts_map_screen.dart';
import '../../contacts/doorstep_briefing_helper.dart';
import '../widgets/person_deletion_dialog.dart';
import '../widgets/doorstep_briefing_card.dart';
import '../../voice_notes/voice_notes_manager.dart';
import '../../voice_notes/voice_note_models.dart';
import '../widgets/quick_voice_note_dialog.dart';
import '../widgets/doorstep_return_booking_dialog.dart';
import '../../core/feature_registry.dart';

import '../widgets/person_detail/person_unified_timeline_section.dart';

export '../widgets/person_detail/person_unified_timeline_section.dart'
    show
        PersonUnifiedTimelineSection,
        PersonTimelineStep,
        PersonMetricSmallCard;

part 'person_detail/person_study_dialogs.dart';
part 'person_detail/person_visit_and_profile_dialogs.dart';
part 'person_detail/person_visits_tab.dart';
part 'person_detail/person_study_and_notes_tabs.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;

  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  // Cache de rascunho de preenchimento para visita rápida da pessoa
  static final Map<String, Map<String, dynamic>> _quickVisitDrafts = {};
  late Future<PersonEntry?> _fallbackPersonFuture;

  @override
  void initState() {
    super.initState();
    _fallbackPersonFuture = ref
        .read(repositoryProvider)
        .getPersonById(widget.personId);
  }

  @override
  void didUpdateWidget(covariant PersonDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.personId != widget.personId) {
      _fallbackPersonFuture = ref
          .read(repositoryProvider)
          .getPersonById(widget.personId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final participants = ref.watch(studyParticipantsStreamProvider).value ?? [];

    final person = people.where((p) => p.id == widget.personId).firstOrNull;

    if (person == null) {
      return FutureBuilder<PersonEntry?>(
        future: _fallbackPersonFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final fallbackPerson = snapshot.data;
          if (fallbackPerson == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Contato')),
              body: const Center(child: Text('Contato não encontrado.')),
            );
          }
          return _buildMainScaffold(
            context,
            repo,
            fallbackPerson,
            studies,
            participants,
          );
        },
      );
    }

    return _buildMainScaffold(context, repo, person, studies, participants);
  }

  // ---------------------------------------------------------------------------
  // MÉTODOS DE PARSING E PERSISTÊNCIA ESTRUTURADA EM JSON (Aba 3 e Aba 4)
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _parseNotes(String? raw) {
    return DoorstepBriefingHelper.parseNotes(raw);
  }

  Widget _buildMainScaffold(
    BuildContext context,
    AppRepository repo,
    PersonEntry person,
    List<BibleStudyEntry> studies,
    List<StudyParticipantEntry> participants,
  ) {
    // Localiza estudo bíblico vinculado a esta pessoa
    final linkedParticipant = participants
        .where((p) => p.personId == person.id && p.deletedAt == null)
        .firstOrNull;
    final linkedStudy = linkedParticipant != null
        ? studies
              .where(
                (s) => s.id == linkedParticipant.studyId && s.deletedAt == null,
              )
              .firstOrNull
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isStudiesEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.studies),
    );
    final isAgendaEnabled = ref.watch(
      isFeatureEnabledProvider(AppFeature.agenda),
    );

    final tabs = <Widget>[
      const Tab(
        icon: Icon(Icons.history_edu),
        text: 'Visitas & Linha do Tempo',
      ),
      if (isStudiesEnabled)
        const Tab(icon: Icon(Icons.school), text: 'Estudo Bíblico'),
      const Tab(icon: Icon(Icons.photo_library), text: 'Fotos'),
      const Tab(icon: Icon(Icons.auto_stories), text: 'Publicações & Pedidos'),
      const Tab(icon: Icon(Icons.family_restroom), text: 'Família & Vínculos'),
      const Tab(
        icon: Icon(Icons.note_alt_outlined),
        text: 'Necessidades & Obs.',
      ),
      const Tab(icon: Icon(Icons.track_changes), text: 'Alvos & Tarefas'),
    ];

    final tabViews = <Widget>[
      // TAB 1: VISITAS & CONTATO
      _buildVisitsAndContactTab(
        context,
        repo,
        person,
        isStudiesEnabled ? linkedStudy : null,
        isDark,
        isStudiesEnabled,
        isAgendaEnabled,
      ),

      // TAB 2: ESTUDO BÍBLICO (Progresso, Publicações, JW Library e Sessões)
      if (isStudiesEnabled)
        _buildBibleStudyTab(context, repo, person, linkedStudy, isDark),

      // TAB 3: FOTOS DA PESSOA / RESIDÊNCIA / ESTUDO
      PersonPhotosTab(person: person),

      // TAB 4: PUBLICAÇÕES & PEDIDOS (Checklist e Pedidos)
      PersonPublicationsTab(person: person),

      // TAB 5: FAMÍLIA & VÍNCULOS (Relacionamentos bidirecionais automáticos)
      PersonFamilyTiesTab(person: person),

      // TAB 6: NECESSIDADES & OBSERVAÇÕES
      _buildNeedsAndNotesTab(context, repo, person, isDark),

      // TAB 7: ALVOS & TAREFAS
      _buildTargetsAndTasksTab(context, repo, person, isDark),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            header: true,
            label: 'Ficha do contato ${person.name}',
            child: Text(person.name),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Editar dados do contato ${person.name}',
              child: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar Dados do Contato',
                onPressed: () => _showEditPersonDialog(context, repo, person),
              ),
            ),
            Semantics(
              button: true,
              label: 'Excluir contato ${person.name}',
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.alertRed,
                ),
                tooltip: 'Excluir Contato',
                onPressed: () async {
                  final deleted = await PersonDeletionDialog.show(
                    context,
                    person: person,
                  );
                  if (deleted == true && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryBlue,
            tabs: tabs,
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }
}
