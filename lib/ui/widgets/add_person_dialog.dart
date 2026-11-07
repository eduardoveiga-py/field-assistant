import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/date_utils.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/sector_manager.dart';
import '../providers.dart';
import 'map_location_picker_dialog.dart';

/// Abre diretamente o formulário modal de cadastro de novo contato / nova pessoa.
Future<void> showAddPersonDialog(BuildContext context, WidgetRef ref) async {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final neighborhoodController = TextEditingController();
  final referenceController = TextEditingController();
  final scheduleController = TextEditingController(text: 'Sábado às 09:00');
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final notesController = TextEditingController();
  String selectedStatus = 'interessado';
  String selectedWeekday = 'Sábado';
  TimeOfDay selectedStudyTime = const TimeOfDay(hour: 9, minute: 0);
  DateTime firstContactDate = DateTime.now();
  DateTime? lastVisitDate;

  final sectors = ref.read(sectorsStreamProvider).value ?? [];

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text('Novo Contato'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome completo ou como é conhecido(a) *',
                  hintText: 'Ex: Dona Maria Silva',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone / WhatsApp',
                        hintText: '(11) 98765-4321',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Situação',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'interessado',
                          child: Text('Interessado'),
                        ),
                        DropdownMenuItem(
                          value: 'revisita',
                          child: Text('Revisita'),
                        ),
                        DropdownMenuItem(
                          value: 'estudo',
                          child: Text('Estudo Bíblico'),
                        ),
                        DropdownMenuItem(
                          value: 'outro',
                          child: Text('Outro'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedStatus = val);
                        }
                      },
                    ),
                  ),
                ],
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
                        Icon(
                          Icons.history_edu,
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
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
                              '1º Contato: ${AppDateUtils.formatDate(firstContactDate)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: firstContactDate,
                                firstDate: DateTime(2010),
                                lastDate: DateTime.now(),
                              );
                              if (p != null) {
                                setDialogState(() => firstContactDate = p);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.history, size: 14),
                            label: Text(
                              lastVisitDate != null
                                  ? 'Últ. Visita: ${AppDateUtils.formatDate(lastVisitDate!)}'
                                  : 'Última Visita (opcional)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: lastVisitDate ?? DateTime.now(),
                                firstDate: DateTime(2010),
                                lastDate: DateTime.now(),
                              );
                              if (p != null) {
                                setDialogState(() => lastVisitDate = p);
                              }
                            },
                          ),
                        ),
                        if (lastVisitDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            tooltip: 'Remover data',
                            onPressed: () =>
                                setDialogState(() => lastVisitDate = null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Localização Completa & Mapa',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: addressController,
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
                      controller: neighborhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Bairro / Setor',
                        hintText: 'Ex: Betânia, Lago Grande...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: referenceController,
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
                      final isChosen =
                          neighborhoodController.text.trim().toLowerCase() ==
                          sec.name.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: Icon(
                            Icons.location_city,
                            size: 14,
                            color: isChosen
                                ? Colors.white
                                : AppTheme.primaryBlue,
                          ),
                          label: Text(
                            sec.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: isChosen ? Colors.white : null,
                            ),
                          ),
                          backgroundColor: isChosen
                              ? AppTheme.primaryBlue
                              : null,
                          onPressed: () {
                            setDialogState(() {
                              neighborhoodController.text = sec.name;
                            });
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
                      controller: latController,
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
                      controller: lngController,
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
                runSpacing: 6,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text(
                      'Capturar GPS + Endereço',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final pos =
                          await GeolocationHelper.getCurrentLocation();
                      final lat = pos?.latitude ?? -23.550520;
                      final lng = pos?.longitude ?? -46.633308;
                      setDialogState(() {
                        latController.text = lat.toStringAsFixed(6);
                        lngController.text = lng.toStringAsFixed(6);
                      });

                      final geo = await GeocodingService.reverseGeocode(
                        lat,
                        lng,
                      );
                      if (geo != null) {
                        setDialogState(() {
                          if (geo.streetAndNumber.isNotEmpty) {
                            addressController.text = geo.streetAndNumber;
                          }
                          if (geo.neighborhood != null &&
                              geo.neighborhood!.isNotEmpty) {
                            neighborhoodController.text = geo.neighborhood!;
                          }
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Endereço preenchido automaticamente: ${geo.formattedSummary}!',
                              ),
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Coordenadas capturadas! Use "Marcar no Mapa" para refinar o local.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: const BorderSide(color: AppTheme.alertRed),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text(
                      '🗺️ Escolher no Mapa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      final initialLat = double.tryParse(
                        latController.text.trim(),
                      );
                      final initialLng = double.tryParse(
                        lngController.text.trim(),
                      );
                      final res = await showDialog<ReverseGeocodingResult>(
                        context: context,
                        builder: (_) => MapLocationPickerDialog(
                          initialLat: initialLat,
                          initialLng: initialLng,
                          initialAddress: addressController.text.trim(),
                          initialNeighborhood: neighborhoodController.text
                              .trim(),
                        ),
                      );
                      if (res != null) {
                        setDialogState(() {
                          latController.text = res.latitude.toStringAsFixed(
                            6,
                          );
                          lngController.text = res.longitude.toStringAsFixed(
                            6,
                          );
                          if (res.streetAndNumber.isNotEmpty) {
                            addressController.text = res.streetAndNumber;
                          }
                          if (res.neighborhood != null &&
                              res.neighborhood!.isNotEmpty) {
                            neighborhoodController.text = res.neighborhood!;
                          }
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Localização da casa marcada: ${res.formattedSummary}!',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  if (addressController.text.isNotEmpty ||
                      latController.text.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text(
                        'Ver no Google Maps',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: () async {
                        final q =
                            (latController.text.isNotEmpty &&
                                lngController.text.isNotEmpty)
                            ? '${latController.text},${lngController.text}'
                            : Uri.encodeComponent(addressController.text);
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$q',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Dia e Horário Habitual de Estudo / Visita',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedWeekday,
                      decoration: const InputDecoration(
                        labelText: 'Dia da Semana',
                      ),
                      items:
                          [
                            'Segunda',
                            'Terça',
                            'Quarta',
                            'Quinta',
                            'Sexta',
                            'Sábado',
                            'Domingo',
                          ].map((d) {
                            return DropdownMenuItem(value: d, child: Text(d));
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedWeekday = val;
                            final timeStr =
                                '${selectedStudyTime.hour.toString().padLeft(2, "0")}:${selectedStudyTime.minute.toString().padLeft(2, "0")}';
                            scheduleController.text =
                                '$selectedWeekday às $timeStr';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        '${selectedStudyTime.hour.toString().padLeft(2, "0")}:${selectedStudyTime.minute.toString().padLeft(2, "0")}',
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedStudyTime,
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedStudyTime = picked;
                            final timeStr =
                                '${picked.hour.toString().padLeft(2, "0")}:${picked.minute.toString().padLeft(2, "0")}';
                            scheduleController.text =
                                '$selectedWeekday às $timeStr';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: scheduleController,
                decoration: const InputDecoration(
                  labelText: 'Horário habitual formatado',
                  hintText: 'Ex: Sábado às 09:00',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText:
                      'Observações, necessidades e assuntos de interesse',
                  hintText:
                      'Ex: Família receptiva, dúvidas sobre a Bíblia...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor, informe ao menos o nome do contato.',
                    ),
                  ),
                );
                return;
              }

              // Compõe endereço unificado com bairro e ponto de referência se fornecidos
              final addrParts = <String>[];
              if (addressController.text.trim().isNotEmpty) {
                addrParts.add(addressController.text.trim());
              }
              if (neighborhoodController.text.trim().isNotEmpty) {
                addrParts.add(
                  'Bairro: ${neighborhoodController.text.trim()}',
                );
              }
              if (referenceController.text.trim().isNotEmpty) {
                addrParts.add('Ref: ${referenceController.text.trim()}');
              }

              final fullAddress = addrParts.isNotEmpty
                  ? addrParts.join(' - ')
                  : null;
              final lat = double.tryParse(latController.text.trim());
              final lng = double.tryParse(lngController.text.trim());

              final repo = ref.read(repositoryProvider);
              await repo.createPerson(
                name: name,
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                address: fullAddress,
                latitude: lat,
                longitude: lng,
                firstContactAt: firstContactDate,
                lastContactAt: lastVisitDate,
                status: selectedStatus,
                preferredSchedule: scheduleController.text.trim().isEmpty
                    ? null
                    : scheduleController.text.trim(),
                generalNotes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
              );

              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contato cadastrado com sucesso!'),
                  ),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}
