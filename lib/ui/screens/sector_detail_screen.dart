import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../territory/sector_manager.dart';
import '../providers.dart';
import 'person_detail_screen.dart';

class SectorDetailScreen extends ConsumerStatefulWidget {
  final TerritorySector sector;

  const SectorDetailScreen({super.key, required this.sector});

  @override
  ConsumerState<SectorDetailScreen> createState() => _SectorDetailScreenState();
}

class _SectorDetailScreenState extends ConsumerState<SectorDetailScreen> {
  String _selectedFilter = 'Todos'; // 'Todos', 'Interessados', 'Revisitas', 'Estudos'
  late String _currentSectorName;

  @override
  void initState() {
    super.initState();
    _currentSectorName = widget.sector.name;
  }

  Future<void> _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/55$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMultiContactRoute(List<PersonEntry> contacts) async {
    final validContacts = contacts.where((c) => (c.address != null && c.address!.trim().isNotEmpty) || (c.latitude != null && c.longitude != null)).toList();
    if (validContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum contato com endereço neste setor para traçar rota.')),
        );
      }
      return;
    }

    if (validContacts.length == 1) {
      final p = validContacts.first;
      final q = (p.latitude != null && p.longitude != null) ? '${p.latitude},${p.longitude}' : Uri.encodeComponent(p.address ?? p.name);
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final effective = validContacts.length > 10 ? validContacts.take(10).toList() : validContacts;
    final dest = effective.last;
    final destQuery = (dest.latitude != null && dest.longitude != null)
        ? '${dest.latitude},${dest.longitude}'
        : Uri.encodeComponent(dest.address ?? dest.name);
    final waypointsList = effective.sublist(0, effective.length - 1).map((c) {
      return (c.latitude != null && c.longitude != null)
          ? '${c.latitude},${c.longitude}'
          : Uri.encodeComponent(c.address ?? c.name);
    }).where((w) => w.isNotEmpty).toList();

    final waypointsParam = waypointsList.isNotEmpty ? '&waypoints=${waypointsList.join("|")}' : '';
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destQuery$waypointsParam');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEditSectorDialog() {
    final nameController = TextEditingController(text: _currentSectorName);
    final descController = TextEditingController(text: widget.sector.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Bairro / Setor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome do Bairro *'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Descrição / Limites'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty) return;
              final mgr = ref.read(sectorManagerProvider);
              final repo = ref.read(repositoryProvider);
              await mgr.updateSector(widget.sector.id, newName, description: descController.text.trim(), repo: repo);
              setState(() {
                _currentSectorName = newName;
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSector() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir Bairro / Setor'),
        content: Text('Tem certeza que deseja remover o setor "$_currentSectorName"? Os contatos cadastrados não serão apagados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final mgr = ref.read(sectorManagerProvider);
      await mgr.deleteSector(widget.sector.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filtra pessoas que pertencem a este setor
    final sectorLower = _currentSectorName.toLowerCase().trim();
    final sectorContacts = people.where((p) {
      if (p.deletedAt != null) return false;
      final addr = (p.address ?? '').toLowerCase();
      final tags = p.tags.toLowerCase();
      final notes = (p.generalNotes ?? '').toLowerCase();
      return addr.contains(sectorLower) || tags.contains(sectorLower) || notes.contains(sectorLower);
    }).toList();

    // Estatísticas da região (modalidades)
    final totalContacts = sectorContacts.length;
    final totalInteressados = sectorContacts.where((p) => p.status == 'interessado').length;
    final totalRevisitas = sectorContacts.where((p) => p.status == 'revisita').length;
    final totalEstudos = sectorContacts.where((p) => p.status == 'estudo').length;

    // Filtro ativo
    final displayedContacts = sectorContacts.where((p) {
      if (_selectedFilter == 'Interessados') return p.status == 'interessado';
      if (_selectedFilter == 'Revisitas') return p.status == 'revisita';
      if (_selectedFilter == 'Estudos') return p.status == 'estudo';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Bairro: $_currentSectorName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar Bairro',
            onPressed: _showEditSectorDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Excluir Bairro',
            onPressed: _confirmDeleteSector,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Painel Superior: Estatísticas da Região / Bairro
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.holiday_village, color: AppTheme.accentTeal, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Estatísticas de $_currentSectorName',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        if (sectorContacts.isNotEmpty)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: const Size(36, 36),
                            ),
                            icon: const Icon(Icons.directions, size: 16),
                            label: const Text('Rota no Setor', style: TextStyle(fontSize: 12)),
                            onPressed: () => _openMultiContactRoute(sectorContacts),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _StatBox(
                          label: 'TOTAL',
                          count: '$totalContacts',
                          color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue,
                          icon: Icons.people_alt,
                        ),
                        const SizedBox(width: 8),
                        _StatBox(
                          label: 'INTERESSADOS',
                          count: '$totalInteressados',
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                          icon: Icons.person_search,
                        ),
                        const SizedBox(width: 8),
                        _StatBox(
                          label: 'REVISITAS',
                          count: '$totalRevisitas',
                          color: AppTheme.accentTeal,
                          icon: Icons.repeat,
                        ),
                        const SizedBox(width: 8),
                        _StatBox(
                          label: 'ESTUDOS',
                          count: '$totalEstudos',
                          color: const Color(0xFF7C3AED),
                          icon: Icons.menu_book,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Filtros de modalidade
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in ['Todos', 'Interessados', 'Revisitas', 'Estudos'])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: _selectedFilter == filter,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilter = filter);
                        },
                        selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Lista de Contatos
            if (displayedContacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_search, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum contato encontrado em "$_currentSectorName"${_selectedFilter != "Todos" ? " com status $_selectedFilter" : ""}.\n\nAo cadastrar um contato com o bairro "$_currentSectorName" no endereço, ele aparecerá aqui automaticamente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedContacts.length,
                itemBuilder: (context, index) {
                  final person = displayedContacts[index];
                  final color = _getStatusColor(person.status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Text(
                                  person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppTheme.textDark,
                                      ),
                                    ),
                                    if (person.phone != null && person.phone!.isNotEmpty)
                                      Text(
                                        person.phone!,
                                        style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  person.status.toUpperCase(),
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (person.address != null && person.address!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.accentTeal),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    person.address!,
                                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFF1F5F9) : AppTheme.textDark),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (person.preferredSchedule != null && person.preferredSchedule!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 15, color: isDark ? const Color(0xFF60A5FA) : AppTheme.primaryBlue),
                                const SizedBox(width: 6),
                                Text(
                                  'Dia Habitual do Estudo: ${person.preferredSchedule!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (person.phone != null && person.phone!.isNotEmpty) ...[
                                IconButton(
                                  icon: const Icon(Icons.phone, size: 20, color: AppTheme.primaryBlue),
                                  tooltip: 'Ligar',
                                  onPressed: () => _makePhoneCall(person.phone),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, size: 20, color: Color(0xFF25D366)),
                                  tooltip: 'WhatsApp',
                                  onPressed: () => _openWhatsApp(person.phone),
                                ),
                              ],
                              OutlinedButton.icon(
                                icon: const Icon(Icons.person, size: 16),
                                label: const Text('Ver Perfil'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: person.id)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'estudo':
        return const Color(0xFF7C3AED);
      case 'revisita':
        return AppTheme.accentTeal;
      case 'interessado':
      default:
        return AppTheme.primaryBlue;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String count;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              count,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
