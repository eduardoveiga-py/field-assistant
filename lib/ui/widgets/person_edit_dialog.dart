import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../database/app_database.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/sector_manager.dart';
import '../providers.dart';
import 'map_location_picker_dialog.dart';

/// Diálogo modal completo para edição dos dados cadastrais do contato.
class PersonEditDialog extends ConsumerStatefulWidget {
  final PersonEntry person;
  final VoidCallback? onSaved;

  const PersonEditDialog({
    super.key,
    required this.person,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required PersonEntry person,
    VoidCallback? onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PersonEditDialog(
        person: person,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends ConsumerState<PersonEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _neighborhoodCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _scheduleCtrl;

  late String _currentStatus;
  late DateTime _editFirstContact;
  DateTime? _editLastContact;

  @override
  void initState() {
    super.initState();
    final person = widget.person;

    String initialStreet = '';
    String initialNeighborhood = '';
    String initialRef = '';
    final rawAddr = person.address ?? '';
    if (rawAddr.contains('Bairro:') || rawAddr.contains('Ref:')) {
      final parts = rawAddr.split(' - ');
      final streetParts = <String>[];
      for (final p in parts) {
        final t = p.trim();
        if (t.toLowerCase().startsWith('bairro:')) {
          initialNeighborhood = t.substring(7).trim();
        } else if (t.toLowerCase().startsWith('ref:')) {
          initialRef = t.substring(4).trim();
        } else {
          streetParts.add(t);
        }
      }
      initialStreet = streetParts.join(' - ');
    } else if (rawAddr.contains(' - ')) {
      final parts = rawAddr.split(' - ');
      if (parts.length >= 2 &&
          parts[1].trim().toLowerCase().startsWith('bairro ')) {
        initialStreet = parts[0].trim();
        initialNeighborhood = parts[1].trim().substring(7).trim();
        if (parts.length >= 3) {
          initialRef = parts.sublist(2).join(' - ').trim();
        }
      } else {
        initialStreet = rawAddr;
      }
    } else {
      initialStreet = rawAddr;
    }

    _nameCtrl = TextEditingController(text: person.name);
    _phoneCtrl = TextEditingController(text: person.phone ?? '');
    _addrCtrl = TextEditingController(text: initialStreet);
    _neighborhoodCtrl = TextEditingController(text: initialNeighborhood);
    _refCtrl = TextEditingController(text: initialRef);
    _latCtrl = TextEditingController(
      text: person.latitude != null && person.latitude != 0.0
          ? person.latitude!.toStringAsFixed(6)
          : '',
    );
    _lngCtrl = TextEditingController(
      text: person.longitude != null && person.longitude != 0.0
          ? person.longitude!.toStringAsFixed(6)
          : '',
    );
    _scheduleCtrl = TextEditingController(
      text: person.preferredSchedule ?? '',
    );
    _currentStatus = person.status;
    _editFirstContact = person.firstContactAt;
    _editLastContact = person.lastContactAt;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _refCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectors = ref.watch(sectorsStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit, color: AppTheme.primaryBlue, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Editar Dados do Contato',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nome Completo *'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Telefone / WhatsApp',
                          hintText: '(11) 98765-4321',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _currentStatus,
                        decoration: const InputDecoration(labelText: 'Situação / Classificação'),
                        items: const [
                          DropdownMenuItem(value: 'interessado', child: Text('👤 Interessado')),
                          DropdownMenuItem(value: 'revisita', child: Text('🔄 Revisita Ativa')),
                          DropdownMenuItem(value: 'estudo', child: Text('📖 Estudo Bíblico')),
                          DropdownMenuItem(value: 'revisita_passada', child: Text('📦 Revisita Repassada')),
                          DropdownMenuItem(value: 'revisita_encerrada', child: Text('⛔ Revisita Encerrada')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _currentStatus = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history_edu, size: 16, color: AppTheme.primaryBlue),
                                SizedBox(width: 6),
                                Text(
                                  'Histórico Prévio (Primeiro Uso / Contato Antigo)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.calendar_today, size: 14),
                                    label: Text(
                                      '1º Contato: ${AppDateUtils.formatDate(_editFirstContact)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: _editFirstContact,
                                        firstDate: DateTime(2010),
                                        lastDate: DateTime.now(),
                                      );
                                      if (p != null) {
                                        setState(() => _editFirstContact = p);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.history, size: 14),
                                    label: Text(
                                      _editLastContact != null
                                          ? 'Últ. Visita: ${AppDateUtils.formatDate(_editLastContact!)}'
                                          : 'Última Visita (opcional)',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onPressed: () async {
                                      final p = await showDatePicker(
                                        context: context,
                                        initialDate: _editLastContact ?? DateTime.now(),
                                        firstDate: DateTime(2010),
                                        lastDate: DateTime.now(),
                                      );
                                      if (p != null) {
                                        setState(() => _editLastContact = p);
                                      }
                                    },
                                  ),
                                ),
                                if (_editLastContact != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    tooltip: 'Remover data',
                                    onPressed: () => setState(() => _editLastContact = null),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Localização & Bairro / Setor',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addrCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Endereço (Rua, Número, Bloco/Apto)',
                          hintText: 'Ex: Rua das Flores, 120, Apto 42',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _neighborhoodCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Bairro / Setor',
                                hintText: 'Ex: Betânia, Lago Grande...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _refCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ponto de Referência',
                                hintText: 'Ex: Próximo à padaria',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (sectors.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: sectors.map((sec) {
                              final isChosen = _neighborhoodCtrl.text.trim().toLowerCase() ==
                                  sec.name.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  avatar: Icon(
                                    Icons.location_city,
                                    size: 14,
                                    color: isChosen ? Colors.white : AppTheme.primaryBlue,
                                  ),
                                  label: Text(
                                    sec.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isChosen ? Colors.white : null,
                                    ),
                                  ),
                                  backgroundColor: isChosen ? AppTheme.primaryBlue : null,
                                  onPressed: () {
                                    setState(() => _neighborhoodCtrl.text = sec.name);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _latCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Latitude GPS',
                                hintText: '-23.5505',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _lngCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Longitude GPS',
                                hintText: '-46.6333',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('🧭 GPS Atual', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              final pos = await GeolocationHelper.getCurrentLocation();
                              if (pos != null) {
                                setState(() {
                                  _latCtrl.text = pos.latitude.toStringAsFixed(6);
                                  _lngCtrl.text = pos.longitude.toStringAsFixed(6);
                                });
                                final geo = await GeocodingService.reverseGeocode(
                                  pos.latitude,
                                  pos.longitude,
                                );
                                if (geo != null && mounted) {
                                  setState(() {
                                    if (_addrCtrl.text.trim().isEmpty &&
                                        geo.streetAndNumber.isNotEmpty) {
                                      _addrCtrl.text = geo.streetAndNumber;
                                    }
                                    if (_neighborhoodCtrl.text.trim().isEmpty &&
                                        geo.neighborhood != null) {
                                      _neighborhoodCtrl.text = geo.neighborhood!;
                                    }
                                  });
                                }
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.map, size: 16),
                            label: const Text(
                              '🗺️ Escolher no Mapa',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final curLat = double.tryParse(_latCtrl.text.trim());
                              final curLng = double.tryParse(_lngCtrl.text.trim());
                              final res = await showDialog<ReverseGeocodingResult>(
                                context: context,
                                builder: (_) => MapLocationPickerDialog(
                                  initialLat: curLat,
                                  initialLng: curLng,
                                ),
                              );
                              if (res != null && mounted) {
                                setState(() {
                                  _latCtrl.text = res.latitude.toStringAsFixed(6);
                                  _lngCtrl.text = res.longitude.toStringAsFixed(6);
                                  if (res.streetAndNumber.isNotEmpty &&
                                      _addrCtrl.text.trim().isEmpty) {
                                    _addrCtrl.text = res.streetAndNumber;
                                  }
                                  if (res.neighborhood != null &&
                                      res.neighborhood!.isNotEmpty &&
                                      _neighborhoodCtrl.text.trim().isEmpty) {
                                    _neighborhoodCtrl.text = res.neighborhood!;
                                  }
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _scheduleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dia e Horário Habitual',
                          hintText: 'Ex: Sábado às 09:00',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Salvar Alterações'),
                    onPressed: () async {
                      final name = _nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('O nome do contato é obrigatório.')),
                        );
                        return;
                      }
                      final phone = _phoneCtrl.text.trim();
                      final addrParts = <String>[];
                      if (_addrCtrl.text.trim().isNotEmpty) {
                        addrParts.add(_addrCtrl.text.trim());
                      }
                      if (_neighborhoodCtrl.text.trim().isNotEmpty) {
                        addrParts.add('Bairro: ${_neighborhoodCtrl.text.trim()}');
                      }
                      if (_refCtrl.text.trim().isNotEmpty) {
                        addrParts.add('Ref: ${_refCtrl.text.trim()}');
                      }
                      final fullAddress = addrParts.isNotEmpty ? addrParts.join(' - ') : null;

                      final lat = double.tryParse(_latCtrl.text.trim());
                      final lng = double.tryParse(_lngCtrl.text.trim());
                      final sched = _scheduleCtrl.text.trim();

                      final repo = ref.read(repositoryProvider);
                      await repo.updatePerson(
                        widget.person.copyWith(
                          name: name,
                          phone: Value(phone.isNotEmpty ? phone : null),
                          address: Value(fullAddress),
                          latitude: Value(lat),
                          longitude: Value(lng),
                          firstContactAt: _editFirstContact,
                          lastContactAt: Value(_editLastContact),
                          preferredSchedule: Value(sched.isNotEmpty ? sched : null),
                          status: _currentStatus,
                          updatedAt: DateTime.now(),
                        ),
                      );

                      widget.onSaved?.call();
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dados do contato atualizados com sucesso!'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
