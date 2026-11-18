part of '../contacts_map_screen.dart';

extension _ContactsMapListView on _ContactsMapScreenState {
  Widget _buildGroupedNeighborhoodList(
    List<PersonEntry> contacts,
    List<BibleStudyEntry> studies,
  ) {
    final Map<String, List<PersonEntry>> byNeighborhood = {};
    for (final c in contacts) {
      final n = _extractNeighborhood(c.address);
      byNeighborhood.putIfAbsent(n, () => []).add(c);
    }

    final sortedNeighborhoods = byNeighborhood.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sortedNeighborhoods.length,
      itemBuilder: (context, idx) {
        final neighborhood = sortedNeighborhoods[idx];
        final neighborhoodContacts = byNeighborhood[neighborhood]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: Icon(
              Icons.holiday_village_outlined,
              color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
            ),
            title: Text(
              neighborhood,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${neighborhoodContacts.length} contato(s) nesta região',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.directions, color: AppTheme.accentTeal),
              tooltip: 'Traçar rota neste bairro',
              onPressed: () => _openMultiContactRoute(neighborhoodContacts),
            ),
            children: neighborhoodContacts.map((person) {
              final color = _getStatusColor(person.status);

              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.shade100,
                    ),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      person.status == 'estudo'
                          ? Icons.menu_book
                          : person.status == 'revisita'
                          ? Icons.repeat
                          : Icons.person_outline,
                      color: color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    person.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (person.address != null)
                        Text(
                          person.address!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      if (person.preferredSchedule != null &&
                          person.preferredSchedule!.isNotEmpty)
                        Text(
                          'Horário: ${person.preferredSchedule!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accentTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.navigation,
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : AppTheme.primaryBlue,
                          size: 20,
                        ),
                        tooltip: 'Abrir no Google Maps',
                        onPressed: () => _openSingleRoute(person),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PersonDetailScreen(personId: person.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'estudo':
        return const Color(0xFF7C3AED);
      case 'revisita':
        return AppTheme.accentTeal;
      case 'revisita_encerrada':
      case 'encerrado':
      case 'concluido':
        return const Color(0xFF94A3B8);
      case 'interessado':
      default:
        return const Color(0xFF2563EB);
    }
  }
}
