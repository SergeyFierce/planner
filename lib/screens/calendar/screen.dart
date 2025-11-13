import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'controller.dart';

const int _minutesInDay = 24 * 60;

String _formatTime(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

String _formatMinutes(int minuteOfDay) {
  final hours = (minuteOfDay ~/ 60) % 24;
  final minutes = minuteOfDay % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

String _formatDurationShort(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '${hours}ч ${minutes}м';
  } else if (hours > 0) {
    return '${hours}ч';
  } else {
    return '${minutes}м';
  }
}

String _formatFriendlyDate(DateTime date) {
  const weekdays = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  final weekdayName = weekdays[date.weekday - 1];
  final monthName = months[date.month - 1];

  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));

  if (DateUtils.isSameDay(date, today)) {
    return 'Сегодня · $weekdayName, ${date.day} $monthName ${date.year}';
  } else if (DateUtils.isSameDay(date, tomorrow)) {
    return 'Завтра · $weekdayName, ${date.day} $monthName ${date.year}';
  } else {
    return '$weekdayName, ${date.day} $monthName ${date.year}';
  }
}

/// Режим отображения календаря: день / месяц.
enum CalendarViewMode {
  day,
  month,
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final CalendarController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initialMonth,
    required this.selectedDay,
    required this.controller,
  });

  final DateTime initialMonth;
  final DateTime selectedDay;
  final CalendarController controller;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late DateTime _visibleMonth;
  double _dragOffset = 0; // отрицательное значение = вверх

  bool _isYearPickerOpen = false;
  final ScrollController _yearScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month - 1,
        1,
      );
    });
  }

  void _goToNextMonth() {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + 1,
        1,
      );
    });
  }

  void _changeYear(int year) {
    setState(() {
      _visibleMonth = DateTime(year, _visibleMonth.month, 1);
    });
  }

  void _toggleYearPicker() {
    setState(() {
      _isYearPickerOpen = !_isYearPickerOpen;
    });

    if (_isYearPickerOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_yearScrollController.hasClients) return;

        const int firstYear = 1900;
        const int lastYear = 2100;

        // 👇 Вместо текущего года — используем ВЫБРАННЫЙ год (_visibleMonth.year)
        final int selectedYear =
        _visibleMonth.year.clamp(firstYear, lastYear);

        final int index = selectedYear - firstYear; // 0..N

        // 👇 Пропорционально скроллим к выбранному году,
        // чтобы не зависеть от точной высоты ячеек
        final max = _yearScrollController.position.maxScrollExtent;
        final int totalYears = lastYear - firstYear + 1;
        final double targetOffset =
        totalYears > 1 ? max * (index / (totalYears - 1)) : 0.0;

        _yearScrollController.jumpTo(
          targetOffset.clamp(0.0, max),
        );
      });
    }
  }


  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragOffset =
                    (_dragOffset + details.delta.dy).clamp(-200.0, 0.0);
              });
            },
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final shouldClose =
                  _dragOffset < -80 || velocity < -400;
              if (shouldClose) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  _dragOffset = 0;
                });
              }
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 400, // ⬅️ БЫЛО 340
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 35, 16, 16),
                    child: _MonthView(
                      month: _visibleMonth,
                      selectedDay: widget.selectedDay,
                      controller: widget.controller,
                      onDaySelected: (date) {
                        Navigator.of(context).pop(date);
                      },
                      onYearChanged: _changeYear,
                      onPreviousMonth: _goToPreviousMonth,
                      onNextMonth: _goToNextMonth,
                      isYearPickerOpen: _isYearPickerOpen,
                      onToggleYearPicker: _toggleYearPicker,
                      yearScrollController: _yearScrollController,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _CalendarScreenState extends State<CalendarScreen> {
  final GlobalKey<_CalendarTimelineState> _timelineKey =
  GlobalKey<_CalendarTimelineState>();

  CalendarController get _controller => widget.controller;

  bool _isFreeSlotsExpanded = false;
  bool _isCompletedExpanded = false;
  CalendarViewMode _viewMode = CalendarViewMode.day;
  late DateTime _visibleMonth;

  Timer? _summaryTimer;

  @override
  void initState() {
    super.initState();
    _visibleMonth = _controller.day;

    // Таймер для обновления карточки "Сейчас / Далее" и прочих вычислений
    _summaryTimer =
        Timer.periodic(const Duration(seconds: 30), (_) {
          if (!mounted) return;
          setState(() {});
        });
  }

  @override
  void dispose() {
    _summaryTimer?.cancel();
    super.dispose();
  }

  Future<void> _openMonthPickerTopSheet() async {
    final selected = await showGeneralDialog<DateTime>(
      context: context,
      barrierLabel: 'MonthPicker',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _MonthPickerDialog(
          initialMonth: _visibleMonth,
          selectedDay: _controller.day,
          controller: _controller,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _controller.setDay(selected);
        _visibleMonth = DateTime(selected.year, selected.month, 1);
      });

      final now = DateTime.now();
      final bool isToday = DateUtils.isSameDay(selected, now);

      final targetTime = isToday
          ? DateTime(
        selected.year,
        selected.month,
        selected.day,
        now.hour,
        now.minute,
      )
          : DateTime(selected.year, selected.month, selected.day, 9);

      _timelineKey.currentState?.scrollTo(targetTime);
    }
  }

  Future<void> _onAddTaskPressed() async {
    final now = DateTime.now();
    final initialTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final picked = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      initialTime: initialTime,
      cancelText: 'Отмена',
      confirmText: 'Добавить',
      helpText: 'Выберите время задачи',
    );

    if (picked == null || !mounted) {
      return;
    }

    final selectedDate = DateTime(
      _controller.day.year,
      _controller.day.month,
      _controller.day.day,
      picked.hour,
      picked.minute,
    );
    final snapped = _snapToInterval(selectedDate, minutes: 5);

    final newEvent = _controller.createEvent(
      title: 'Новая задача',
      start: snapped,
      duration: const Duration(minutes: 30),
    );

    setState(() {});

    _timelineKey.currentState?.scrollTo(snapped);

    final timeRange =
        '${_formatTime(snapped)} – ${_formatTime(newEvent.end)}';
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Задача добавлена на $timeRange')),
    );
  }

  static DateTime _snapToInterval(DateTime value, {int minutes = 5}) {
    final totalMinutes = value.hour * 60 + value.minute;
    final snappedMinutes = (totalMinutes / minutes).round() * minutes;
    return DateTime(
      value.year,
      value.month,
      value.day,
      snappedMinutes ~/ 60,
      snappedMinutes % 60,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    final overview = _controller.overview;
    final freeSlots = _controller.freeSlots;
    final bestSlot = _controller.bestFocusSlot;
    final events = _controller.events;
    // карточку завершённых задач убираем — completedEvents больше не нужен

    return Scaffold(
      backgroundColor: cs.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 12),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          child: AppBar(
            elevation: 0,
            backgroundColor: cs.surfaceVariant,
            centerTitle: true,
            // убираем стандартный leading, чтобы заголовок реально был по центру
            leading: const SizedBox.shrink(),
            leadingWidth: 0,
            titleSpacing: 0,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final isCompact = maxWidth < 360;

                final baseStyle =
                    textTheme.titleLarge ?? const TextStyle(fontSize: 20);
                final textStyle = baseStyle.copyWith(
                  // Чуть уменьшаем шрифт на очень узких экранах
                  fontSize: isCompact
                      ? (baseStyle.fontSize ?? 20) - 2
                      : baseStyle.fontSize,
                  fontWeight: FontWeight.w700,
                );

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420, // чтобы на планшете не растягивалось бесконечно
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _openMonthPickerTopSheet,
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _formatFriendlyDate(_controller.day),
                                style: textStyle,
                                textAlign: TextAlign.center,
                                maxLines: 2, // разрешаем перенос на 2 строки
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔥 УБРАЛИ _ViewModeSwitcher
              // const SizedBox(height: 12),  // можно оставить один отступ, если надо
              const SizedBox(height: 12),
              _DaySummaryCard(
                overview: overview,
                day: _controller.day,
                events: events,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CalendarTimeline(
                  key: _timelineKey,
                  day: _controller.day,
                  events: events,
                  freeSlots: freeSlots,
                  onAddRequested: _onAddTaskPressed,
                  onToggleEventDone: (event) {
                    setState(() {
                      _controller.toggleEventCompletion(event);
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              _FreeSlotsSection(
                freeSlots: freeSlots,
                bestSlot: bestSlot,
                isExpanded: _isFreeSlotsExpanded,
                onToggle: () {
                  setState(() {
                    _isFreeSlotsExpanded = !_isFreeSlotsExpanded;
                  });
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _onAddTaskPressed,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Новая задача'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewModeSwitcher extends StatelessWidget {
  const _ViewModeSwitcher({
    required this.mode,
    required this.onModeChanged,
  });

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SegmentedButton<CalendarViewMode>(
          segments: const <ButtonSegment<CalendarViewMode>>[
            ButtonSegment<CalendarViewMode>(
              value: CalendarViewMode.day,
              label: Text('День'),
              icon: Icon(Icons.view_day_rounded),
            ),
            ButtonSegment<CalendarViewMode>(
              value: CalendarViewMode.month,
              label: Text('Месяц'),
              icon: Icon(Icons.calendar_month_rounded),
            ),
          ],
          selected: {mode},
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return cs.primary.withOpacity(0.08);
              }
              return cs.surfaceVariant.withOpacity(0.5);
            }),
          ),
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            onModeChanged(selection.first);
          },
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.overview,
    required this.day,
    required this.events,
  });

  final DayOverview overview;
  final DateTime day;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    final totalEvents = overview.totalEvents;
    final hasEvents = totalEvents > 0;

    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(day, now);

    // Прогресс: выполнено / всего (по событиям дня)
    final completedEvents = events.where((e) => e.isDone).length;
    final double tasksProgress =
    hasEvents ? (completedEvents / totalEvents) : 0.0;
    final int tasksPercent = (tasksProgress * 100).round();

    // Определяем текущую и следующую задачи
    CalendarEvent? currentEvent;
    CalendarEvent? upcomingEvent;

    if (isToday && hasEvents) {
      final sorted = [...events]..sort((a, b) => a.start.compareTo(b.start));
      for (final e in sorted) {
        final bool isOngoing =
            e.start.isBefore(now) && e.end.isAfter(now);
        if (isOngoing) {
          currentEvent = e;
          continue;
        }

        if (e.start.isAfter(now)) {
          upcomingEvent ??= e;
          if (currentEvent != null) break;
        }
      }
    }

    // Заголовок
    String primaryLine;
    if (hasEvents) {
      primaryLine = '$totalEvents задач на этот день';
    } else if (isToday) {
      primaryLine = 'Сегодня пока нет задач';
    } else {
      primaryLine = 'На этот день пока нет задач';
    }

    // Линии для блока "Сейчас / Далее"
    String? currentLine;
    String? nextLine;
    IconData? currentIcon;
    IconData? nextIcon;

    if (isToday && currentEvent != null) {
      currentIcon = Icons.play_arrow_rounded;
      currentLine =
      'Сейчас: ${currentEvent.title} до ${_formatTime(currentEvent.end)}';
      if (upcomingEvent != null) {
        nextIcon = Icons.schedule_rounded;
        nextLine =
        'Далее: ${upcomingEvent.title} в ${_formatTime(upcomingEvent.start)}';
      }
    } else if (isToday &&
        currentEvent == null &&
        upcomingEvent != null) {
      nextIcon = Icons.schedule_rounded;
      nextLine =
      'Следующее сегодня в ${_formatTime(upcomingEvent.start)} — ${upcomingEvent.title}';
    } else if (isToday &&
        hasEvents &&
        currentEvent == null &&
        upcomingEvent == null) {
      nextIcon = Icons.check_circle_rounded;
      nextLine = 'Все задачи на сегодня уже позади';
    } else if (!isToday && hasEvents) {
      nextIcon = Icons.calendar_month_rounded;
      nextLine = 'План на этот день уже составлен';
    } else {
      nextIcon = Icons.auto_awesome_rounded;
      nextLine =
      'Запланируйте хотя бы одну задачу — я помогу всё разложить по времени';
    }

    TextStyle labelStrong(TextStyle? base) =>
        (base ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
        );

    Widget buildHighlightedLine({
      required IconData icon,
      required String text,
      required bool highlightKeyword,
    }) {
      final keywordEnd = text.indexOf(':');
      final hasKeyword =
          highlightKeyword && keywordEnd > 0 && keywordEnd < text.length - 1;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: cs.onPrimaryContainer.withOpacity(0.9),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: cs.onPrimaryContainer.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: hasKeyword
                  ? RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: textTheme.bodySmall?.copyWith(
                    color:
                    cs.onPrimaryContainer.withOpacity(0.9),
                  ),
                  children: [
                    TextSpan(
                      text: text.substring(0, keywordEnd + 1),
                      style: labelStrong(
                          textTheme.bodySmall?.copyWith(
                            color:
                            cs.onPrimaryContainer.withOpacity(0.95),
                          )),
                    ),
                    TextSpan(
                      text: text.substring(keywordEnd + 1),
                    ),
                  ],
                ),
              )
                  : Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color:
                  cs.onPrimaryContainer.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withOpacity(0.85),
            cs.primaryContainer.withOpacity(0.55),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withOpacity(0.14),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 24,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Основная строка
                Text(
                  primaryLine,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (hasEvents) ...[
                  // Прогресс по задачам
                  Row(
                    children: [
                      Text(
                        'Прогресс по задачам',
                        style: textTheme.labelSmall?.copyWith(
                          color:
                          cs.onPrimaryContainer.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$completedEvents / $totalEvents',
                        style: textTheme.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($tasksPercent%)',
                        style: textTheme.labelSmall?.copyWith(
                          color:
                          cs.onPrimaryContainer.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: tasksProgress,
                      minHeight: 6,
                      backgroundColor:
                      cs.onPrimaryContainer.withOpacity(0.12),
                      valueColor:
                      AlwaysStoppedAnimation<Color>(cs.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (currentLine != null)
                  buildHighlightedLine(
                    icon: currentIcon ?? Icons.play_arrow_rounded,
                    text: currentLine!,
                    highlightKeyword: true,
                  ),
                if (currentLine != null && nextLine != null)
                  const SizedBox(height: 6),
                if (nextLine != null)
                  buildHighlightedLine(
                    icon: nextIcon ?? Icons.schedule_rounded,
                    text: nextLine!,
                    highlightKeyword: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeSlotsSection extends StatelessWidget {
  const _FreeSlotsSection({
    required this.freeSlots,
    required this.bestSlot,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<FreeSlot> freeSlots;
  final FreeSlot? bestSlot;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool hasSlots = freeSlots.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.6),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Свободное время',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasSlots)
                    Text(
                      '${freeSlots.length} окон',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: hasSlots
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                if (bestSlot != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Лучшее окно для фокуса: '
                              '${_formatTime(bestSlot!.start)} — ${_formatTime(bestSlot!.end)}'
                              ' (${_formatDurationShort(bestSlot!.duration)})',
                          style:
                          textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in freeSlots)
                      _FreeSlotChip(
                        slot: slot,
                        highlighted: bestSlot != null &&
                            slot.start == bestSlot!.start &&
                            slot.end == bestSlot!.end,
                      ),
                  ],
                ),
              ],
            )
                : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Свободных окон почти нет — берегите себя и оставьте время на отдых.',
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedEventsSection extends StatelessWidget {
  const _CompletedEventsSection({
    required this.completedEvents,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<CalendarEvent> completedEvents;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (completedEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final sorted = [...completedEvents]
      ..sort((a, b) => a.start.compareTo(b.start));

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.6),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Завершённые задачи',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${sorted.length}',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 4),
                for (final e in sorted)
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatTime(e.start)} – ${_formatTime(e.end)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeSlotChip extends StatelessWidget {
  const _FreeSlotChip({
    required this.slot,
    this.highlighted = false,
  });

  final FreeSlot slot;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final borderColor = highlighted
        ? cs.primary
        : cs.outlineVariant.withOpacity(0.7);

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: highlighted
            ? cs.primary.withOpacity(0.12)
            : cs.surfaceVariant.withOpacity(0.5),
        border: Border.all(
          color: borderColor,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            highlighted ? Icons.stars_rounded : Icons.schedule,
            size: 16,
            color: highlighted
                ? cs.primary
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            '${_formatTime(slot.start)} — ${_formatTime(slot.end)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatDurationShort(slot.duration),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarTimeline extends StatefulWidget {
  const CalendarTimeline({
    super.key,
    required this.day,
    required this.events,
    required this.freeSlots,
    required this.onAddRequested,
    required this.onToggleEventDone,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final List<FreeSlot> freeSlots;
  final VoidCallback onAddRequested;
  final ValueChanged<CalendarEvent> onToggleEventDone;

  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline> {
  static const double _timeLabelWidth = 74;
  static const double _pixelsPerMinute = 1.2; // фиксированный масштаб
  static const double _minEventHeight = 28;
  static const double _scrollEdgePadding = 24.0;

  late final ScrollController _scrollController;
  double _viewportHeight = 0;

  DateTime _now = DateTime.now();
  Timer? _timer;

  DateTime get _startOfDay =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  double get _dayHeight => _minutesInDay * _pixelsPerMinute;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _now = DateTime.now();
    _timer =
        Timer.periodic(const Duration(seconds: 15), (_) {
          if (!mounted) return;
          setState(() {
            _now = DateTime.now();
          });
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = context.findRenderObject();
      if (renderBox is RenderBox) {
        _viewportHeight = renderBox.size.height;
      }
      _scrollToInitialPosition();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void scrollTo(DateTime time) {
    final offset =
        (_scrollEdgePadding + _offsetFor(time)) - _viewportHeight / 3;
    _animateTo(offset);
  }

  void _scrollToInitialPosition() {
    if (!DateUtils.isSameDay(_now, widget.day)) {
      return;
    }
    if (_viewportHeight == 0 || !_scrollController.hasClients) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToInitialPosition());
      return;
    }
    final offset =
        (_scrollEdgePadding + _offsetFor(_now)) - _viewportHeight / 2;
    _animateTo(offset, jump: true);
  }

  void _animateTo(double target, {bool jump = false}) {
    if (!_scrollController.hasClients) return;

    final double maxOffset = math.max(
      0,
      (_dayHeight + _scrollEdgePadding * 2) - _viewportHeight,
    );
    final double clamped =
    target.clamp(0.0, maxOffset).toDouble();

    if (jump) {
      _scrollController.jumpTo(clamped);
    } else {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  double _offsetFor(DateTime time) {
    final diff = time.difference(_startOfDay);
    final double minutes = diff.inMilliseconds / 60000.0;
    final double clamped =
    minutes.clamp(0.0, _minutesInDay.toDouble()).toDouble();
    return clamped * _pixelsPerMinute;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalHeight = _dayHeight;
    final showCurrentTime =
    DateUtils.isSameDay(_now, widget.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: theme.colorScheme.surfaceVariant
                  .withOpacity(0.35),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis ==
                      Axis.vertical) {
                    final viewport =
                        notification.metrics.viewportDimension;
                    if ((viewport - _viewportHeight).abs() > 0.5 ||
                        notification is ScrollUpdateNotification ||
                        notification is OverscrollNotification) {
                      setState(() {
                        _viewportHeight = viewport;
                      });
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(vertical: 24),
                    child: SizedBox(
                      height: totalHeight,
                      child: Stack(
                        children: <Widget>[
                          // Сетка времени
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TimelineGridPainter(
                                pixelsPerMinute:
                                _pixelsPerMinute,
                                timeLabelWidth:
                                _timeLabelWidth,
                                theme: theme,
                                textStyle:
                                theme.textTheme.bodySmall ??
                                    const TextStyle(
                                        fontSize: 12),
                              ),
                            ),
                          ),
                          // Фон для свободных интервалов
                          ..._buildFreeSlotBackgrounds(
                              theme, totalHeight),
                          // Индикатор "сейчас" между цифрами и лентой
                          if (showCurrentTime)
                            Positioned(
                              top: _offsetFor(_now),
                              left: 0,
                              right: 0,
                              child: _CurrentTimeIndicator(
                                label: _formatTime(_now),
                                timeLabelWidth:
                                _timeLabelWidth,
                                color:
                                theme.colorScheme.error,
                              ),
                            ),
                          // Карточки событий поверх всего
                          ..._buildEventWidgets(
                              theme, totalHeight),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFreeSlotBackgrounds(
      ThemeData theme,
      double totalHeight,
      ) {
    if (widget.freeSlots.isEmpty) {
      return const <Widget>[];
    }

    final cs = theme.colorScheme;
    final List<Widget> widgets = <Widget>[];

    for (final slot in widget.freeSlots) {
      final startMinutes = slot.start.isBefore(_startOfDay)
          ? 0
          : slot.start
          .difference(_startOfDay)
          .inMinutes;
      final endMinutes = slot.end.isAfter(
        _startOfDay.add(const Duration(days: 1)),
      )
          ? _minutesInDay
          : slot.end
          .difference(_startOfDay)
          .inMinutes;

      final double top =
          (startMinutes.clamp(0, _minutesInDay)) *
              _pixelsPerMinute;
      final double bottom =
          (endMinutes.clamp(0, _minutesInDay)) *
              _pixelsPerMinute;
      final double height = math.max(bottom - top, 12.0);
      final double constrainedTop = top.clamp(
        0.0,
        math.max(0.0, totalHeight - height),
      ).toDouble();

      widgets.add(
        Positioned(
          top: constrainedTop,
          left: _timeLabelWidth,
          right: 0,
          height: height,
          child: IgnorePointer(
            ignoring: true,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: cs.secondaryContainer
                    .withOpacity(0.18),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildEventWidgets(
      ThemeData theme,
      double totalHeight,
      ) {
    if (widget.events.isEmpty) {
      return <Widget>[
        Positioned.fill(
          child: Center(
            child: Text(
              'Запланируйте новую задачу через кнопку «Новая задача»',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ];
    }

    final List<Widget> widgets = <Widget>[];
    final now = _now;

    // Группируем события по одинаковому интервалу (start + end)
    final Map<String, List<CalendarEvent>> groups = <String, List<CalendarEvent>>{};
    for (final event in widget.events) {
      final key =
          '${event.start.millisecondsSinceEpoch}_${event.end.millisecondsSinceEpoch}';
      groups.putIfAbsent(key, () => <CalendarEvent>[]).add(event);
    }

    for (final slotEvents in groups.values) {
      if (slotEvents.isEmpty) continue;

      final List<CalendarEvent> active = [
        for (final e in slotEvents)
          if (!e.isDone) e,
      ];
      final List<CalendarEvent> done = [
        for (final e in slotEvents)
          if (e.isDone) e,
      ];

      late final CalendarEvent primary;
      late final List<CalendarEvent> foldedDone;

      // Если есть хотя бы одна невыполненная — она становится основной
      if (active.isNotEmpty) {
        active.sort((a, b) => a.start.compareTo(b.start));
        primary = active.first;
        foldedDone = done;
      } else {
        // Все выполнены — показываем первую, остальные свёрнуты
        done.sort((a, b) => a.start.compareTo(b.start));
        primary = done.first;
        foldedDone = done.skip(1).toList();
      }

      final endDate = primary.end;
      final bool isPastByTime = endDate.isBefore(now);

      final startMinutes = primary.start.isBefore(_startOfDay)
          ? 0
          : primary.start.difference(_startOfDay).inMinutes;
      final endMinutes = endDate.isAfter(
        _startOfDay.add(const Duration(days: 1)),
      )
          ? _minutesInDay
          : endDate.difference(_startOfDay).inMinutes;

      final top =
          (startMinutes.clamp(0, _minutesInDay)) * _pixelsPerMinute;
      final bottom =
          (endMinutes.clamp(0, _minutesInDay)) * _pixelsPerMinute;
      final height = math.max(bottom - top, _minEventHeight);
      final double constrainedTop = top.clamp(
        0.0,
        math.max(0.0, totalHeight - height),
      ).toDouble();

      final bool isOngoing =
          primary.start.isBefore(now) && primary.end.isAfter(now);
      final bool isPast = isPastByTime;

      widgets.add(
        Positioned(
          key: ValueKey(
            '${primary.title}_${primary.start.toIso8601String()}',
          ),
          top: constrainedTop,
          left: _timeLabelWidth + 16,
          right: 16,
          height: height,
          child: _EventTile(
            event: primary,
            startLabel: _formatTime(primary.start),
            endLabel: _formatTime(primary.end),
            availableHeight: height,
            isPast: isPast,
            isCurrent: isOngoing,
            foldedDoneEvents: foldedDone,
            onToggleDone: () => widget.onToggleEventDone(primary),
          ),
        ),
      );
    }

    return widgets;
  }
}

class _TimelineGridPainter extends CustomPainter {
  _TimelineGridPainter({
    required this.pixelsPerMinute,
    required this.timeLabelWidth,
    required this.theme,
    required this.textStyle,
  });

  final double pixelsPerMinute;
  final double timeLabelWidth;
  final ThemeData theme;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint hourPaint = Paint()
      ..color = theme.colorScheme.outlineVariant
      ..strokeWidth = 1;
    final Paint minorPaint = Paint()
      ..color = theme.colorScheme.outlineVariant
          .withOpacity(0.4)
      ..strokeWidth = 1;
    final Paint minutePaint = Paint()
      ..color = theme.colorScheme.outlineVariant
          .withOpacity(0.25)
      ..strokeWidth = 1;

    final double startX = timeLabelWidth;
    final double endX = size.width;
    final bool showQuarter = pixelsPerMinute >= 1.2;
    final bool showFiveMinutes = pixelsPerMinute >= 3.0;
    final bool showMinutes = pixelsPerMinute >= 6.0;

    for (int minute = 0;
    minute <= _minutesInDay;
    minute++) {
      final double dy = minute * pixelsPerMinute;
      if (dy > size.height + 1) {
        break;
      }

      if (minute % 60 == 0) {
        canvas.drawLine(
            Offset(startX, dy), Offset(endX, dy), hourPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: _formatMinutes(minute),
            style: textStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: timeLabelWidth - 12);
        textPainter.paint(
          canvas,
          Offset(
            timeLabelWidth - textPainter.width - 12,
            dy - textPainter.height / 2,
          ),
        );
      } else if (showQuarter && minute % 15 == 0) {
        canvas.drawLine(
          Offset(startX + 12, dy),
          Offset(endX, dy),
          minorPaint,
        );
      } else if (showFiveMinutes &&
          minute % 5 == 0) {
        canvas.drawLine(
          Offset(startX + 24, dy),
          Offset(endX, dy),
          minutePaint,
        );
      } else if (showMinutes) {
        canvas.drawLine(
          Offset(startX + 36, dy),
          Offset(endX, dy),
          minutePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
      covariant _TimelineGridPainter oldDelegate,
      ) {
    return oldDelegate.pixelsPerMinute != pixelsPerMinute ||
        oldDelegate.theme != theme ||
        oldDelegate.textStyle != textStyle;
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.startLabel,
    required this.endLabel,
    required this.availableHeight,
    required this.isPast,
    required this.isCurrent,
    required this.onToggleDone,
    this.foldedDoneEvents = const [], // ⬅️ НОВОЕ
  });

  final CalendarEvent event;
  final String startLabel;
  final String endLabel;
  final double availableHeight;
  final bool isPast;
  final bool isCurrent;
  final VoidCallback onToggleDone;
  final List<CalendarEvent> foldedDoneEvents; // ⬅️ НОВОЕ


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const double kTightHeight = 44;
    const double kCompactHeight = 56;
    final bool isUltraCompact = availableHeight < kTightHeight;
    final bool isCompact =
        !isUltraCompact && availableHeight < kCompactHeight;

    // прошедшие ИЛИ выполненные — зачёркнуты
    final bool strikeThrough = event.isDone || isPast;

    final EdgeInsets padding = isUltraCompact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : isCompact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.all(12);

    final titleStyle = (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
      color: cs.onPrimaryContainer,
      fontWeight: FontWeight.w700,
      fontSize: isUltraCompact
          ? 12
          : (isCompact ? 13 : null),
      decoration: strikeThrough
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      decorationThickness: 1.5,
    );

    final labelStyle = (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
      color: cs.onPrimaryContainer.withOpacity(0.8),
      fontSize: isUltraCompact
          ? 10
          : (isCompact ? 11 : null),
    );

    final descStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: cs.onPrimaryContainer.withOpacity(0.75),
    );

    // Логика цвета:
    // - выполнено => зелёный фон
    // - время прошло (но не выполнено) => более бледный синий
    // - остальное => обычный синий
    Color bgColor;
    Color borderColor;
    if (event.isDone) {
      bgColor = Colors.green.shade500.withOpacity(0.86);
      borderColor = Colors.green.shade700.withOpacity(0.85);
    } else if (isPast) {
      bgColor = cs.primaryContainer.withOpacity(0.55);
      borderColor = cs.primary.withOpacity(0.25);
    } else {
      bgColor = cs.primaryContainer.withOpacity(0.85);
      borderColor = cs.primary.withOpacity(0.4);
    }

    final double boxShadowOpacity =
    event.isDone ? 0.04 : (isCurrent ? 0.18 : 0.1);

    return Opacity(
      opacity: isPast ? 0.7 : 1.0, // прошедшие задачи чуть прозрачнее
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: event.isDone ? 1.2 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: cs.primary.withOpacity(boxShadowOpacity),
              blurRadius: isCurrent ? 10 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: isUltraCompact
              ? Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$startLabel — $endLabel',
                style: labelStyle,
              ),
              const SizedBox(width: 4),
              Checkbox(
                value: event.isDone,
                onChanged: (_) => onToggleDone(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    SizedBox(height: isCompact ? 2 : 4),
                    Text(
                      '$startLabel — $endLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle,
                    ),
                    if (!isCompact && event.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: descStyle,
                      ),
                    ],
                    if (foldedDoneEvents.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: cs.onPrimaryContainer.withOpacity(0.9),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              foldedDoneEvents.length == 1
                                  ? 'Ещё 1 выполненная задача'
                                  : 'Ещё ${foldedDoneEvents.length} выполненных задач',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onPrimaryContainer.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: event.isDone,
                onChanged: (_) => onToggleDone(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator({
    required this.label,
    required this.timeLabelWidth,
    required this.color,
  });

  final String label;
  final double timeLabelWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ) ??
            TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            );

    final Color bg =
    theme.colorScheme.surface.withOpacity(0.9);

    return IgnorePointer(
      ignoring: true,
      child: SizedBox(
        height: 1.5,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Линия "сейчас" во всю ширину
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: 1.5,
                  color: color,
                ),
              ),
            ),
            // Подпись времени внутри колонки времени
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: timeLabelWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin:
                    const EdgeInsets.only(right: 4),
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius:
                      BorderRadius.circular(6),
                      border: Border.all(
                        color: color.withOpacity(0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Text(label, style: textStyle),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Месячный календарь с метками статуса дней.
class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.month,
    required this.selectedDay,
    required this.controller,
    required this.onDaySelected,
    required this.onYearChanged,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.isYearPickerOpen,
    required this.onToggleYearPicker,
    required this.yearScrollController,
  });

  final DateTime month;
  final DateTime selectedDay;
  final CalendarController controller;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  final bool isYearPickerOpen;
  final VoidCallback onToggleYearPicker;
  final ScrollController yearScrollController;




  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);

    // Пн = 1 ... Вс = 7 → 0..6, где Пн = 0
    final int firstWeekdayIndex = (firstDayOfMonth.weekday + 6) % 7;
    final totalCells = firstWeekdayIndex + daysInMonth;
    final rowsCount = (totalCells / 7).ceil();

    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(selectedDay);

    const weekdayLabels = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок месяца
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity: VisualDensity.compact,
                onPressed: onPreviousMonth,
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onToggleYearPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _monthName(month.month),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${month.year}',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isYearPickerOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: const Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity: VisualDensity.compact,
                onPressed: onNextMonth,
              ),
            ],
          ),
        ),

        // Календарь + оверлей годов
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // высота оверлея по месту, чтобы не вылезать за низ
              final double overlayMaxHeight =
              math.min(220.0, constraints.maxHeight);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Базовый календарь (дни недели + сетка дней)
                  Column(
                    children: [
                      // Шапка с днями недели
                      Row(
                        children: [
                          for (final label in weekdayLabels)
                            Expanded(
                              child: Center(
                                child: Text(
                                  label,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          children: [
                            for (int row = 0; row < rowsCount; row++)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (int col = 0; col < 7; col++)
                                      Expanded(
                                        child: _buildCell(
                                          context: context,
                                          cs: cs,
                                          textTheme: textTheme,
                                          row: row,
                                          col: col,
                                          firstWeekdayIndex: firstWeekdayIndex,
                                          daysInMonth: daysInMonth,
                                          month: month,
                                          today: today,
                                          selected: selected,
                                          controller: controller,
                                          onDaySelected: onDaySelected,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Оверлей выбор года поверх календаря
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: 0,
                    right: 0,
                    top: isYearPickerOpen ? 0 : -overlayMaxHeight,
                    height: overlayMaxHeight,
                    child: IgnorePointer(
                      ignoring: !isYearPickerOpen,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isYearPickerOpen ? 1.0 : 0.0,
                        curve: Curves.easeOutCubic,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.6),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: GridView.builder(
                              controller: yearScrollController,
                              padding: const EdgeInsets.all(12),
                              physics: const BouncingScrollPhysics(),
                              gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, // 3 года в строке
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.4,
                              ),
                              itemCount: 2100 - 1900 + 1,
                              itemBuilder: (context, index) {
                                const int firstYear = 1900;
                                final int year = firstYear + index;

                                final int currentYear = DateTime.now().year;
                                final bool isSelectedYear = year == month.year;
                                final bool isCurrentYear = year == currentYear;

                                Color borderColor = cs.outlineVariant;
                                Color? background;
                                TextStyle textStyle =
                                    textTheme.bodyMedium ?? const TextStyle(fontSize: 14);

                                // 🌟 Текущий год всегда заметен: лёгкий фон + чуть сильнее бордер
                                if (isCurrentYear) {
                                  borderColor = cs.primary.withOpacity(isSelectedYear ? 1.0 : 0.8);
                                  background = cs.primary.withOpacity(0.10);
                                  textStyle = textStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.primary,
                                  );
                                }

                                // 📌 Выбранный год — самый яркий (перекрывает настройки выше)
                                if (isSelectedYear) {
                                  background = cs.primary.withOpacity(0.18);
                                  borderColor = cs.primary;
                                  textStyle = textStyle.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary,
                                  );
                                }


                                return OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    side: BorderSide(
                                      color: borderColor,
                                      width: isSelectedYear ? 1.4 : 1,
                                    ),
                                    backgroundColor: background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  onPressed: () {
                                    // 1) меняем год
                                    onYearChanged(year);
                                    // 2) сразу скрываем список годов
                                    onToggleYearPicker();
                                  },
                                  child: Text(
                                    '$year',
                                    style: textStyle,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildCell({
    required BuildContext context,
    required ColorScheme cs,
    required TextTheme textTheme,
    required int row,
    required int col,
    required int firstWeekdayIndex,
    required int daysInMonth,
    required DateTime month,
    required DateTime today,
    required DateTime selected,
    required CalendarController controller,
    required ValueChanged<DateTime> onDaySelected,
  }) {
    final index = row * 7 + col;
    final offsetFromFirst = index - firstWeekdayIndex;

    // Дата в ячейке: может быть из прошлого/следующего месяца
    final DateTime cellDate = DateTime(month.year, month.month, 1)
        .add(Duration(days: offsetFromFirst));
    final normalized = DateUtils.dateOnly(cellDate);

    final bool isToday = normalized == today;
    final bool isSelected = normalized == selected;
    final bool isCurrentMonth = cellDate.month == month.month;

    final status = controller.getDayStatus(cellDate);

    Color? dotColor;
    switch (status) {
      case DayMarkerStatus.free:
        dotColor = cs.outlineVariant.withOpacity(0.5);
        break;
      case DayMarkerStatus.hasEvents:
        dotColor = cs.primary;
        break;
      case DayMarkerStatus.hasIncomplete:
        dotColor = cs.error;
        break;
      case DayMarkerStatus.allDone:
        dotColor = Colors.green.shade600;
        break;
    }

    // ⬇️ ДВА базовых фона: текущий месяц / другие месяцы
    Color bg = isCurrentMonth
        ? cs.surfaceVariant.withOpacity(0.30)
        : Colors.transparent;

    Color textColor = isCurrentMonth
        ? cs.onSurfaceVariant
        : cs.onSurfaceVariant.withOpacity(0.7);

    Color borderColor =
    cs.outlineVariant.withOpacity(isCurrentMonth ? 0.7 : 0.4);

    if (isCurrentMonth && isSelected) {
      borderColor = cs.primary;
      textColor = cs.primary;
    } else if (isCurrentMonth && isToday) {
      borderColor = cs.secondary;
      textColor = cs.secondary;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onDaySelected(cellDate),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${cellDate.day}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight:
                  isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    return names[month - 1].replaceFirstMapped(
      RegExp(r'^.'),
          (m) => m.group(0)!.toUpperCase(),
    );
  }
}
