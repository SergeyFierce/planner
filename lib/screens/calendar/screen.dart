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

  final yearPart = date.year.toString();

  if (DateUtils.isSameDay(date, today)) {
    return 'Сегодня · $weekdayName, ${date.day} $monthName $yearPart';
  } else if (DateUtils.isSameDay(date, tomorrow)) {
    return 'Завтра · $weekdayName, ${date.day} $monthName $yearPart';
  } else {
    return '$weekdayName, ${date.day} $monthName $yearPart';
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final CalendarController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final GlobalKey<_CalendarTimelineState> _timelineKey =
      GlobalKey<_CalendarTimelineState>();

  CalendarController get _controller => widget.controller;

  bool _isFreeSlotsExpanded = false;
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

  Future<void> _showMonthPickerSheet() async {
    final selectedDay = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      isScrollControlled: true,
      builder: (context) {
        return _MonthPickerSheet(
          initialMonth: _visibleMonth,
          selectedDay: _controller.day,
          controller: _controller,
        );
      },
    );

    if (selectedDay == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _controller.setDay(selectedDay);
      _visibleMonth = DateTime(selectedDay.year, selectedDay.month, 1);
    });
    _timelineKey.currentState?.scrollTo(selectedDay);
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
    final events = _controller.events;

    final Color appBarColor = theme.colorScheme.surfaceVariant;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: appBarColor,
        toolbarHeight: 76,
        centerTitle: false,
        titleSpacing: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _DateSelectorButton(
              label: _formatFriendlyDate(_controller.day),
              onPressed: _showMonthPickerSheet,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

class _DateSelectorButton extends StatelessWidget {
  const _DateSelectorButton({
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
        backgroundColor: cs.surface.withOpacity(0.35),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: cs.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: cs.onSurface,
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

    final List<CalendarEvent> collapsedEvents = [];
    final List<CalendarEvent> regularEvents = [];

    for (final event in widget.events) {
      if (event.isDone && event.start.isAfter(now)) {
        collapsedEvents.add(event);
      } else {
        regularEvents.add(event);
      }
    }

    List<CalendarEvent> sortByStart(List<CalendarEvent> list) =>
        [...list]..sort((a, b) => a.start.compareTo(b.start));

    for (final event in sortByStart(regularEvents)) {
      final startMinutes = event.start.isBefore(_startOfDay)
          ? 0
          : event.start
              .difference(_startOfDay)
              .inMinutes;
      final endDate = event.end;
      final endMinutes = endDate.isAfter(
        _startOfDay.add(const Duration(days: 1)),
      )
          ? _minutesInDay
          : endDate
              .difference(_startOfDay)
              .inMinutes;

      final top =
          (startMinutes.clamp(0, _minutesInDay)) *
              _pixelsPerMinute;
      final bottom =
          (endMinutes.clamp(0, _minutesInDay)) *
              _pixelsPerMinute;
      final height =
          math.max(bottom - top, _minEventHeight);
      final double constrainedTop = top.clamp(
        0.0,
        math.max(0.0, totalHeight - height),
      ).toDouble();

      final bool isOngoing =
          event.start.isBefore(now) &&
              event.end.isAfter(now);
      final bool isPast = event.end.isBefore(now);

      final eventKey =
          '${event.title}_${event.start.microsecondsSinceEpoch}_${event.duration.inMinutes}';

      widgets.add(
        Positioned(
          key: ValueKey('event_$eventKey'),
          top: constrainedTop,
          left: _timeLabelWidth + 16,
          right: 16,
          height: height,
          child: _EventTile(
            key: ValueKey('tile_$eventKey'),
            event: event,
            startLabel: _formatTime(event.start),
            endLabel: _formatTime(event.end),
            availableHeight: height,
            isPast: isPast,
            isCurrent: isOngoing,
            onToggleDone: () => widget.onToggleEventDone(event),
          ),
        ),
      );
    }

    for (final event in sortByStart(collapsedEvents)) {
      final startMinutes = event.start.isBefore(_startOfDay)
          ? 0
          : event.start
              .difference(_startOfDay)
              .inMinutes;
      final endMinutes = event.end.isAfter(
        _startOfDay.add(const Duration(days: 1)),
      )
          ? _minutesInDay
          : event.end
              .difference(_startOfDay)
              .inMinutes;

      final top =
          (startMinutes.clamp(0, _minutesInDay)) *
              _pixelsPerMinute;
      final bottom =
          (endMinutes.clamp(0, _minutesInDay)) *
              _pixelsPerMinute;
      final double baseHeight =
          math.max(bottom - top, _minEventHeight);
      final double collapsedHeight =
          math.max(32, math.min(baseHeight, 52));
      final double constrainedTop = top.clamp(
        0.0,
        math.max(0.0, totalHeight - collapsedHeight),
      ).toDouble();

      final eventKey =
          '${event.title}_${event.start.microsecondsSinceEpoch}_${event.duration.inMinutes}_collapsed';

      widgets.add(
        Positioned(
          key: ValueKey(eventKey),
          top: constrainedTop,
          left: _timeLabelWidth + 80,
          right: 24,
          height: collapsedHeight,
          child: _CollapsedEventTile(
            key: ValueKey('collapsed_$eventKey'),
            event: event,
            startLabel: _formatTime(event.start),
            endLabel: _formatTime(event.end),
            onToggleDone: () => widget.onToggleEventDone(event),
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
    super.key,
    required this.event,
    required this.startLabel,
    required this.endLabel,
    required this.availableHeight,
    required this.isPast,
    required this.isCurrent,
    required this.onToggleDone,
  });

  final CalendarEvent event;
  final String startLabel;
  final String endLabel;
  final double availableHeight;
  final bool isPast;
  final bool isCurrent;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    const double kTightHeight = 44;
    const double kCompactHeight = 56;
    final bool isUltraCompact = availableHeight < kTightHeight;
    final bool isCompact =
        !isUltraCompact && availableHeight < kCompactHeight;

    final EdgeInsets padding = isUltraCompact
        ? const EdgeInsets.symmetric(
        horizontal: 10, vertical: 6)
        : isCompact
        ? const EdgeInsets.symmetric(
        horizontal: 12, vertical: 8)
        : const EdgeInsets.all(12);

    final bool shouldStrike = event.isDone || isPast;
    final Color baseTextColor = cs.onPrimaryContainer.withOpacity(
      shouldStrike ? 0.75 : 1,
    );

    final titleStyle = (theme.textTheme.titleSmall ??
            const TextStyle())
        .copyWith(
      color: baseTextColor,
      fontWeight: FontWeight.w700,
      fontSize: isUltraCompact
          ? 12
          : (isCompact ? 13 : null),
      decoration: shouldStrike
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      decorationThickness: 1.5,
    );

    final labelStyle = (theme.textTheme.labelMedium ??
            const TextStyle())
        .copyWith(
      color: baseTextColor.withOpacity(0.8),
      fontSize: isUltraCompact
          ? 10
          : (isCompact ? 11 : null),
      decoration: shouldStrike
          ? TextDecoration.lineThrough
          : TextDecoration.none,
    );

    final descStyle = (theme.textTheme.bodySmall ??
            const TextStyle())
        .copyWith(
      color: baseTextColor.withOpacity(0.75),
      decoration: shouldStrike
          ? TextDecoration.lineThrough
          : TextDecoration.none,
    );

    // Логика цвета:
    // - выполнено => зелёный фон
    // - время прошло (но не выполнено) => более бледный синий
    // - остальное => обычный синий
    Color bgColor;
    Color borderColor;
    if (event.isDone) {
      bgColor = Colors.green.shade500.withOpacity(0.86);
      borderColor =
          Colors.green.shade700.withOpacity(0.85);
    } else if (isPast) {
      bgColor = cs.primaryContainer.withOpacity(0.55);
      borderColor = cs.primary.withOpacity(0.25);
    } else {
      bgColor = cs.primaryContainer.withOpacity(0.85);
      borderColor = cs.primary.withOpacity(0.4);
    }

    final boxShadowOpacity =
    event.isDone ? 0.04 : (isCurrent ? 0.18 : 0.1);

    return Opacity(
      opacity: isPast ? 0.75 : 1,
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
            Text('$startLabel — $endLabel',
                style: labelStyle),
            const SizedBox(width: 4),
            Checkbox(
              value: event.isDone,
              onChanged: (_) => onToggleDone(),
              materialTapTargetSize:
              MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        )
            : Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                mainAxisAlignment:
                MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                  SizedBox(
                      height:
                      isCompact ? 2 : 4),
                  Text(
                    '$startLabel — $endLabel',
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                  if (!isCompact &&
                      event.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.description!,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
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
              materialTapTargetSize:
              MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedEventTile extends StatelessWidget {
  const _CollapsedEventTile({
    super.key,
    required this.event,
    required this.startLabel,
    required this.endLabel,
    required this.onToggleDone,
  });

  final CalendarEvent event;
  final String startLabel;
  final String endLabel;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.7),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.lineThrough,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startLabel — $endLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: cs.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Checkbox(
            value: true,
            onChanged: (_) => onToggleDone(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ],
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

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({
    required this.initialMonth,
    required this.selectedDay,
    required this.controller,
  });

  final DateTime initialMonth;
  final DateTime selectedDay;
  final CalendarController controller;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Material(
            color: cs.surface,
            elevation: 12,
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Предыдущий месяц',
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Следующий месяц',
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: _MonthView(
                        month: _visibleMonth,
                        selectedDay: widget.selectedDay,
                        controller: widget.controller,
                        onDaySelected: (date) {
                          Navigator.of(context).pop(date);
                        },
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    this.compact = false,
  });

  final DateTime month;
  final DateTime selectedDay;
  final CalendarController controller;
  final ValueChanged<DateTime> onDaySelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final firstDayOfMonth =
    DateTime(month.year, month.month, 1);
    final daysInMonth =
    DateUtils.getDaysInMonth(month.year, month.month);

    // Пн = 1 ... Вс = 7 → 0..6, где Пн = 0
    final int firstWeekdayIndex =
        (firstDayOfMonth.weekday + 6) % 7;
    final totalCells = firstWeekdayIndex + daysInMonth;
    final rowsCount = (totalCells / 7).ceil();

    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(selectedDay);

    const weekdayLabels = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: Text(
                '${_monthName(month.month)} ${month.year}',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        // Шапка с днями недели
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant
                          .withOpacity(compact ? 0.7 : 1.0),
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
                            firstWeekdayIndex:
                                firstWeekdayIndex,
                            daysInMonth: daysInMonth,
                            month: month,
                            today: today,
                            selected: selected,
                            controller: controller,
                            onDaySelected: onDaySelected,
                            compact: compact,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
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
    required bool compact,
  }) {
    final index = row * 7 + col;
    final dayNumber = index - firstWeekdayIndex + 1;

    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox.shrink();
    }

    final date =
    DateTime(month.year, month.month, dayNumber);
    final normalized = DateUtils.dateOnly(date);
    final isToday = normalized == today;
    final isSelected = normalized == selected;

    final status = controller.getDayStatus(date);

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

    Color? bg;
    Color? border;
    Color textColor = cs.onSurface;
    if (compact) {
      if (isSelected) {
        bg = cs.primary;
        textColor = cs.onPrimary;
      } else if (isToday) {
        bg = cs.secondaryContainer;
        textColor = cs.onSecondaryContainer;
      } else {
        bg = cs.surfaceVariant.withOpacity(0.35);
        border = cs.surfaceVariant.withOpacity(0.2);
      }
    } else {
      if (isSelected) {
        bg = cs.primary.withOpacity(0.12);
        textColor = cs.primary;
      } else if (isToday) {
        bg = cs.secondaryContainer.withOpacity(0.4);
        textColor = cs.onSecondaryContainer;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(compact ? 16 : 12),
      onTap: () => onDaySelected(date),
      child: Padding(
        padding: EdgeInsets.all(compact ? 2 : 4),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(compact ? 16 : 12),
            border:
                border != null ? Border.all(color: border, width: 1) : null,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight:
                  isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: compact ? 8 : 6,
                height: compact ? 8 : 6,
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
