import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../family/family_ties_manager.dart';
import '../providers.dart';
import '../screens/person_detail_screen.dart';

class PersonFamilyTiesTab extends ConsumerStatefulWidget {
  final PersonEntry person;

  const PersonFamilyTiesTab({super.key, required this.person});

  @override
  ConsumerState<PersonFamilyTiesTab> createState() => _PersonFamilyTiesTabState();
}

class _PersonFamilyTiesTabState extends ConsumerState<PersonFamilyTiesTab> {
  final List<String> _relationshipOptions = const [
    'Esposa',
    'Marido',
    'Cônjuge',
    'Pai',
    'Mãe',
    'Filho',
    'Filha',
    'Filho(a)',
    'Irmão',
    'Irmã',
    'Irmão(ã)',
    'Padrasto',
    'Madrasta',
    'Enteado',
    'Enteada',
    'Enteado(a)',
    'Avô',
    'Avó',
    'Neto',
    'Neta',
    'Sogro(a)',
    'Genro/Nora',
    'Parente',
    'Outro Vínculo',
  ];

  void _showAddFamilyTieDialog(BuildContext context, List<PersonEntry> allPeople) {
    String selectedMode = 'registered'; // 'registered' ou 'manual'
    PersonEntry? selectedPerson;
    final manualNameController = TextEditingController();
    String selectedRelationship = 'Esposa';

    // Pessoas disponíveis para vínculo (excluindo a própria pessoa)
    final otherPeople = allPeople.where((p) => p.id != widget.person.id && p.deletedAt == null).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.family_restroom, color: AppTheme.primaryBlue),
                SizedBox(width: 8),
                Expanded(child: Text('Vínculo Familiar', style: TextStyle(fontSize: 18))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vincule cônjuges, pais, filhos e parentes. Ao vincular uma pessoa cadastrada, o parentesco recíproco é atualizado automaticamente!',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : AppTheme.textMuted),
                  ),
                  const SizedBox(height: 14),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'registered', label: Text('Pessoa Cadastrada', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'manual', label: Text('Digitar Nome', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {selectedMode},
                    onSelectionChanged: (val) {
                      setDialogState(() => selectedMode = val.first);
                    },
                  ),
                  const SizedBox(height: 14),

                  if (selectedMode == 'registered') ...[
                    if (otherPeople.isEmpty)
                      const Text('Não há outras pessoas cadastradas para vincular.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
                    else
                      DropdownButtonFormField<PersonEntry>(
                        initialValue: selectedPerson,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Selecione a pessoa cadastrada *'),
                        items: otherPeople.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (${p.status.toUpperCase()})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedPerson = val);
                        },
                      ),
                  ] else ...[
                    TextField(
                      controller: manualNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do familiar / parente *',
                        hintText: 'Ex: Pedro Silva (Filho)',
                      ),
                      autofocus: true,
                    ),
                  ],
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: selectedRelationship,
                    decoration: const InputDecoration(labelText: 'Grau de Parentesco / Relação *'),
                    items: _relationshipOptions.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRelationship = val);
                    },
                  ),
                  const SizedBox(height: 8),

                  if (selectedMode == 'registered' && selectedPerson != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sync_alt, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No cadastro de "${selectedPerson!.name}", aparecerá automaticamente: "${FamilyTiesManager.getReciprocalRelationship(selectedRelationship)}: ${widget.person.name}".',
                              style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () async {
                  String name;
                  String? relatedId;

                  if (selectedMode == 'registered') {
                    if (selectedPerson == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecione uma pessoa cadastrada.')),
                      );
                      return;
                    }
                    name = selectedPerson!.name;
                    relatedId = selectedPerson!.id;
                  } else {
                    name = manualNameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Informe o nome do familiar.')),
                      );
                      return;
                    }
                  }

                  final mgr = ref.read(familyTiesManagerProvider);
                  await mgr.addFamilyTie(
                    personId: widget.person.id,
                    personName: widget.person.name,
                    relatedPersonId: relatedId,
                    relatedPersonName: name,
                    relationshipType: selectedRelationship,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(relatedId != null
                            ? 'Vínculo adicionado e sincronizado reciprocamente com ${selectedPerson!.name}!'
                            : 'Vínculo familiar salvo com sucesso!'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  }
                },
                child: const Text('Salvar Vínculo'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTieDialog(BuildContext context, FamilyTieItem tie) {
    String selectedRelationship = _relationshipOptions.contains(tie.relationshipType) ? tie.relationshipType : 'Parente';
    final nameController = TextEditingController(text: tie.relatedPersonName);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Ajustar Vínculo: ${tie.relatedPersonName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tie.relatedPersonId == null) ...[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
              ],
              DropdownButtonFormField<String>(
                initialValue: selectedRelationship,
                decoration: const InputDecoration(labelText: 'Parentesco / Relação'),
                items: _relationshipOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRelationship = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final mgr = ref.read(familyTiesManagerProvider);
                await mgr.updateFamilyTie(
                  id: tie.id,
                  newRelationshipType: selectedRelationship,
                  newRelatedPersonName: tie.relatedPersonId == null ? nameController.text.trim() : null,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiesAsync = ref.watch(familyTiesStreamProvider);
    final allPeopleAsync = ref.watch(peopleStreamProvider);
    final allPeople = allPeopleAsync.value ?? [];

    final ties = (tiesAsync.value ?? []).where((t) => t.personId == widget.person.id).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.family_restroom, color: AppTheme.primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Text('Laços & Vínculos Familiares', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_link, size: 16),
                label: const Text('+ Vincular Familiar', style: TextStyle(fontSize: 12)),
                onPressed: () => _showAddFamilyTieDialog(context, allPeople),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Família e parentes que estudam ou moram juntos. Toque em uma tag para navegar para o perfil:',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),

          if (ties.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.diversity_3, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 10),
                      Text(
                        'Nenhum vínculo familiar cadastrado para ${widget.person.name}.\nToque em "+ Vincular Familiar" para associar cônjuge, pais ou filhos.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // EXIBIÇÃO EM FORMATO DE TAGS / CHIPS EM DESTAQUE
            const Text('Vínculos Cadastrados (Formato de Tags):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ties.map((tie) {
                final isRegistered = tie.relatedPersonId != null && tie.relatedPersonId!.isNotEmpty;

                return InkWell(
                  onTap: isRegistered
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PersonDetailScreen(personId: tie.relatedPersonId!)),
                          );
                        }
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isRegistered
                          ? AppTheme.primaryBlue.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isRegistered ? AppTheme.primaryBlue.withValues(alpha: 0.4) : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isRegistered ? Icons.person : Icons.person_outline,
                          size: 16,
                          color: isRegistered ? AppTheme.primaryBlue : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${tie.relationshipType}: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isRegistered ? AppTheme.primaryBlue : (isDark ? Colors.white : AppTheme.textDark),
                          ),
                        ),
                        Text(
                          tie.relatedPersonName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: isRegistered ? TextDecoration.underline : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          onSelected: (val) async {
                            if (val == 'edit') {
                              _showEditTieDialog(context, tie);
                            } else if (val == 'delete') {
                              final mgr = ref.read(familyTiesManagerProvider);
                              await mgr.deleteFamilyTie(tie.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vínculo familiar removido.')),
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Ajustar Parentesco')),
                            PopupMenuItem(value: 'delete', child: Text('Excluir Vínculo')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
