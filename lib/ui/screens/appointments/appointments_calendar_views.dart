part of '../appointments_screen.dart';

extension _AppointmentsCalendarViews on _AppointmentsScreenState {
  // 1. Visão de Calendário Mensal Google Calendar Style
  Widget _buildMonthCalendarView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday =
        firstDayOfMonth.weekday % 7; // 0 = Domingo, 1 = Segunda...

    final Map<int, List<AppointmentEntry>> apptsByDay = {};
    for (final a in allAppts) {
      if (a.deletedAt == null &&
          a.startTime.year == year &&
          a.startTime.month == month) {
        apptsByDay.putIfAbsent(a.startTime.day, () => []).add(a);
      }
    }

    final selectedDayAppts = apptsByDay[_selectedDate.day] ?? [];
    final holidaysOnSelectedDay = BrazilHolidays.onDay(_selectedDate);
    final holidaysByDay = {
      for (final h in BrazilHolidays.inRange(
        DateTime(year, month, 1),
        DateTime(year, month, daysInMonth),
      ))
        h.date.day,
    };

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho dos dias da semana
              Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text(
                          'DOM',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppTheme.alertRed,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'SEG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'TER',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'QUA',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'QUI',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'SEX',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'SÁB',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF93C5FD)
                                : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Grade 7 colunas Google Calendar Style
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 72,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final dayNumber = index - startingWeekday + 1;
                  final isCurrentMonth =
                      dayNumber >= 1 && dayNumber <= daysInMonth;

                  if (!isCurrentMonth) {
                    return const SizedBox.shrink();
                  }

                  final cellDate = DateTime(year, month, dayNumber);
                  final isSelected =
                      cellDate.day == _selectedDate.day &&
                      cellDate.month == _selectedDate.month &&
                      cellDate.year == _selectedDate.year;
                  final isToday =
                      cellDate.day == DateTime.now().day &&
                      cellDate.month == DateTime.now().month &&
                      cellDate.year == DateTime.now().year;
                  final dayAppts = apptsByDay[dayNumber] ?? [];
                  final isHoliday = holidaysByDay.contains(dayNumber);

                  return InkWell(
                    onTap: () {
                      _updateState(() => _selectedDate = cellDate);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                  ? const Color(0xFF3B82F6)
                                        .withValues(alpha: 0.25)
                                  : AppTheme.primaryBlue.withValues(
                                      alpha: 0.12,
                                    ))
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? (isDark
                                    ? const Color(0xFF60A5FA)
                                    : AppTheme.primaryBlue)
                              : isToday
                              ? AppTheme.accentTeal
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : Colors.grey.shade200),
                          width: isSelected || isToday ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: isToday
                                    ? BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF3B82F6)
                                            : AppTheme.primaryBlue,
                                        borderRadius: BorderRadius.circular(8),
                                      )
                                    : null,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isToday
                                        ? Colors.white
                                        : (index % 7 == 0
                                              ? AppTheme.alertRed
                                              : (isDark
                                                    ? Colors.white
                                                    : AppTheme.textDark)),
                                  ),
                                ),
                              ),
                              if (isHoliday)
                                const Icon(
                                  Icons.celebration_outlined,
                                  size: 12,
                                  color: Color(0xFFB45309),
                                )
                              else if (dayAppts.length > 2)
                                Text(
                                  '+${dayAppts.length - 2}',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          for (final a in dayAppts.take(2)) ...[
                            Builder(
                              builder: (context) {
                                final color =
                                    _AppointmentsScreenState._getAppointmentActivityColor(
                                      a,
                                    );
                                final timeStr = AppDateUtils.formatTime(
                                  a.startTime,
                                );
                                return ClipRect(
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                        alpha: isDark ? 0.35 : 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.6),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? color.withValues(
                                                      alpha: 0.95,
                                                    )
                                                  : color,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Expanded(
                                          child: Text(
                                            a.title,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : AppTheme.textDark,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Divider(height: 1),

              // Painel Inferior: Lista de compromissos do dia selecionado
              Container(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Compromissos em ${AppDateUtils.formatDate(_selectedDate)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text(
                            'Novo',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _showNewAppointmentModal(
                            context,
                            initialDateTime: _selectedDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (holidaysOnSelectedDay.isNotEmpty) ...[
                      ...holidaysOnSelectedDay.map(
                        (h) => Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3B2F0B)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF92600A)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.celebration_outlined,
                                size: 18,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Feriado: ${h.name}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (selectedDayAppts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Nenhum compromisso agendado para esta data.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...selectedDayAppts.map((appt) {
                        final isDone = appt.status == 'realizado';
                        final color =
                            _AppointmentsScreenState._getAppointmentActivityColor(
                              appt,
                            );

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(
                                  alpha: isDark ? 0.25 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppDateUtils.formatTime(appt.startTime),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: color,
                                    ),
                                  ),
                                  Text(
                                    '${appt.durationMinutes}m',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark
                                          ? const Color(0xFFCBD5E1)
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            title: Text(
                              appt.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              appt.locationNotes ?? 'Status: ${appt.status}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : AppTheme.textMuted,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert, size: 20),
                              onPressed: () =>
                                  _showAppointmentActions(context, appt),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Visão de Calendário Semanal
  Widget _buildWeekCalendarView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monday = _selectedDate.subtract(
      Duration(days: (_selectedDate.weekday - 1) % 7),
    );
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final isToday =
            day.day == DateTime.now().day &&
            day.month == DateTime.now().month &&
            day.year == DateTime.now().year;
        final dayAppts =
            allAppts
                .where(
                  (a) =>
                      a.deletedAt == null &&
                      a.startTime.year == day.year &&
                      a.startTime.month == day.month &&
                      a.startTime.day == day.day,
                )
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

        const weekdayNames = [
          'Segunda',
          'Terça',
          'Quarta',
          'Quinta',
          'Sexta',
          'Sábado',
          'Domingo',
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday
                  ? AppTheme.accentTeal
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              width: isToday ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isToday
                      ? (isDark
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.25)
                            : AppTheme.primaryBlue.withValues(alpha: 0.1))
                      : (isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC)),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(9),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${weekdayNames[index]} • ${AppDateUtils.formatDate(day)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isToday
                            ? AppTheme.primaryBlue
                            : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                    ),
                    Text(
                      '${dayAppts.length} compromisso(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (dayAppts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Nenhum compromisso',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                )
              else
                ...dayAppts.map((appt) {
                  final color =
                      _AppointmentsScreenState._getAppointmentActivityColor(
                        appt,
                      );
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.3 : 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppDateUtils.formatTime(appt.startTime),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: color,
                        ),
                      ),
                    ),
                    title: Text(
                      appt.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: appt.locationNotes != null
                        ? Text(
                            appt.locationNotes!,
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: () => _showAppointmentActions(context, appt),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // 3. Visão de Calendário Diário por Hora
  Widget _buildDayHourlyGridView(List<AppointmentEntry> allAppts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayAppts = allAppts
        .where(
          (a) =>
              a.deletedAt == null &&
              a.startTime.year == _selectedDate.year &&
              a.startTime.month == _selectedDate.month &&
              a.startTime.day == _selectedDate.day,
        )
        .toList();

    return SingleChildScrollView(
      controller: _timeScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: List.generate(16, (i) {
              final hour = 7 + i; // 07:00 às 22:00
              final hourStart = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                hour,
                0,
              );
              final hourEnd = hourStart.add(const Duration(hours: 1));

              final inThisHour = dayAppts
                  .where(
                    (a) =>
                        a.startTime.isBefore(hourEnd) &&
                        a.endTime.isAfter(hourStart),
                  )
                  .toList();

              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: inThisHour.isEmpty
                          ? InkWell(
                              onTap: () {
                                _showNewAppointmentModal(
                                  context,
                                  initialDateTime: DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    _selectedDate.day,
                                    hour,
                                    0,
                                  ),
                                );
                              },
                              child: const SizedBox.expand(),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: inThisHour.length,
                              itemBuilder: (ctx, idx) {
                                final appt = inThisHour[idx];
                                final color =
                                    _AppointmentsScreenState._getAppointmentActivityColor(
                                      appt,
                                    );
                                return InkWell(
                                  onTap: () =>
                                      _showAppointmentActions(context, appt),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                        alpha: isDark ? 0.35 : 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${AppDateUtils.formatTime(appt.startTime)} ${appt.title}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : color,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // 4. Visão em Lista Linear
  Widget _buildListView(
    List<AppointmentEntry> allAppts, {
    bool isWide = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeAppts =
        allAppts
            .where((a) => a.deletedAt == null && a.status != 'cancelado')
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (activeAppts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Nenhum compromisso cadastrado na agenda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      itemCount: activeAppts.length,
      itemBuilder: (context, index) {
        final appt = activeAppts[index];
        final isDone = appt.status == 'realizado';
        final isSelected = isWide && _selectedAppointmentId == appt.id;
        final color = _AppointmentsScreenState._getAppointmentActivityColor(
          appt,
        );

        return Semantics(
          container: true,
          selected: isSelected,
          button: true,
          label:
              '${appt.title}, ${AppDateUtils.formatDateTime(appt.startTime)}',
          child: Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isSelected
                  ? const BorderSide(color: AppTheme.primaryBlue, width: 2)
                  : BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
            ),
            child: ListTile(
              onTap: isWide
                  ? () => _updateState(() => _selectedAppointmentId = appt.id)
                  : () => _showAppointmentActions(context, appt),
              leading: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.3 : 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppDateUtils.formatTime(appt.startTime),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                    Text(
                      '${appt.durationMinutes}m',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                appt.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                '${AppDateUtils.formatDate(appt.startTime)} • ${appt.locationNotes ?? appt.status}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : AppTheme.textMuted,
                ),
              ),
              trailing: Semantics(
                button: true,
                label: 'Mais opções para ${appt.title}',
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showAppointmentActions(context, appt),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static List<AppointmentEntry> _appointmentsWithTasksAndProjects(
    List<AppointmentEntry> appointments,
    List<TaskEntry> tasks,
    List<ProjectEntry> projects,
  ) {
    final taskAppts = <AppointmentEntry>[];
    for (final task in tasks) {
      if (task.dueDate == null ||
          task.status == 'completed' ||
          task.status == 'cancelled')
        continue;
      final due = task.dueDate!;
      final start = (due.hour != 0 || due.minute != 0)
          ? due
          : DateTime(due.year, due.month, due.day, 9, 0);
      final end = start.add(const Duration(hours: 1));
      taskAppts.add(
        AppointmentEntry(
          id: 'task:${task.id}',
          title: '📋 ${task.title}',
          startTime: start,
          endTime: end,
          durationMinutes: 60,
          status: 'planejado',
          locationNotes:
              'Prazo de Tarefa • Prioridade: ${task.priority}${task.description != null ? "\n${task.description}" : ""}',
          isProvisional: false,
          createdAt: task.createdAt,
          updatedAt: task.updatedAt,
          revision: task.revision,
        ),
      );
    }

    final projectAppts = <AppointmentEntry>[];
    for (final project in projects) {
      if (project.targetDate == null ||
          project.status == 'completed' ||
          project.status == 'archived')
        continue;
      final target = project.targetDate!;
      final start = (target.hour != 0 || target.minute != 0)
          ? target
          : DateTime(target.year, target.month, target.day, 10, 0);
      final end = start.add(const Duration(hours: 1));
      projectAppts.add(
        AppointmentEntry(
          id: 'project:${project.id}',
          title: '🎯 ${project.name}',
          startTime: start,
          endTime: end,
          durationMinutes: 60,
          status: 'planejado',
          locationNotes:
              'Prazo do Projeto${project.description != null ? "\n${project.description}" : ""}',
          isProvisional: false,
          createdAt: project.createdAt,
          updatedAt: project.updatedAt,
          revision: project.revision,
        ),
      );
    }

    return [...appointments, ...taskAppts, ...projectAppts];
  }
}
