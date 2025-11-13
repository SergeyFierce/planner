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
    return 'Сегодня · $weekdayName, ${date.day} $monthName';
  } else if (DateUtils.isSameDay(date, tomorrow)) {
    return 'Завтра · $weekdayName, ${date.day} $monthName';
  } else {
    return '$weekdayName, ${date.day} $monthName';
  }
}

String _friendlyGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 5) return 'Поздний вечер';
  if (hour < 12) return 'Доброе утро';
  if (hour < 18) return 'Добрый день';
  return 'Добрый вечер';
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

    final overview = _controller.overview;
    final freeSlots = _controller.freeSlots;
    final bestSlot = _controller.bestFocusSlot;

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        titleSpacing: 24,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _friendlyGreeting(now),
              style: textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatFriendlyDate(_controller.day),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DaySummaryCard(
                overview: overview,
                day: _controller.day,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CalendarTimeline(
                  key: _timelineKey,
                  day: _controller.day,
                  events: _controller.events,
                  freeSlots: freeSlots,
                  onAddRequested: _onAddTaskPressed,
                ),
              ),
              const SizedBox(height: 12),
              _FreeSlotsSection(
                freeSlots: freeSlots,
                bestSlot: bestSlot,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
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

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.overview,
    required this.day,
  });

  final DayOverview overview;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cs = theme.colorScheme;

    final totalEvents = overview.totalEvents;
    final busy = overview.busy;
    final free = overview.free;
    final next = overview.nextEvent;

    final hasEvents = totalEvents > 0;
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(day, now);

    String primaryLine;
    if (hasEvents) {
      primaryLine =
      '$totalEvents задач · Занято ${_formatDurationShort(busy)} · Свободно ${_formatDurationShort(free)}';
    } else if (isToday) {
      primaryLine = 'Сегодня пока нет задач';
    } else {
      primaryLine = 'На этот день пока нет задач';
    }

    String secondaryLine;
    IconData secondaryIcon;

    if (isToday && next != null) {
      secondaryIcon = Icons.schedule;
      secondaryLine =
      'Ближайшее сегодня в ${_formatTime(next.start)} — ${next.title}';
    } else if (isToday && hasEvents && next == null) {
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
                Text(
                  primaryLine,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      secondaryIcon,
                      size: 18,
                      color: cs.onPrimaryContainer.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        secondaryLine,
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
  });

  final List<FreeSlot> freeSlots;
  final FreeSlot? bestSlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (freeSlots.isEmpty) {
      return Text(
        'Свободных окон почти нет — берегите себя и оставьте время на отдых.',
        style: textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Свободное время',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
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
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final List<FreeSlot> freeSlots;
  final VoidCallback onAddRequested;

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
    // Учитываем верхний паддинг, чтобы позиционирование было точнее
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

    // Контент теперь: высота дня + паддинги сверху/снизу
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
                    final viewport = notification.metrics.viewportDimension;
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
                    // Важное место: добавляем паддинги сверху/снизу,
                    // чтобы 00:00 и конец дня не обрезались.
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
                          // Индикатор "сейчас" — СЛОЙ МЕЖДУ сеткой/фоном и карточками
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

    final List<Widget> widgets = <Widget>[];
    for (final event in widget.events) {
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

      widgets.add(
        Positioned(
          top: constrainedTop,
          left: _timeLabelWidth + 16,
          right: 16,
          height: height,
          child: _EventTile(
            event: event,
            startLabel: _formatTime(event.start),
            endLabel: _formatTime(event.end),
            availableHeight: height,
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
  });

  final CalendarEvent event;
  final String startLabel;
  final String endLabel;
  final double availableHeight;

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

    final titleStyle = (theme.textTheme.titleSmall ?? const TextStyle())
        .copyWith(
      color: cs.onPrimaryContainer,
      fontWeight: FontWeight.w700,
      fontSize: isUltraCompact
          ? 12
          : (isCompact ? 13 : null),
    );

    final labelStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(
      color: cs.onPrimaryContainer.withOpacity(0.8),
      fontSize: isUltraCompact
          ? 10
          : (isCompact ? 11 : null),
    );

    final descStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(
      color: cs.onPrimaryContainer.withOpacity(0.75),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.4), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.primary.withOpacity(0.1),
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
          ],
        )
            : Column(
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
          ],
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
    final textStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ) ??
            TextStyle(color: color, fontWeight: FontWeight.w700);

    return IgnorePointer(
      ignoring: true,
      child: Row(
        children: <Widget>[
          // Чип с текущим временем в колонке времени
          SizedBox(
            width: timeLabelWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label, style: textStyle),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Точка-гайдер на границе между шкалой и задачами
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Линия только в области задач, с лёгким градиентом
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

