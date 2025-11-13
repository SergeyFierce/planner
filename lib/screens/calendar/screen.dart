import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'controller.dart';

const int _minutesInDay = 24 * 60;

const List<String> _weekdayNames = <String>[
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const List<String> _weekdayShortNames = <String>[
  'Пн',
  'Вт',
  'Ср',
  'Чт',
  'Пт',
  'Сб',
  'Вс',
];

const List<String> _monthNames = <String>[
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

const List<String> _monthNamesTitle = <String>[
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

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
  final weekdayName = _weekdayNames[date.weekday - 1];
  final monthName = _monthNames[date.month - 1];

  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));

  if (DateUtils.isSameDay(date, today)) {
    return 'Сегодня $weekdayName, ${date.day} $monthName ${date.year}';
  } else if (DateUtils.isSameDay(date, tomorrow)) {
    return 'Завтра $weekdayName, ${date.day} $monthName ${date.year}';
  } else {
    return '$weekdayName, ${date.day} $monthName ${date.year}';
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final CalendarController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late GlobalKey<_CalendarTimelineState> _timelineKey;

  CalendarController get _controller => widget.controller;

  bool _isFreeSlotsExpanded = false; // Свободное время — по умолчанию свёрнуто

  @override
  void initState() {
    super.initState();
    _timelineKey = GlobalKey<_CalendarTimelineState>();
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

  Future<void> _openCalendarSheet() async {
    final selectedDate = await showGeneralDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Выбор даты',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CalendarTopSheet(
          initialDay: _controller.day,
          hasEvents: _controller.hasEventsOn,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _controller.changeDay(selectedDate);
      _timelineKey = GlobalKey<_CalendarTimelineState>();
    });
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

    final overview = _controller.overview;
    final freeSlots = _controller.freeSlots;
    final bestSlot = _controller.bestFocusSlot;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 24,
        toolbarHeight: 92,
        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.95),
        surfaceTintColor: Colors.transparent,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        title: _DateSelectionButton(
          label: _formatFriendlyDate(_controller.day),
          onPressed: _openCalendarSheet,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DaySummaryCard(
                overview: overview,
                day: _controller.day,
                events: _controller.events, // ***
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CalendarTimeline(
                  key: _timelineKey,
                  day: _controller.day,
                  events: _controller.events,
                  freeSlots: freeSlots,
                  onAddRequested: _onAddTaskPressed,
                  onToggleEventDone: (event) { // ***
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

class _DateSelectionButton extends StatelessWidget {
  const _DateSelectionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: cs.primary.withOpacity(0.12),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.expand_more_rounded,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.overview,
    required this.day,
    required this.events, // ***
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

    // Прогресс: выполнено / всего
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

    // Вторая строка: текущая + следующая
    String secondaryLine;
    IconData secondaryIcon;

    if (isToday && currentEvent != null) {
      secondaryIcon = Icons.play_arrow_rounded;
      if (upcomingEvent != null) {
        secondaryLine =
        'Сейчас: ${currentEvent.title} до ${_formatTime(currentEvent.end)}. '
            'Далее: ${upcomingEvent.title} в ${_formatTime(upcomingEvent.start)}';
      } else {
        secondaryLine =
        'Сейчас: ${currentEvent.title} до ${_formatTime(currentEvent.end)}';
      }
    } else if (isToday && currentEvent == null && upcomingEvent != null) {
      secondaryIcon = Icons.schedule;
      secondaryLine =
      'Следующее сегодня в ${_formatTime(upcomingEvent.start)} — ${upcomingEvent.title}';
    } else if (isToday && hasEvents && currentEvent == null && upcomingEvent == null) {
      secondaryIcon = Icons.check_circle;
      secondaryLine = 'Все задачи на сегодня уже позади';
    } else if (!isToday && hasEvents) {
      secondaryIcon = Icons.calendar_month;
      secondaryLine = 'План на этот день уже составлен';
    } else {
      secondaryIcon = Icons.auto_awesome;
      secondaryLine =
      'Запланируйте хотя бы одну задачу — я помогу всё разложить по времени';
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
                          color: cs.onPrimaryContainer.withOpacity(0.9),
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
                          color: cs.onPrimaryContainer.withOpacity(0.9),
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
                // Вторая строка — текущее/следующее событие
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 28,
                        child: Center(
                          child: Icon(
                            secondaryIcon,
                            size: 18,
                            color: cs.onPrimaryContainer.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            secondaryLine,
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer.withOpacity(0.9),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
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

    return Container( // *** карточка
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
                          style: textTheme.bodySmall?.copyWith(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            color: highlighted ? cs.primary : cs.onSurfaceVariant,
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
    required this.onToggleEventDone, // ***
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final List<FreeSlot> freeSlots;
  final VoidCallback onAddRequested;
  final ValueChanged<CalendarEvent> onToggleEventDone; // ***

  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline> {
  static const double _timeLabelWidth = 74;
  static const double _pixelsPerMinute = 1.2; // фиксированный масштаб
  static const double _minEventHeight = 28;
  static const double _scrollEdgePadding = 24.0; // отступы сверху/снизу

  late final ScrollController _scrollController;
  double _viewportHeight = 0;

  DateTime _now = DateTime.now();
  Timer? _timer;

  DateTime get _startOfDay =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
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
    final double clamped = target.clamp(0.0, maxOffset).toDouble();

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

  double get _dayHeight => _minutesInDay * _pixelsPerMinute;

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
    final showCurrentTime = DateUtils.isSameDay(_now, widget.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) {
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
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: SizedBox(
                      height: totalHeight,
                      child: Stack(
                        children: <Widget>[
                          // Сетка времени
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TimelineGridPainter(
                                pixelsPerMinute: _pixelsPerMinute,
                                timeLabelWidth: _timeLabelWidth,
                                theme: theme,
                                textStyle: theme.textTheme.bodySmall ??
                                    const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          // Фон для свободных интервалов
                          ..._buildFreeSlotBackgrounds(theme, totalHeight),
                          // Индикатор "сейчас" между цифрами и лентой
                          if (showCurrentTime)
                            Positioned(
                              top: _offsetFor(_now),
                              left: 0,
                              right: 0,
                              child: _CurrentTimeIndicator(
                                label: _formatTime(_now),
                                timeLabelWidth: _timeLabelWidth,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          // Карточки событий поверх всего
                          ..._buildEventWidgets(theme, totalHeight),
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
          : slot.start.difference(_startOfDay).inMinutes;
      final endMinutes =
      slot.end.isAfter(_startOfDay.add(const Duration(days: 1)))
          ? _minutesInDay
          : slot.end.difference(_startOfDay).inMinutes;

      final double top =
          (startMinutes.clamp(0, _minutesInDay)) * _pixelsPerMinute;
      final double bottom =
          (endMinutes.clamp(0, _minutesInDay)) * _pixelsPerMinute;
      final double height = math.max(bottom - top, 12.0);
      final double constrainedTop =
      top.clamp(0.0, math.max(0.0, totalHeight - height)).toDouble();

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
                color: cs.secondaryContainer.withOpacity(0.18),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildEventWidgets(ThemeData theme, double totalHeight) {
    if (widget.events.isEmpty) {
      return <Widget>[
        Positioned.fill(
          child: Center(
            child: Text(
              'Запланируйте новую задачу через кнопку «Новая задача»',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ];
    }

    final List<CalendarEvent> orderedEvents = <CalendarEvent>[...widget.events]
      ..sort((a, b) {
        final cmp = a.start.compareTo(b.start);
        if (cmp != 0) return cmp;
        if (a.isDone == b.isDone) return 0;
        return a.isDone ? 1 : -1;
      });

    final now = DateTime.now();
    final List<Widget> widgets = <Widget>[];
    for (final event in orderedEvents) {
      final startMinutes = event.start.isBefore(_startOfDay)
          ? 0
          : event.start.difference(_startOfDay).inMinutes;
      final endDate = event.end;
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
      final double constrainedTop =
      top.clamp(0.0, math.max(0.0, totalHeight - height)).toDouble();

      final bool isPast = event.end.isBefore(now);
      final bool collapsedFutureDone =
          event.isDone && event.start.isAfter(now);
      final double effectiveHeight =
          collapsedFutureDone ? _minEventHeight : height;
      final double topOffset =
          collapsedFutureDone ? constrainedTop + 4 : constrainedTop;
      final double leftInset =
          _timeLabelWidth + (collapsedFutureDone ? 48 : 16);
      final double rightInset = collapsedFutureDone ? 72 : 16;

      widgets.add(
        Positioned(
          key: ObjectKey(event),
          top: topOffset,
          left: leftInset,
          right: rightInset,
          height: effectiveHeight,
          child: _EventTile(
            event: event,
            startLabel: _formatTime(event.start),
            endLabel: _formatTime(event.end),
            availableHeight: effectiveHeight,
            isPast: isPast,
            isCollapsed: collapsedFutureDone,
            onToggleDone: () => widget.onToggleEventDone(event), // ***
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
      ..color = theme.colorScheme.outlineVariant.withOpacity(0.4)
      ..strokeWidth = 1;
    final Paint minutePaint = Paint()
      ..color = theme.colorScheme.outlineVariant.withOpacity(0.25)
      ..strokeWidth = 1;

    final double startX = timeLabelWidth;
    final double endX = size.width;
    final bool showQuarter = pixelsPerMinute >= 1.2;
    final bool showFiveMinutes = pixelsPerMinute >= 3.0;
    final bool showMinutes = pixelsPerMinute >= 6.0;

    for (int minute = 0; minute <= _minutesInDay; minute++) {
      final double dy = minute * pixelsPerMinute;
      if (dy > size.height + 1) {
        break;
      }

      if (minute % 60 == 0) {
        canvas.drawLine(Offset(startX, dy), Offset(endX, dy), hourPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: _formatMinutes(minute),
            style: textStyle.copyWith(fontWeight: FontWeight.w600),
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
      } else if (showFiveMinutes && minute % 5 == 0) {
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
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) {
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
    this.isCollapsed = false,
    required this.onToggleDone, // ***
  });

  final CalendarEvent event;
  final String startLabel;
  final String endLabel;
  final double availableHeight;
  final bool isPast;
  final bool isCollapsed;
  final VoidCallback onToggleDone; // ***

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const double kTightHeight = 44; // ультра-компактный
    const double kCompactHeight = 56; // компактный
    final bool isUltraCompact = availableHeight < kTightHeight;
    final bool isCompact =
        !isUltraCompact && availableHeight < kCompactHeight;

    final EdgeInsets padding = isUltraCompact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : isCompact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.all(12);

    final bool strikeThrough = event.isDone || isPast;
    final titleStyle = (theme.textTheme.titleSmall ?? const TextStyle())
        .copyWith(
      color: cs.onPrimaryContainer,
      fontWeight: FontWeight.w700,
      fontSize: isUltraCompact ? 12 : (isCompact ? 13 : null),
      decoration: strikeThrough ? TextDecoration.lineThrough : TextDecoration.none,
      decorationThickness: 1.5,
    );

    final labelStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(
      color: cs.onPrimaryContainer.withOpacity(0.8),
      fontSize: isUltraCompact ? 10 : (isCompact ? 11 : null),
    );

    final descStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(
      color: cs.onPrimaryContainer.withOpacity(0.75),
    );

    final Color bgColor = isCollapsed
        ? cs.surfaceVariant.withOpacity(0.85)
        : event.isDone
            ? cs.primaryContainer.withOpacity(0.55)
            : cs.primaryContainer.withOpacity(0.85);

    final double opacity = isPast ? 0.65 : 1.0;

    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.primary.withOpacity(event.isDone ? 0.25 : 0.4),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: cs.primary.withOpacity(event.isDone ? 0.04 : 0.1),
              blurRadius: 8,
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
                    Text('$startLabel — $endLabel', style: labelStyle),
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
                          if (!isCompact &&
                              event.description != null &&
                              !isCollapsed)
                            ...[
                              const SizedBox(height: 4),
                              Text(
                                event.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: descStyle,
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
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    ) ??
        TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        );

    final Color bg = theme.colorScheme.surface.withOpacity(0.9);

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
            // Подпись времени внутри колонки времени, прижата к правому краю
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: timeLabelWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
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

class _CalendarTopSheet extends StatefulWidget {
  const _CalendarTopSheet({
    required this.initialDay,
    required this.hasEvents,
  });

  final DateTime initialDay;
  final bool Function(DateTime day) hasEvents;

  @override
  State<_CalendarTopSheet> createState() => _CalendarTopSheetState();
}

class _CalendarTopSheetState extends State<_CalendarTopSheet> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialDay.year, widget.initialDay.month);
    _selectedDay = widget.initialDay;
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      );
    });
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
    Navigator.of(context).pop(day);
  }

  List<DateTime?> _buildGridDays() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final int daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final int leadingEmpty = (firstDay.weekday + 6) % 7;
    final int totalCells = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;

    return List<DateTime?>.generate(totalCells, (int index) {
      final int dayNumber = index - leadingEmpty + 1;
      if (dayNumber < 1 || dayNumber > daysInMonth) {
        return null;
      }
      return DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final List<DateTime?> days = _buildGridDays();
    final String monthLabel =
        '${_monthNamesTitle[_visibleMonth.month - 1]} ${_visibleMonth.year}';

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _changeMonth(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  monthLabel,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatFriendlyDate(_selectedDay),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeMonth(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List<Widget>.generate(
                          _weekdayShortNames.length,
                          (int index) {
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Center(
                                  child: Text(
                                    _weekdayShortNames[index],
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: days.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final DateTime? day = days[index];
                          if (day == null) {
                            return const SizedBox.shrink();
                          }
                          final bool isSelected =
                              DateUtils.isSameDay(day, _selectedDay);
                          final bool isToday =
                              DateUtils.isSameDay(day, DateTime.now());
                          final bool hasEvents = widget.hasEvents(day);
                          final Color backgroundColor = isSelected
                              ? cs.primary
                              : cs.surfaceVariant.withOpacity(0.4);
                          final Color textColor = isSelected
                              ? cs.onPrimary
                              : cs.onSurface;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _onDaySelected(day),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isToday && !isSelected
                                        ? cs.primary.withOpacity(0.7)
                                        : Colors.transparent,
                                    width: 1.4,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      '${day.day}',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (hasEvents)
                                      Positioned(
                                        bottom: 8,
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? cs.onPrimary
                                                : cs.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
