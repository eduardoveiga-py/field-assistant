import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/feature_registry.dart';
import '../providers.dart';
import 'person_detail_screen.dart';
import 'phone_contacts_screen.dart';
import 'research_screen.dart';
import 'appointments_screen.dart';
import 'studies_screen.dart';

enum GlobalSearchResultType {
  person('Pessoa', Icons.person, AppTheme.primaryBlue),
  phone('Telefone', Icons.phone, AppTheme.accentTeal),
  voiceNote('Nota de Voz', Icons.mic, Color(0xFF10B981)),
  research('Pesquisa Bíblica', Icons.menu_book, Color(0xFFD97706)),
  appointment('Compromisso', Icons.event, Color(0xFF2563EB)),
  study('Estudo Bíblico', Icons.school, Color(0xFF7C3AED));

  final String label;
  final IconData icon;
  final Color color;
  const GlobalSearchResultType(this.label, this.icon, this.color);
}

class GlobalSearchResultItem {
  final String id;
  final String title;
  final String subtitle;
  final String? snippet;
  final GlobalSearchResultType type;
  final VoidCallback onTap;

  GlobalSearchResultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.snippet,
    required this.type,
    required this.onTap,
  });
}

class GlobalSearchDelegate extends SearchDelegate<void> {
  final WidgetRef ref;

  GlobalSearchDelegate({required this.ref})
      : super(
          searchFieldLabel: 'Buscar pessoas, telefones, notas, estudos...',
          searchFieldStyle: const TextStyle(fontSize: 15),
        );

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Limpar busca',
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Voltar',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Busca Global Unificada',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'Digite qualquer termo para buscar simultaneamente em pessoas, telefones, notas de voz, estudos bíblicos, artigos de pesquisa e agenda.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final repo = ref.watch(repositoryProvider);
    final db = repo.db;
    final isStudiesEnabled = ref.watch(isFeatureEnabledProvider(AppFeature.studies));
    final isAgendaEnabled = ref.watch(isFeatureEnabledProvider(AppFeature.agenda));
    final isResearchEnabled = ref.watch(isFeatureEnabledProvider(AppFeature.notesResearch));
    final isPhonesEnabled = ref.watch(isFeatureEnabledProvider(AppFeature.phones));


    return FutureBuilder<List<GlobalSearchResultItem>>(
      future: _performSearch(
        db: db,
        repo: repo,
        query: cleanQuery,
        context: context,
        isStudiesEnabled: isStudiesEnabled,
        isAgendaEnabled: isAgendaEnabled,
        isResearchEnabled: isResearchEnabled,
        isPhonesEnabled: isPhonesEnabled,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum resultado para "$query"',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tente buscar por partes do nome, endereço, número ou tema.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = results[index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.type.icon, color: item.type.color, size: 20),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  if (item.snippet != null && item.snippet!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.snippet!,
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              trailing: Chip(
                label: Text(item.type.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onTap: () {
                close(context, null);
                item.onTap();
              },
            );
          },
        );
      },
    );
  }

  Future<List<GlobalSearchResultItem>> _performSearch({
    required dynamic db,
    required dynamic repo,
    required String query,
    required BuildContext context,
    required bool isStudiesEnabled,
    required bool isAgendaEnabled,
    required bool isResearchEnabled,
    required bool isPhonesEnabled,
  }) async {
    final results = <GlobalSearchResultItem>[];

    // 1. Pessoas
    try {
      final people = await repo.getAllPeople();
      for (final p in people) {
        if (p.deletedAt != null) continue;
        final nameMatch = p.name.toLowerCase().contains(query);
        final addrMatch = p.address?.toLowerCase().contains(query) ?? false;
        final noteMatch = p.notes?.toLowerCase().contains(query) ?? false;
        final nextMatch = p.nextActionNote?.toLowerCase().contains(query) ?? false;

        if (nameMatch || addrMatch || noteMatch || nextMatch) {
          results.add(
            GlobalSearchResultItem(
              id: p.id,
              title: p.name,
              subtitle: p.address ?? 'Sem endereço cadastrado',
              snippet: noteMatch ? p.notes : (nextMatch ? p.nextActionNote : null),
              type: GlobalSearchResultType.person,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: p.id)));
              },
            ),
          );
        }
      }
    } catch (_) {}

    // 2. Telefones (se módulo ativo)
    if (isPhonesEnabled) {
      try {
        final phones = await repo.getAllPhoneContacts();
        for (final ph in phones) {
          if (ph.deletedAt != null) continue;
          final nameMatch = ph.name.toLowerCase().contains(query);
          final phoneMatch = ph.phone.replaceAll(RegExp(r'\D'), '').contains(query) || ph.phone.contains(query);
          final notesMatch = ph.notes?.toLowerCase().contains(query) ?? false;

          if (nameMatch || phoneMatch || notesMatch) {
            results.add(
              GlobalSearchResultItem(
                id: ph.id,
                title: ph.name,
                subtitle: 'Telefone: ${ph.phone}',
                snippet: notesMatch ? ph.notes : null,
                type: GlobalSearchResultType.phone,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneContactsScreen()));
                },
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 3. Notas de Voz
    try {
      final voiceNotes = await db.select(db.voiceNotes).get();
      for (final vn in voiceNotes) {
        if (vn.deletedAt != null) continue;
        final textMatch = vn.transcription.toLowerCase().contains(query);
        final doubtMatch = vn.extractedPendingDoubt?.toLowerCase().contains(query) ?? false;

        if (textMatch || doubtMatch) {
          results.add(
            GlobalSearchResultItem(
              id: vn.id,
              title: 'Nota de Voz (${vn.audioDurationSeconds}s)',
              subtitle: 'Transcrição de áudio gravado',
              snippet: vn.transcription,
              type: GlobalSearchResultType.voiceNote,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: vn.personId)));
              },
            ),
          );
        }
      }
    } catch (_) {}

    // 4. Artigos de Pesquisa (se módulo ativo)
    if (isResearchEnabled) {
      try {
        final articles = await db.select(db.researchArticles).get();
        for (final a in articles) {
          if (a.deletedAt != null) continue;
          final titleMatch = a.title.toLowerCase().contains(query);
          final scriptMatch = a.scriptures?.toLowerCase().contains(query) ?? false;
          final notesMatch = a.notes?.toLowerCase().contains(query) ?? false;

          if (titleMatch || scriptMatch || notesMatch) {
            results.add(
              GlobalSearchResultItem(
                id: a.id,
                title: a.title,
                subtitle: 'Categoria: ${a.category} • Textos: ${a.scriptures ?? ""}',
                snippet: notesMatch ? a.notes : null,
                type: GlobalSearchResultType.research,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ResearchScreen()));
                },
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 5. Compromissos e Agenda (se módulo ativo)
    if (isAgendaEnabled) {
      try {
        final appts = await repo.getAllAppointments();
        for (final a in appts) {
          if (a.deletedAt != null) continue;
          final titleMatch = a.title.toLowerCase().contains(query);
          final notesMatch = a.locationNotes?.toLowerCase().contains(query) ?? false;

          if (titleMatch || notesMatch) {
            results.add(
              GlobalSearchResultItem(
                id: a.id,
                title: a.title,
                subtitle: 'Compromisso em ${a.startTime.day}/${a.startTime.month} • Status: ${a.status}',
                snippet: notesMatch ? a.locationNotes : null,
                type: GlobalSearchResultType.appointment,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen()));
                },
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 6. Estudos Bíblicos (se módulo ativo)
    if (isStudiesEnabled) {
      try {
        final studies = await repo.getAllStudies();
        for (final s in studies) {
          if (s.deletedAt != null) continue;
          final titleMatch = s.title.toLowerCase().contains(query);
          final manualMatch = s.manualReference?.toLowerCase().contains(query) ?? false;

          if (titleMatch || manualMatch) {
            results.add(
              GlobalSearchResultItem(
                id: s.id,
                title: s.title,
                subtitle: 'Publicação: ${s.publicationId} • Status: ${s.status}',
                snippet: s.learningGoals,
                type: GlobalSearchResultType.study,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudiesScreen()));
                },
              ),
            );
          }
        }
      } catch (_) {}
    }

    return results;
  }
}
