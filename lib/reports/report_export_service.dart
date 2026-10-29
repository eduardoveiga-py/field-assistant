import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/date_utils.dart';
import '../dashboard/counting_rules.dart';
import '../database/app_database.dart';
import '../territory/landmark_manager.dart';
import '../territory/sector_manager.dart';
import 'web_downloader.dart';

class ReportExportService {
  static String _getPioneerModalityLabel(int goal) {
    switch (goal) {
      case 15:
        return 'Pioneiro Auxiliar (15h)';
      case 30:
        return 'Pioneiro Auxiliar (30h)';
      case 100:
        return 'Pioneiro Especial (100h)';
      case 50:
      default:
        return 'Pioneiro Regular (50h)';
    }
  }

  /// Gera e abre impressão / download para Estatísticas do Ministério
  static Future<void> exportMinistryStatisticsPdf({
    required BuildContext context,
    required DashboardMetrics metrics,
    required List<ActivityRecordEntry> activities,
    required List<BibleStudyEntry> studies,
    required DateTime period,
    required String periodMode,
    double? scheduledHours,
    double? actualHours,
    int? personalGoalHours,
  }) async {
    final pdf = pw.Document();

    final monthNames = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final periodTitle = periodMode == 'Ano de Serviço'
        ? 'Ano de Serviço (01/09 a 31/08)'
        : '${monthNames[period.month - 1]} de ${period.year}';

    final totalHoursStr = AppDateUtils.formatDuration(metrics.totalActivitySeconds);
    final int goal = personalGoalHours ?? 50;
    final modalityLabel = _getPioneerModalityLabel(goal);
    final isYearMode = periodMode == 'Ano de Serviço';
    final effectiveGoal = isYearMode ? goal * 12 : goal;
    final totalActualHours = actualHours ?? (metrics.totalActivitySeconds / 3600.0);
    final goalProgressPct = effectiveGoal > 0 ? (totalActualHours / effectiveGoal) : 0.0;
    final remainingHours = (effectiveGoal - totalActualHours).clamp(0.0, effectiveGoal.toDouble());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Cabeçalho Principal do Ministério
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RELATÓRIO DO MINISTÉRIO PESSOAL',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Período: $periodTitle',
                      style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey800),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(modalityLabel, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Emissão: ${AppDateUtils.formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Resumo de Metas, Modalidade e Horas da Agenda
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('MODALIDADE / META', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 3),
                      pw.Text('$effectiveGoal h', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text(modalityLabel, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(width: 1, height: 32, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text('HORAS REALIZADAS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                      pw.SizedBox(height: 3),
                      pw.Text('${totalActualHours.toStringAsFixed(1)} h', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                      pw.Text(totalHoursStr, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(width: 1, height: 32, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text('HORAS PROGRAMADAS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 3),
                      pw.Text('${(scheduledHours ?? 0.0).toStringAsFixed(1)} h', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text(
                        scheduledHours != null && scheduledHours > 0
                            ? (totalActualHours >= scheduledHours
                                ? (((totalActualHours - scheduledHours) * 60).round() >= 1
                                    ? '100% cumprido (+${AppDateUtils.formatDuration(((totalActualHours - scheduledHours) * 3600).round())})'
                                    : '100% cumprido')
                                : '${((totalActualHours / scheduledHours) * 100).toStringAsFixed(0)}% cumprido')
                            : 'Sem agendamentos',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Container(width: 1, height: 32, color: PdfColors.blue200),
                  pw.Column(
                    children: [
                      pw.Text('COMPARAÇÃO COM META', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        '${(goalProgressPct * 100).toStringAsFixed(0)}%',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: totalActualHours >= effectiveGoal ? PdfColors.green800 : PdfColors.indigo900),
                      ),
                      pw.Text(
                        totalActualHours >= effectiveGoal
                            ? '+${(totalActualHours - effectiveGoal).toStringAsFixed(1)} h excedentes'
                            : 'Faltam ${remainingHours.toStringAsFixed(1)} h',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: totalActualHours >= effectiveGoal ? PdfColors.green800 : PdfColors.orange900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Indicadores Principais e Estatísticas Completas do Ministério
            pw.Text('Ficha Estatística do Ministério (Witness Work)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildPdfHeaderCell('Horas'),
                    _buildPdfHeaderCell('Revisitas'),
                    _buildPdfHeaderCell('Estudos Bíblicos'),
                    _buildPdfHeaderCell('Sessões Dadas'),
                    _buildPdfHeaderCell('Assistência Total'),
                    _buildPdfHeaderCell('Média / Estudo'),
                    _buildPdfHeaderCell('Publicações'),
                    _buildPdfHeaderCell('Vídeos'),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildPdfValueCell(totalHoursStr),
                    _buildPdfValueCell('${metrics.heldVisitsCount}'),
                    _buildPdfValueCell('${metrics.activeStudiesCount}'),
                    _buildPdfValueCell('${metrics.heldSessionsCount}'),
                    _buildPdfValueCell('${metrics.totalStudyAttendance}'),
                    _buildPdfValueCell('${metrics.averageAttendancePerStudy}'),
                    _buildPdfValueCell('${metrics.totalPlacements}'),
                    _buildPdfValueCell('${metrics.totalVideos}'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Tabela Detalhada de Lançamentos de Atividade
            pw.Text('Registro de Atividades de Campo (${activities.length} lançamentos)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 6),
            if (activities.isEmpty)
              pw.Text('Nenhuma atividade avulsa registrada no período.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildPdfHeaderCell('Data'),
                      _buildPdfHeaderCell('Duração'),
                      _buildPdfHeaderCell('Modalidade'),
                      _buildPdfHeaderCell('Observações / Ponto'),
                    ],
                  ),
                  ...activities.map((a) {
                    final h = (a.durationSeconds / 3600).floor();
                    final m = ((a.durationSeconds % 3600) / 60).round();
                    final durStr = '${h}h ${m.toString().padLeft(2, "0")}min';
                    return pw.TableRow(
                      children: [
                        _buildPdfCell(AppDateUtils.formatDate(a.date)),
                        _buildPdfCell(durStr),
                        _buildPdfCell(a.modality),
                        _buildPdfCell(a.notes ?? '-'),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 16),

            // Tabela de Estudos Bíblicos Ativos
            pw.Text('Estudos Bíblicos Cadastrados (${studies.length})', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 6),
            if (studies.isEmpty)
              pw.Text('Nenhum estudo bíblico ativo cadastrado.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildPdfHeaderCell('Estudante / Título'),
                      _buildPdfHeaderCell('Lição'),
                      _buildPdfHeaderCell('Publicação'),
                      _buildPdfHeaderCell('Frequência'),
                      _buildPdfHeaderCell('Situação'),
                    ],
                  ),
                  ...studies.map((s) => pw.TableRow(
                    children: [
                      _buildPdfCell(s.title),
                      _buildPdfCell('Lição ${s.currentLesson ?? 1}'),
                      _buildPdfCell(s.publicationId),
                      _buildPdfCell(s.frequency),
                      _buildPdfCell(s.status),
                    ],
                  )),
                ],
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'relatorio_estatisticas_ministerio.pdf',
    );
  }

  /// Gera e abre impressão / download para o Mapa Geral dos Contatos e Território
  static Future<void> exportContactsMapPdf({
    required BuildContext context,
    required List<PersonEntry> people,
    required List<TerritoryLandmark> landmarks,
    required List<TerritorySector> sectors,
  }) async {
    final pdf = pw.Document();

    final activePeople = people.where((p) => p.deletedAt == null).toList();
    final estudos = activePeople.where((p) => p.status == 'estudo').toList();
    final revisitas = activePeople.where((p) => p.status == 'revisita').toList();
    final interessados = activePeople.where((p) => p.status == 'interessado').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Cabeçalho
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MAPA GERAL DO TERRITÓRIO E CONTATOS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('Visão completa de Estudos, Revisitas e Interessados', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Relatório Territorial', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('Emissão: ${AppDateUtils.formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 12),

            // Resumo Quantitativo
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Text('Total de Contatos: ${activePeople.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('Estudos: ${estudos.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.purple800, fontSize: 11)),
                  pw.Text('Revisitas: ${revisitas.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal800, fontSize: 11)),
                  pw.Text('Interessados: ${interessados.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, fontSize: 11)),
                  pw.Text('Marcos: ${landmarks.length}', style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Lista de Contatos Mapeados
            pw.Text('Lista Detalhada de Contatos do Território (${activePeople.length})', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(4.0),
                4: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildPdfHeaderCell('Nome'),
                    _buildPdfHeaderCell('Situação'),
                    _buildPdfHeaderCell('Telefone'),
                    _buildPdfHeaderCell('Endereço / Bairro'),
                    _buildPdfHeaderCell('Horário Habitual'),
                  ],
                ),
                ...activePeople.map((p) => pw.TableRow(
                  children: [
                    _buildPdfCell(p.name, bold: true),
                    _buildPdfCell(p.status.toUpperCase()),
                    _buildPdfCell(p.phone ?? '-'),
                    _buildPdfCell(p.address ?? '-'),
                    _buildPdfCell(p.preferredSchedule ?? '-'),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),

            // Marcos e Pontos de Referência
            if (landmarks.isNotEmpty) ...[
              pw.Text('Marcos e Pontos de Referência do Território (${landmarks.length})', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(4),
                  3: const pw.FlexColumnWidth(3),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildPdfHeaderCell('Nome do Marco'),
                      _buildPdfHeaderCell('Categoria'),
                      _buildPdfHeaderCell('Endereço / Localização'),
                      _buildPdfHeaderCell('Coordenadas GPS'),
                    ],
                  ),
                  ...landmarks.map((l) => pw.TableRow(
                    children: [
                      _buildPdfCell(l.name, bold: true),
                      _buildPdfCell(l.category.toUpperCase()),
                      _buildPdfCell(l.address ?? '-'),
                      _buildPdfCell(l.latitude != null ? '${l.latitude!.toStringAsFixed(4)}, ${l.longitude!.toStringAsFixed(4)}' : '-'),
                    ],
                  )),
                ],
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'mapa_geral_territorio_contatos.pdf',
    );
  }

  /// Gera e abre impressão / download otimizado para Trabalho por Telefone
  static Future<void> exportPhoneWitnessingPdf({
    required BuildContext context,
    required List<PersonEntry> contacts,
    required String filterStatus,
    required String filterNeighborhood,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Cabeçalho da Lista Telefônica
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LISTA PARA TESTEMUNHO POR TELEFONE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Filtros: Situação: $filterStatus | Bairro: $filterNeighborhood (${contacts.length} contatos)',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Testemunho Pessoal', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.Text('Data: ${AppDateUtils.formatDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue800),
            pw.SizedBox(height: 8),

            // Tabela Especial com Telefones em Destaque e Checkboxes para o Publicador
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.0),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(2.5),
                4: const pw.FlexColumnWidth(2.2),
                5: const pw.FlexColumnWidth(3.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildPdfHeaderCell('Nome do Contato'),
                    _buildPdfHeaderCell('Telefone / WhatsApp'),
                    _buildPdfHeaderCell('Situação'),
                    _buildPdfHeaderCell('Bairro / Endereço'),
                    _buildPdfHeaderCell('Último Contato'),
                    _buildPdfHeaderCell('Anotações da Ligação / Retorno'),
                  ],
                ),
                ...contacts.map((c) {
                  final phoneStr = (c.phone != null && c.phone!.trim().isNotEmpty) ? c.phone! : 'Sem telefone';
                  final lastContactStr = c.lastContactAt != null ? AppDateUtils.formatDate(c.lastContactAt) : 'Sem registro';

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(c.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            if (c.preferredSchedule != null)
                              pw.Text('Pref: ${c.preferredSchedule}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          phoneStr,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: c.phone != null ? PdfColors.blue900 : PdfColors.grey600,
                          ),
                        ),
                      ),
                      _buildPdfCell(c.status.toUpperCase()),
                      _buildPdfCell(c.address ?? '-'),
                      _buildPdfCell(lastContactStr),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              children: [
                                pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700))),
                                pw.SizedBox(width: 3),
                                pw.Text('Atendeu  ', style: const pw.TextStyle(fontSize: 7)),
                                pw.Container(width: 8, height: 8, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700))),
                                pw.SizedBox(width: 3),
                                pw.Text('Não atendeu', style: const pw.TextStyle(fontSize: 7)),
                              ],
                            ),
                            pw.SizedBox(height: 3),
                            if (c.generalNotes != null && c.generalNotes!.isNotEmpty)
                              pw.Text('Obs: ${c.generalNotes}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600), maxLines: 1),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'lista_trabalho_telefone.pdf',
    );
  }

  /// Gera string CSV formatada em UTF-8 compatível com Excel
  static String generateCsvForContacts(List<PersonEntry> contacts) {
    final buffer = StringBuffer();
    // UTF-8 BOM para o Excel abrir sem corromper acentuação em PT-BR
    buffer.write('\uFEFF');

    // Cabeçalho CSV separado por ponto e vírgula
    buffer.writeln('Nome;Telefone;Situação;Bairro/Endereço;Horário Habitual;Último Contato;Próxima Ação;Latitude;Longitude;Anotações');

    for (final c in contacts) {
      if (c.deletedAt != null) continue;
      final name = _cleanCsv(c.name);
      final phone = _cleanCsv(c.phone ?? '');
      final status = _cleanCsv(c.status);
      final address = _cleanCsv(c.address ?? '');
      final schedule = _cleanCsv(c.preferredSchedule ?? '');
      final lastContact = c.lastContactAt != null ? AppDateUtils.formatDate(c.lastContactAt) : '';
      final nextAction = c.nextActionAt != null ? AppDateUtils.formatDate(c.nextActionAt) : '';
      final lat = c.latitude?.toString() ?? '';
      final lng = c.longitude?.toString() ?? '';
      final notes = _cleanCsv(c.generalNotes ?? '');

      buffer.writeln('$name;$phone;$status;$address;$schedule;$lastContact;$nextAction;$lat;$lng;$notes');
    }

    return buffer.toString();
  }

  /// Faz o download do arquivo CSV
  static void downloadCsv(String filename, String csvContent) {
    FileDownloader.download(filename, csvContent);
  }

  static String _cleanCsv(String text) {
    final clean = text.replaceAll('"', '""').replaceAll('\n', ' ').replaceAll('\r', '');
    return '"$clean"';
  }

  static pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.grey900),
      ),
    );
  }

  static pw.Widget _buildPdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _buildPdfValueCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }
}
