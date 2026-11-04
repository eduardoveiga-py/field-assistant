import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' as drift show Value;

import '../../core/app_theme.dart';
import '../../database/app_database.dart';
import '../../reports/report_export_service.dart';
import '../../territory/geocoding_service.dart';
import '../../territory/geolocation_helper.dart';
import '../../territory/landmark_manager.dart';
import '../../territory/sector_manager.dart';
import '../../territory/tile_cache/tile_cache_service.dart';
import '../providers.dart';
import '../widgets/interactive_map_canvas.dart';
import '../widgets/map_location_picker_dialog.dart';
import '../../contacts/person_hand_off_helper.dart';
import 'person_detail_screen.dart';

class ContactsMapScreen extends ConsumerStatefulWidget {
  final String? highlightPersonId;

  const ContactsMapScreen({super.key, this.highlightPersonId});

  @override
  ConsumerState<ContactsMapScreen> createState() => _ContactsMapScreenState();
}

class _ContactsMapScreenState extends ConsumerState<ContactsMapScreen> {
  String? _highlightPersonId;
  String _selectedStatusFilter =
      'Todos'; // 'Todos', 'Estudos', 'Revisitas', 'Interessados'
  String _selectedDayFilter = 'Todos'; // 'Todos', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
  String _selectedNeighborhood = 'Todos';
  String _viewMode = 'Mapa Interativo'; // 'Mapa Interativo', 'Lista / Bairros'
  bool _showLandmarks = true;
  PersonEntry? _selectedPinPerson;
  TerritoryLandmark? _selectedPinLandmark;
  int _zoom = 15;

  final Set<String> _geocodedPersonIds = {};

  @override
  void initState() {
    super.initState();
    _highlightPersonId = widget.highlightPersonId;
  }

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // pi / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  Future<void> _openSingleRoute(PersonEntry person) async {
    final query =
        (person.latitude != null &&
            person.longitude != null &&
            (person.latitude != 0.0 || person.longitude != 0.0))
        ? '${person.latitude},${person.longitude}'
        : Uri.encodeComponent(person.address ?? person.name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openLandmarkRoute(TerritoryLandmark landmark) async {
    final query =
        (landmark.latitude != null &&
            landmark.longitude != null &&
            landmark.latitude != 0.0)
        ? '${landmark.latitude},${landmark.longitude}'
        : Uri.encodeComponent(landmark.address ?? landmark.name);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMultiContactRoute(List<PersonEntry> contacts) async {
    final validContacts = contacts
        .where(
          (c) =>
              (c.address != null && c.address!.trim().isNotEmpty) ||
              (c.latitude != null &&
                  c.longitude != null &&
                  (c.latitude != 0.0 || c.longitude != 0.0)),
        )
        .toList();
    if (validContacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nenhum contato com endereço cadastrado para traçar rota.',
            ),
          ),
        );
      }
      return;
    }

    if (validContacts.length == 1) {
      await _openSingleRoute(validContacts.first);
      return;
    }

    // Filtra pontos distantes (> 60km) calculados em relação à mediana do agrupamento do território
    final validLats = <double>[];
    final validLngs = <double>[];
    for (final c in validContacts) {
      if (c.latitude != null &&
          c.longitude != null &&
          (c.latitude != 0.0 || c.longitude != 0.0) &&
          c.latitude!.abs() <= 90 &&
          c.longitude!.abs() <= 180) {
        validLats.add(c.latitude!);
        validLngs.add(c.longitude!);
      }
    }

    final nearbyContacts = <PersonEntry>[];
    if (validLats.isNotEmpty) {
      validLats.sort();
      validLngs.sort();
      final medianLat = validLats[validLats.length ~/ 2];
      final medianLng = validLngs[validLngs.length ~/ 2];

      for (final c in validContacts) {
        if (c.latitude != null &&
            c.longitude != null &&
            (c.latitude != 0.0 || c.longitude != 0.0)) {
          final dist = _calculateDistanceKm(
            medianLat,
            medianLng,
            c.latitude!,
            c.longitude!,
          );
          if (dist <= 60.0) {
            nearbyContacts.add(c);
          }
        } else {
          nearbyContacts.add(c);
        }
      }
    } else {
      nearbyContacts.addAll(validContacts);
    }

    if (nearbyContacts.isEmpty) nearbyContacts.addAll(validContacts);

    if (nearbyContacts.length == 1) {
      await _openSingleRoute(nearbyContacts.first);
      return;
    }

    if (nearbyContacts.length < validContacts.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rota traçada apenas para os ${nearbyContacts.length} contatos próximos do território.',
          ),
        ),
      );
    }

    final effectiveContacts = nearbyContacts.length > 10
        ? nearbyContacts.take(10).toList()
        : nearbyContacts;
    if (nearbyContacts.length > 10 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rota otimizada para os primeiros 10 contatos de ${nearbyContacts.length} (limite do Google Maps).',
          ),
        ),
      );
    }

    final dest = effectiveContacts.last;
    final destQuery =
        (dest.latitude != null &&
            dest.longitude != null &&
            (dest.latitude != 0.0 || dest.longitude != 0.0))
        ? '${dest.latitude},${dest.longitude}'
        : Uri.encodeComponent(dest.address ?? dest.name);

    final waypointsList = effectiveContacts
        .sublist(0, effectiveContacts.length - 1)
        .map((c) {
          return (c.latitude != null &&
                  c.longitude != null &&
                  (c.latitude != 0.0 || c.longitude != 0.0))
              ? '${c.latitude},${c.longitude}'
              : Uri.encodeComponent(c.address ?? c.name);
        })
        .where((w) => w.isNotEmpty)
        .toList();

    final waypointsParam = waypointsList.isNotEmpty
        ? '&waypoints=${waypointsList.join("|")}'
        : '';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destQuery$waypointsParam',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Abre o Google Maps padrão com a visualização do mapa/localizações (NÃO rota de carro)
  Future<void> _openStandardGoogleMaps(
    List<PersonEntry> contacts, [
    List<TerritoryLandmark>? landmarks,
  ]) async {
    final validLats = <double>[];
    final validLngs = <double>[];

    for (final c in contacts) {
      if (c.latitude != null &&
          c.longitude != null &&
          (c.latitude != 0.0 || c.longitude != 0.0) &&
          c.latitude!.abs() <= 90 &&
          c.longitude!.abs() <= 180) {
        validLats.add(c.latitude!);
        validLngs.add(c.longitude!);
      }
    }
    if (landmarks != null) {
      for (final l in landmarks) {
        if (l.latitude != null &&
            l.longitude != null &&
            (l.latitude != 0.0 || l.longitude != 0.0) &&
            l.latitude!.abs() <= 90 &&
            l.longitude!.abs() <= 180) {
          validLats.add(l.latitude!);
          validLngs.add(l.longitude!);
        }
      }
    }

    if (validLats.isNotEmpty) {
      validLats.sort();
      validLngs.sort();
      final medianLat = validLats[validLats.length ~/ 2];
      final medianLng = validLngs[validLngs.length ~/ 2];

      // Abre o Google Maps visualizando o ponto central do território
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$medianLat,$medianLng',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    for (final c in contacts) {
      if (c.address != null && c.address!.trim().isNotEmpty) {
        final query = Uri.encodeComponent(c.address!);
        final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$query',
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
    }

    final defaultUri = Uri.parse('https://www.google.com/maps');
    if (await canLaunchUrl(defaultUri)) {
      await launchUrl(defaultUri, mode: LaunchMode.externalApplication);
    }
  }

  String _extractNeighborhood(String? address) {
    if (address == null || address.trim().isEmpty) return 'Sem Bairro Definido';
    final parts = address.split(RegExp(r'[-–,]'));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.toLowerCase().startsWith('bairro') ||
          trimmed.toLowerCase().startsWith('jd') ||
          trimmed.toLowerCase().startsWith('jardim') ||
          trimmed.toLowerCase().startsWith('centro')) {
        return trimmed;
      }
    }
    if (parts.length >= 2) {
      final candidate = parts[1].trim();
      if (candidate.isNotEmpty && !RegExp(r'^\d+$').hasMatch(candidate)) {
        return candidate;
      }
    }
    return 'Geral';
  }

  // Modal para criar novo Ponto de Referência / Marco no território
  void _showAddLandmarkModal(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String selectedCategory = 'padaria';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final dialogIsDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_location_alt, color: AppTheme.accentTeal),
                SizedBox(width: 8),
                Text('Novo Ponto de Referência'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crie marcos úteis para localizar endereços com facilidade ou orientar outros publicadores.',
                    style: TextStyle(
                      fontSize: 12,
                      color: dialogIsDark
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Ponto de Referência *',
                      hintText:
                          'Ex: Padaria Central Betânia, Escola Estadual...',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoria / Tipo de Marco',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'padaria',
                        child: Text('🥖 Padaria / Comércio'),
                      ),
                      DropdownMenuItem(
                        value: 'escola',
                        child: Text('🏫 Escola / Colégio'),
                      ),
                      DropdownMenuItem(
                        value: 'saude',
                        child: Text('🏥 Posto de Saúde / Hospital'),
                      ),
                      DropdownMenuItem(
                        value: 'transporte',
                        child: Text('🚌 Ponto de Ônibus / Terminal'),
                      ),
                      DropdownMenuItem(
                        value: 'mercado',
                        child: Text('🛒 Supermercado'),
                      ),
                      DropdownMenuItem(
                        value: 'praca',
                        child: Text('🌳 Praça / Parque'),
                      ),
                      DropdownMenuItem(
                        value: 'religioso',
                        child: Text('⛪ Salão do Reino / Igreja'),
                      ),
                      DropdownMenuItem(
                        value: 'combustivel',
                        child: Text('⛽ Posto de Combustível'),
                      ),
                      DropdownMenuItem(
                        value: 'outro',
                        child: Text('📍 Outro Marco'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Endereço ou Localização',
                      hintText: 'Ex: Av. Principal com Rua 3 - Betânia',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude GPS (opcional)',
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
                            labelText: 'Longitude GPS (opcional)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text(
                          'Capturar GPS Atual',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final pos =
                              await GeolocationHelper.getCurrentLocation();
                          if (pos != null) {
                            setDialogState(() {
                              latController.text = pos.latitude.toStringAsFixed(
                                6,
                              );
                              lngController.text = pos.longitude
                                  .toStringAsFixed(6);
                            });
                            final geo = await GeocodingService.reverseGeocode(
                              pos.latitude,
                              pos.longitude,
                            );
                            if (geo != null &&
                                addressController.text.trim().isEmpty) {
                              setDialogState(() {
                                addressController.text = geo.formattedSummary;
                              });
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Não foi possível obter sinal GPS. Toque em "🗺️ Escolher no Mapa" para posicionar.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentTeal,
                          side: const BorderSide(color: AppTheme.accentTeal),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
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
                            ),
                          );
                          if (res != null) {
                            setDialogState(() {
                              latController.text = res.latitude.toStringAsFixed(
                                6,
                              );
                              lngController.text = res.longitude
                                  .toStringAsFixed(6);
                              if (addressController.text.trim().isEmpty &&
                                  res.streetAndNumber.isNotEmpty) {
                                addressController.text = res.formattedSummary;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Observações / Instruções para encontrar',
                      hintText: 'Ex: Ponto de encontro da saída de campo no sábado às 9:00',
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
                  if (name.isEmpty) return;

                  final mgr = ref.read(landmarkManagerProvider);
                  final lat = double.tryParse(latController.text.trim());
                  final lng = double.tryParse(lngController.text.trim());

                  await mgr.addLandmark(
                    name: name,
                    category: selectedCategory,
                    address: addressController.text.trim().isEmpty
                        ? null
                        : addressController.text.trim(),
                    latitude: lat,
                    longitude: lng,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ponto de referência cadastrado no mapa!',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Salvar Marco'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _shareLandmark(TerritoryLandmark landmark) async {
    final text =
        '📍 Ponto de Referência no Território: ${landmark.name}\n'
        'Categoria: ${landmark.categoryLabel}\n'
        '${landmark.address != null ? "Endereço: ${landmark.address}\n" : ""}'
        '${landmark.notes != null ? "Observações: ${landmark.notes}\n" : ""}'
        '${landmark.latitude != null && landmark.longitude != null ? "Coordenadas: ${landmark.latitude},${landmark.longitude}" : ""}';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Informações do ponto de referência copiadas para compartilhar!',
        ),
      ),
    );
  }

  Future<void> _downloadOfflineTiles(
    BuildContext context,
    List<PersonEntry> people,
    List<TerritoryLandmark> landmarks,
  ) async {
    final validLats = <double>[];
    final validLngs = <double>[];

    for (final c in people) {
      if (c.latitude != null &&
          c.longitude != null &&
          (c.latitude != 0.0 || c.longitude != 0.0) &&
          c.latitude!.abs() <= 90 &&
          c.longitude!.abs() <= 180) {
        validLats.add(c.latitude!);
        validLngs.add(c.longitude!);
      }
    }
    for (final l in landmarks) {
      if (l.latitude != null &&
          l.longitude != null &&
          (l.latitude != 0.0 || l.longitude != 0.0) &&
          l.latitude!.abs() <= 90 &&
          l.longitude!.abs() <= 180) {
        validLats.add(l.latitude!);
        validLngs.add(l.longitude!);
      }
    }

    double cLat = -23.550520;
    double cLng = -46.633308;
    if (validLats.isNotEmpty) {
      validLats.sort();
      validLngs.sort();
      cLat = validLats[validLats.length ~/ 2];
      cLng = validLngs[validLngs.length ~/ 2];
    }

    final zoomLevels = [_zoom - 1, _zoom];
    const half = 3;
    final totalExpected = zoomLevels.length * (half * 2 + 1) * (half * 2 + 1);
    final progressNotifier = ValueNotifier<int>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.download_for_offline, color: AppTheme.accentTeal),
                SizedBox(width: 8),
                Text('Baixando Mapa Offline', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: ValueListenableBuilder<int>(
              valueListenable: progressNotifier,
              builder: (ctx, progress, _) {
                final pct = totalExpected > 0
                    ? (progress / totalExpected).clamp(0.0, 1.0)
                    : 0.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Salvando blocos do território no dispositivo para uso sem internet no campo...',
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: AppTheme.accentTeal,
                      backgroundColor: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$progress de $totalExpected blocos',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentTeal,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    int totalSaved = 0;
    int cumulativeDone = 0;
    for (final z in zoomLevels) {
      final cx = InteractiveMapCanvas.lon2tileX(cLng, z);
      final cy = InteractiveMapCanvas.lat2tileY(cLat, z);
      final saved = await TileCacheService.instance.preloadArea(
        z: z,
        minX: cx - half,
        maxX: cx + half,
        minY: cy - half,
        maxY: cy + half,
        onProgress: (completed, _) {
          progressNotifier.value = cumulativeDone + completed;
        },
      );
      totalSaved += saved;
      cumulativeDone += (half * 2 + 1) * (half * 2 + 1);
    }

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sucesso! $totalSaved blocos salvos para uso offline no ministério.',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleStreamProvider);
    final landmarks = ref.watch(landmarksStreamProvider).value ?? [];
    final studies = ref.watch(studiesStreamProvider).value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa dos Contatos e Território'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Ver Mapa Interativo',
            onPressed: () {
              setState(() {
                _viewMode = 'Mapa Interativo';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: 'Ver em Lista / Bairros',
            onPressed: () {
              setState(() {
                _viewMode = 'Lista / Bairros';
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais Opções do Mapa',
            onSelected: (val) {
              if (val == 'pdf') {
                final people = peopleAsync.value ?? [];
                final sectors = ref.watch(sectorsStreamProvider).value ?? [];
                ReportExportService.exportContactsMapPdf(
                  context: context,
                  people: people,
                  landmarks: landmarks,
                  sectors: sectors,
                );
              } else if (val == 'offline') {
                final people = peopleAsync.value ?? [];
                _downloadOfflineTiles(context, people, landmarks);
              } else if (val == 'google_maps') {
                final people = peopleAsync.value ?? [];
                _openStandardGoogleMaps(people, landmarks);
              } else if (val == 'landmark') {
                _showAddLandmarkModal(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar Mapa Geral (PDF)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'offline',
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Baixar Mapa Offline'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'google_maps',
                child: Row(
                  children: [
                    Icon(Icons.public, size: 18),
                    SizedBox(width: 8),
                    Text('Abrir no Google Maps'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'landmark',
                child: Row(
                  children: [
                    Icon(Icons.add_location_alt_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('+ Ponto de Referência'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location),
        label: const Text('+ Ponto de Referência'),
        onPressed: () => _showAddLandmarkModal(context),
      ),
      body: peopleAsync.when(
        data: (people) {
          final neighborhoods = <String>{'Todos'};
          for (final p in people) {
            if (p.address != null && p.address!.isNotEmpty) {
              neighborhoods.add(_extractNeighborhood(p.address));
            }
          }

          final filtered = people.where((p) {
            // Se for o contato em destaque vindo do perfil individual, nunca exclui por filtros
            if (_highlightPersonId != null && p.id == _highlightPersonId) {
              return true;
            }

            final hasLoc =
                (p.address != null && p.address!.trim().isNotEmpty) ||
                (p.latitude != null && p.longitude != null);
            if (!hasLoc) return false;

            if (_selectedStatusFilter == 'Todos') {
              if (p.status == 'revisita_encerrada' || p.status == 'encerrado') {
                return false;
              }
            } else if (_selectedStatusFilter == 'Estudos' &&
                p.status != 'estudo') {
              return false;
            } else if (_selectedStatusFilter == 'Revisitas' &&
                p.status != 'revisita') {
              return false;
            } else if (_selectedStatusFilter == 'Interessados' &&
                p.status != 'interessado') {
              return false;
            } else if (_selectedStatusFilter == 'Estrangeiros') {
              final tags = p.tags.toLowerCase();
              final notes = (p.generalNotes ?? '').toLowerCase();
              final isForeign =
                  tags.contains('estrangeiro') ||
                  notes.contains('idioma') ||
                  notes.contains('língua') ||
                  notes.contains('estrangeir') ||
                  notes.contains('inglês') ||
                  notes.contains('espanhol') ||
                  notes.contains('francês') ||
                  notes.contains('chinês') ||
                  notes.contains('coreano') ||
                  notes.contains('crioulo') ||
                  notes.contains('árabe');
              if (!isForeign) return false;
            } else if (_selectedStatusFilter == 'Encerrados' &&
                !(p.status == 'revisita_encerrada' ||
                    p.status == 'encerrado' ||
                    p.status == 'concluido')) {
              return false;
            }

            if (_selectedNeighborhood != 'Todos') {
              final b = _extractNeighborhood(p.address);
              if (b != _selectedNeighborhood) return false;
            }

            if (_selectedDayFilter != 'Todos') {
              final sched = (p.preferredSchedule ?? '').toLowerCase();
              final dayNorm = _selectedDayFilter.toLowerCase();
              if (!sched.contains(dayNorm.substring(0, 3))) return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              // Barra de filtros superior
              Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final status in [
                            'Todos',
                            'Estudos',
                            'Revisitas',
                            'Interessados',
                            'Estrangeiros',
                            'Encerrados',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(status),
                                selected: _selectedStatusFilter == status,
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(
                                      () => _selectedStatusFilter = status,
                                    );
                                  }
                                },
                                selectedColor: AppTheme.primaryBlue.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                          const VerticalDivider(width: 12),
                          DropdownButton<String>(
                            value: _selectedDayFilter,
                            underline: const SizedBox.shrink(),
                            hint: const Text('Dia da Visita'),
                            items:
                                [
                                  'Todos',
                                  'Segunda',
                                  'Terça',
                                  'Quarta',
                                  'Quinta',
                                  'Sexta',
                                  'Sábado',
                                  'Domingo',
                                ].map((d) {
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d == 'Todos' ? 'Qualquer Dia' : d,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDayFilter = val);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          if (neighborhoods.length > 2)
                            DropdownButton<String>(
                              value:
                                  neighborhoods.contains(_selectedNeighborhood)
                                  ? _selectedNeighborhood
                                  : 'Todos',
                              underline: const SizedBox.shrink(),
                              items: neighborhoods.map((b) {
                                return DropdownMenuItem(
                                  value: b,
                                  child: Text(
                                    b == 'Todos' ? 'Todos os Bairros' : b,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedNeighborhood = val);
                                }
                              },
                            ),
                          const SizedBox(width: 8),
                          FilterChip(
                            avatar: Icon(
                              Icons.place,
                              size: 16,
                              color: _showLandmarks
                                  ? Colors.white
                                  : AppTheme.accentTeal,
                            ),
                            label: Text('Pontos Ref. (${landmarks.length})'),
                            selected: _showLandmarks,
                            onSelected: (val) =>
                                setState(() => _showLandmarks = val),
                            selectedColor: AppTheme.accentTeal,
                            labelStyle: TextStyle(
                              color: _showLandmarks ? Colors.white : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filtered.length} contatos • ${landmarks.length} marcos de referência',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(36, 36),
                              ),
                              icon: const Icon(Icons.public, size: 16),
                              label: const Text(
                                'Mapa Padrão',
                                style: TextStyle(fontSize: 12),
                              ),
                              onPressed: () =>
                                  _openStandardGoogleMaps(filtered, landmarks),
                            ),
                            const SizedBox(width: 6),
                            if (filtered.isNotEmpty)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(36, 36),
                                ),
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text(
                                  'Traçar Rota',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    _openMultiContactRoute(filtered),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Corpo da Tela: Mapa Interativo Visual OU Lista por Bairros
              Expanded(
                child: _viewMode == 'Mapa Interativo'
                    ? _buildInteractiveVisualMap(filtered, landmarks)
                    : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off_outlined,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum contato com endereço cadastrado coincide com os filtros selecionados.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : AppTheme.textMuted,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.filter_alt_off),
                                label: const Text('Limpar Filtros'),
                                onPressed: () {
                                  setState(() {
                                    _selectedStatusFilter = 'Todos';
                                    _selectedDayFilter = 'Todos';
                                    _selectedNeighborhood = 'Todos';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildGroupedNeighborhoodList(filtered, studies),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Erro ao carregar contatos: $err')),
      ),
    );
  }

  // Visualizador geográfico com mapa real OpenStreetMap (tiles raster com cache offline) e zoom interativo
  Widget _buildInteractiveVisualMap(
    List<PersonEntry> contacts,
    List<TerritoryLandmark> landmarks,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    PersonEntry? highlightPerson;
    if (_highlightPersonId != null) {
      for (final c in contacts) {
        if (c.id == _highlightPersonId) {
          highlightPerson = c;
          break;
        }
      }
    }

    final hasHighlightCoords =
        highlightPerson != null &&
        highlightPerson.latitude != null &&
        highlightPerson.longitude != null &&
        (highlightPerson.latitude != 0.0 || highlightPerson.longitude != 0.0) &&
        highlightPerson.latitude!.abs() <= 90 &&
        highlightPerson.longitude!.abs() <= 180;

    // Se o contato em destaque não possuir coordenadas GPS mas tiver endereço, geocodifica automaticamente
    if (highlightPerson != null &&
        !hasHighlightCoords &&
        highlightPerson.address != null &&
        highlightPerson.address!.trim().isNotEmpty &&
        !_geocodedPersonIds.contains(highlightPerson.id)) {
      _geocodedPersonIds.add(highlightPerson.id);
      final personToGeocode = highlightPerson;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final res = await GeocodingService.geocodeAddress(
          personToGeocode.address!,
        );
        if (res != null && mounted) {
          await ref
              .read(repositoryProvider)
              .updatePerson(
                personToGeocode.copyWith(
                  latitude: drift.Value(res.latitude),
                  longitude: drift.Value(res.longitude),
                ),
              );
        }
      });
    }

    return Stack(
      children: [
        InteractiveMapCanvas(
          contacts: contacts,
          landmarks: landmarks,
          highlightPersonId: _highlightPersonId,
          selectedPerson: _selectedPinPerson,
          selectedLandmark: _selectedPinLandmark,
          showLandmarks: _showLandmarks,
          onPersonSelected: (person) {
            setState(() {
              _selectedPinPerson = person;
              _selectedPinLandmark = null;
            });
          },
          onLandmarkSelected: (landmark) {
            setState(() {
              _selectedPinLandmark = landmark;
              _selectedPinPerson = null;
            });
          },
          onClearHighlight: () {
            setState(() {
              _highlightPersonId = null;
            });
          },
          onZoomChanged: (z) => setState(() => _zoom = z),
        ),

        // Painel inferior flutuante ao tocar em um Ponto de Referência
            if (_selectedPinLandmark != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _selectedPinLandmark!.color
                                      .withValues(alpha: 0.15),
                                  child: Icon(
                                    _selectedPinLandmark!.icon,
                                    color: _selectedPinLandmark!.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedPinLandmark!.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () =>
                                  setState(() => _selectedPinLandmark = null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedPinLandmark!.color.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _selectedPinLandmark!.categoryLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedPinLandmark!.color,
                            ),
                          ),
                        ),
                        if (_selectedPinLandmark!.address != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedPinLandmark!.address!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_selectedPinLandmark!.notes != null &&
                            _selectedPinLandmark!.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _selectedPinLandmark!.notes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedPinLandmark!.color,
                                ),
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text('Rota até esta Referência'),
                                onPressed: () =>
                                    _openLandmarkRoute(_selectedPinLandmark!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Compartilhar'),
                              onPressed: () =>
                                  _shareLandmark(_selectedPinLandmark!),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.alertRed,
                              ),
                              tooltip: 'Excluir marco',
                              onPressed: () async {
                                final mgr = ref.read(landmarkManagerProvider);
                                await mgr.deleteLandmark(
                                  _selectedPinLandmark!.id,
                                );
                                setState(() => _selectedPinLandmark = null);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Painel inferior flutuante ao tocar em um pino de contato
            if (_selectedPinPerson != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPinPerson!.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  _selectedPinPerson!.status,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedPinPerson!.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(
                                    _selectedPinPerson!.status,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () =>
                                  setState(() => _selectedPinPerson = null),
                            ),
                          ],
                        ),
                        if (_selectedPinPerson!.address != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _selectedPinPerson!.address!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_selectedPinPerson!.preferredSchedule != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : AppTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedPinPerson!.preferredSchedule!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.accentTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text('Abrir Rota no Mapa'),
                                onPressed: () =>
                                    _openSingleRoute(_selectedPinPerson!),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person, size: 16),
                              label: const Text('Ver Perfil'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(
                                      personId: _selectedPinPerson!.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF059669),
                              side: const BorderSide(color: Color(0xFF059669)),
                            ),
                            icon: const Icon(Icons.share_outlined, size: 16),
                            label: const Text(
                              'Passar Contato para Irmão Responsável (WhatsApp)',
                            ),
                            onPressed: () =>
                                PersonHandOffHelper.sendViaWhatsApp(
                                  person: _selectedPinPerson!,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
  }

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
