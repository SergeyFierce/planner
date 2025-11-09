import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final CalendarController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late List<CalendarEvent> _events;
  final GlobalKey<_CalendarTimelineState> _timelineKey = GlobalKey<_CalendarTimelineState>();

  @override
  void initState() {
    super.initState();
    _events = [...widget.controller.events];
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _events = [...widget.controller.events];
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
      widget.controller.day.year,
      widget.controller.day.month,
      widget.controller.day.day,
      picked.hour,
      picked.minute,
    );
    final snapped = _snapToInterval(selectedDate, minutes: 5);
    final newEvent = CalendarEvent(
      title: 'Новая задача',
      start: snapped,
      duration: const Duration(minutes: 30),
    );

    setState(() {
      _events = [..._events, newEvent]
        ..sort((a, b) => a.start.compareTo(b.start));
    });

    _timelineKey.currentState?.scrollTo(snapped);

    final timeRange = '${_formatTime(snapped)} – ${_formatTime(newEvent.end)}';
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.controller.headline,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(widget.controller.description, style: textTheme.bodyMedium),
          const SizedBox(height: 24),
          Expanded(
            child: CalendarTimeline(
              key: _timelineKey,
              day: widget.controller.day,
              events: _events,
              onAddRequested: _onAddTaskPressed,
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
    required this.onAddRequested,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final VoidCallback onAddRequested;

  @override
  State<CalendarTimeline> createState() => _CalendarTimelineState();
}

class _CalendarTimelineState extends State<CalendarTimeline> {
  static const double _timeLabelWidth = 74;
  static const double _minPixelsPerMinute = 0.35;
  static const double _maxPixelsPerMinute = 8.0;
  static const double _minEventHeight = 28;
  static const List<_ZoomLevel> _zoomLevels = <_ZoomLevel>[
    _ZoomLevel('День', 0.35),
    _ZoomLevel('6 часов', 0.6),
    _ZoomLevel('3 часа', 0.95),
    _ZoomLevel('Час', 1.6),
    _ZoomLevel('30 мин', 2.4),
    _ZoomLevel('10 мин', 4.2),
    _ZoomLevel('1 мин', 7.5),
  ];

  late final ScrollController _scrollController;
  double _pixelsPerMinute = 1.2;
  double _scaleStartPixelsPerMinute = 1.2;
  double _viewportHeight = 0;
  DateTime _now = DateTime.now();
  Timer? _timer;

  DateTime get _startOfDay => DateTime(widget.day.year, widget.day.month, widget.day.day);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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
    final offset = _offsetFor(time) - _viewportHeight / 3;
    _animateTo(offset);
  }

  void _scrollToInitialPosition() {
    if (!DateUtils.isSameDay(_now, widget.day)) {
      return;
    }
    if (_viewportHeight == 0 || !_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitialPosition());
      return;
    }
    final offset = _offsetFor(_now) - _viewportHeight / 2;
    _animateTo(offset, jump: true);
  }

  void _animateTo(double target, {bool jump = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final maxOffset = math.max(0, _dayHeight - _viewportHeight);
    final clamped = target.clamp(0.0, maxOffset);
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
    final diff = time.difference(_startOfDay).inMinutes;
    final clampedMinutes = diff.clamp(0, _minutesInDay);
    return clampedMinutes * _pixelsPerMinute;
  }

  int get _currentZoomIndex {
    int closestIndex = 0;
    double closestDiff = double.infinity;
    for (var i = 0; i < _zoomLevels.length; i++) {
      final diff = (_zoomLevels[i].pixelsPerMinute - _pixelsPerMinute).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  void _zoomIn() {
    final nextIndex = (_currentZoomIndex + 1).clamp(0, _zoomLevels.length - 1);
    _setZoom(_zoomLevels[nextIndex].pixelsPerMinute);
  }

  void _zoomOut() {
    final nextIndex = (_currentZoomIndex - 1).clamp(0, _zoomLevels.length - 1);
    _setZoom(_zoomLevels[nextIndex].pixelsPerMinute);
  }

  void _setZoom(double newPixelsPerMinute, {double? focalPoint}) {
    final clamped = newPixelsPerMinute.clamp(_minPixelsPerMinute, _maxPixelsPerMinute);
    if ((clamped - _pixelsPerMinute).abs() < 0.001) {
      return;
    }

    final totalBefore = _dayHeight;
    setState(() {
      _pixelsPerMinute = clamped;
    });

    if (!_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final totalAfter = _dayHeight;
      final focus = focalPoint ?? (_viewportHeight / 2);
      final focusRatio = totalBefore == 0
          ? 0.0
          : (_scrollController.offset + focus).clamp(0.0, totalBefore) / totalBefore;
      final desiredOffset = (totalAfter * focusRatio) - focus;
      final maxOffset = math.max(0, totalAfter - _viewportHeight);
      _scrollController.jumpTo(desiredOffset.clamp(0.0, maxOffset));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalHeight = _dayHeight;
    final showCurrentTime = DateUtils.isSameDay(_now, widget.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TimelineControls(
          zoomLevels: _zoomLevels,
          selectedPixelsPerMinute: _pixelsPerMinute,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onLevelSelected: (level) => _setZoom(level.pixelsPerMinute),
          onAddPressed: widget.onAddRequested,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  _scaleStartPixelsPerMinute = _pixelsPerMinute;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount < 2) {
                    return;
                  }
                  final renderBox = context.findRenderObject();
                  if (renderBox is! RenderBox) {
                    return;
                  }
                  final localFocal = renderBox.globalToLocal(details.focalPoint).dy;
                  _setZoom(_scaleStartPixelsPerMinute * details.scale, focalPoint: localFocal);
                },
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
                    child: SizedBox(
                      height: totalHeight,
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _TimelineGridPainter(
                                pixelsPerMinute: _pixelsPerMinute,
                                timeLabelWidth: _timeLabelWidth,
                                theme: theme,
                                textStyle: theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          ..._buildEventWidgets(theme, totalHeight),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MiniMap(
          day: widget.day,
          events: widget.events,
          totalHeight: totalHeight,
          pixelsPerMinute: _pixelsPerMinute,
          scrollOffset: _scrollController.hasClients ? _scrollController.offset : 0.0,
          viewportHeight: _viewportHeight,
          onTap: (ratio) {
            final target = ratio * totalHeight - _viewportHeight / 2;
            _animateTo(target);
          },
        ),
      ],
    );
  }

  List<Widget> _buildEventWidgets(ThemeData theme, double totalHeight) {
    if (widget.events.isEmpty) {
      return <Widget>[
        Positioned.fill(
          child: Center(
            child: Text(
              'Запланируйте новую задачу через кнопку «+»',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
      final endMinutes = endDate.isAfter(_startOfDay.add(const Duration(days: 1)))
          ? _minutesInDay
          : endDate.difference(_startOfDay).inMinutes;

      final top = (startMinutes.clamp(0, _minutesInDay)) * _pixelsPerMinute;
      final bottom = (endMinutes.clamp(0, _minutesInDay)) * _pixelsPerMinute;
      final height = math.max(bottom - top, _minEventHeight);
      final constrainedTop = top.clamp(0.0, math.max(0.0, totalHeight - height));

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
          ),
        ),
      );
    }

    return widgets;
  }
}

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({
    required this.zoomLevels,
    required this.selectedPixelsPerMinute,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLevelSelected,
    required this.onAddPressed,
  });

  final List<_ZoomLevel> zoomLevels;
  final double selectedPixelsPerMinute;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final ValueChanged<_ZoomLevel> onLevelSelected;
  final VoidCallback onAddPressed;

  _ZoomLevel get _selectedLevel {
    return zoomLevels.reduce((current, next) =>
        (current.pixelsPerMinute - selectedPixelsPerMinute).abs() <
                (next.pixelsPerMinute - selectedPixelsPerMinute).abs()
            ? current
            : next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        FilledButton.icon(
          onPressed: onAddPressed,
          icon: const Icon(Icons.add),
          label: const Text('Задача'),
        ),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: onZoomOut,
          icon: const Icon(Icons.remove),
          tooltip: 'Уменьшить масштаб',
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
          ),
          child: DropdownButton<_ZoomLevel>(
            value: _selectedLevel,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            focusColor: Colors.transparent,
            onChanged: (level) {
              if (level != null) {
                onLevelSelected(level);
              }
            },
            items: zoomLevels
                .map(
                  (level) => DropdownMenuItem<_ZoomLevel>(
                    value: level,
                    child: Text(level.label),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onZoomIn,
          icon: const Icon(Icons.add),
          tooltip: 'Увеличить масштаб',
        ),
      ],
    );
  }
}

class _ZoomLevel {
  const _ZoomLevel(this.label, this.pixelsPerMinute);

  final String label;
  final double pixelsPerMinute;
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
        )
          ..layout(maxWidth: timeLabelWidth - 12);
        textPainter.paint(
          canvas,
          Offset(timeLabelWidth - textPainter.width - 12, dy - textPainter.height / 2),
        );
      } else if (showQuarter && minute % 15 == 0) {
        canvas.drawLine(Offset(startX + 12, dy), Offset(endX, dy), minorPaint);
      } else if (showFiveMinutes && minute % 5 == 0) {
        canvas.drawLine(Offset(startX + 24, dy), Offset(endX, dy), minutePaint);
      } else if (showMinutes) {
        canvas.drawLine(Offset(startX + 36, dy), Offset(endX, dy), minutePaint);
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
  });

  final CalendarEvent event;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.4), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$startLabel — $endLabel',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
            if (event.description != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                event.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withOpacity(0.75),
                ),
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
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(color: color, fontWeight: FontWeight.w700);

    return IgnorePointer(
      ignoring: true,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: timeLabelWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(label, style: textStyle),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.day,
    required this.events,
    required this.totalHeight,
    required this.pixelsPerMinute,
    required this.scrollOffset,
    required this.viewportHeight,
    required this.onTap,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final double totalHeight;
  final double pixelsPerMinute;
  final double scrollOffset;
  final double viewportHeight;
  final ValueChanged<double> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewStart = totalHeight <= 0 ? 0.0 : (scrollOffset / totalHeight).clamp(0.0, 1.0);
        final viewEnd = totalHeight <= 0
            ? 0.0
            : ((scrollOffset + viewportHeight) / totalHeight).clamp(0.0, 1.0);
        final highlightWidth = (viewEnd - viewStart).clamp(0.05, 1.0) * width;

        return GestureDetector(
          onTapDown: (details) {
            if (width == 0) {
              return;
            }
            final ratio = (details.localPosition.dx / width).clamp(0.0, 1.0);
            onTap(ratio);
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MiniMapPainter(
                      day: day,
                      events: events,
                      colorScheme: theme.colorScheme,
                    ),
                  ),
                ),
                Positioned(
                  left: viewStart * width,
                  width: highlightWidth.isFinite ? highlightWidth : 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.primary, width: 2),
                        color: theme.colorScheme.primary.withOpacity(0.08),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.day,
    required this.events,
    required this.colorScheme,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          colorScheme.surfaceVariant.withOpacity(0.5),
          colorScheme.surfaceVariant.withOpacity(0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    if (events.isEmpty) {
      return;
    }

    final double minuteWidth = size.width / _minutesInDay;
    final RRect baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.clipRRect(baseRect);

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final startOfDay = DateTime(day.year, day.month, day.day);
      final startMinutes = event.start.isBefore(startOfDay)
          ? 0
          : event.start.difference(startOfDay).inMinutes;
      final endMinutes = event.end.isAfter(startOfDay.add(const Duration(days: 1)))
          ? _minutesInDay
          : event.end.difference(startOfDay).inMinutes;

      final double left = startMinutes * minuteWidth;
      final double width = math.max((endMinutes - startMinutes) * minuteWidth, 2);
      final double top = size.height * 0.2;
      final double height = size.height * 0.6;

      final color = Color.lerp(
        colorScheme.primary.withOpacity(0.65),
        colorScheme.tertiary.withOpacity(0.65),
        (i % 4) / 3,
      );

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        const Radius.circular(6),
      );

      canvas.drawRRect(rect, Paint()..color = color ?? colorScheme.primary.withOpacity(0.6));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return !listEquals(oldDelegate.events, events) || oldDelegate.colorScheme != colorScheme;
  }
}
