import 'package:flutter/material.dart';

/// Модель одного события календаря.
class CalendarEvent {
  CalendarEvent({
    required this.title,
    required this.start,
    required this.duration,
    this.description,
    this.isDone = false,
  });

  final String title;
  final DateTime start;
  final Duration duration;
  final String? description;

  /// Флаг выполнения задачи
  bool isDone;

  DateTime get end => start.add(duration);
}

/// Свободный промежуток между событиями.
class FreeSlot {
  const FreeSlot({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// Сводка по дню: сколько задач, сколько занято/свободно, ближайшее событие.
class DayOverview {
  const DayOverview({
    required this.totalEvents,
    required this.busy,
    required this.free,
    required this.firstEvent,
    required this.lastEvent,
    required this.nextEvent,
  });

  final int totalEvents;
  final Duration busy;
  final Duration free;
  final CalendarEvent? firstEvent;
  final CalendarEvent? lastEvent;
  final CalendarEvent? nextEvent;
}

/// Статус дня для месячного календаря.
enum DayMarkerStatus {
  free,          // день свободен
  hasEvents,     // есть дела в этот день (будущее / сегодня)
  hasIncomplete, // есть невыполненные дела (в прошлом / сегодня)
  allDone,       // все дела выполнены
}

DateTime _normalizeDate(DateTime d) => DateUtils.dateOnly(d);

class CalendarController {
  CalendarController({
    DateTime? day,
    List<CalendarEvent>? events,
  })  : _currentDay = _normalizeDate(day ?? DateTime.now()),
        _eventsByDay = <DateTime, List<CalendarEvent>>{} {
    final initial = _currentDay;
    _eventsByDay[initial] = List<CalendarEvent>.from(
      events ?? _createSampleEvents(initial),
    )..sort((a, b) => a.start.compareTo(b.start));
  }

  DateTime _currentDay;
  final Map<DateTime, List<CalendarEvent>> _eventsByDay;

  DateTime get day => _currentDay;

  String get headline => 'Календарь';
  String get description =>
      'Планируйте свои события и отслеживайте ближайшие задачи.';

  List<CalendarEvent> get _currentEvents =>
      _eventsByDay[_currentDay] ?? const <CalendarEvent>[];

  /// Все события выбранного дня (read-only).
  List<CalendarEvent> get events => List.unmodifiable(_currentEvents);

  /// Завершённые события выбранного дня.
  List<CalendarEvent> get completedEvents =>
      _currentEvents.where((e) => e.isDone).toList(growable: false);

  /// События произвольного дня.
  List<CalendarEvent> eventsForDay(DateTime date) {
    final key = _normalizeDate(date);
    final list = _eventsByDay[key];
    if (list == null) return const <CalendarEvent>[];
    return List.unmodifiable(list);
  }

  /// Свободные промежутки внутри дня (учитываются только НЕвыполненные события).
  List<FreeSlot> get freeSlots => _computeFreeSlots();

  /// Самое длительное свободное окно — лучшее для фокусной работы.
  FreeSlot? get bestFocusSlot {
    final slots = freeSlots;
    if (slots.isEmpty) return null;
    FreeSlot best = slots.first;
    for (final slot in slots.skip(1)) {
      if (slot.duration > best.duration) {
        best = slot;
      }
    }
    return best;
  }

  /// Сводка по дню: сколько задач, сколько занято/свободно, ближайшее событие.
  DayOverview get overview => _buildOverview();

  /// Переключить текущий день (используется в месячном календаре).
  void setDay(DateTime newDay) {
    final normalized = _normalizeDate(newDay);
    _currentDay = normalized;
    _eventsByDay.putIfAbsent(
      normalized,
          () => _createSampleEvents(normalized),
    );
    _eventsByDay[normalized]!
        .sort((a, b) => a.start.compareTo(b.start));
  }

  /// Удобный метод — создать и сразу добавить событие.
  CalendarEvent createEvent({
    required String title,
    required DateTime start,
    Duration duration = const Duration(minutes: 30),
    String? description,
  }) {
    final event = CalendarEvent(
      title: title,
      start: start,
      duration: duration,
      description: description,
    );
    addEvent(event);
    return event;
  }

  /// Добавить событие в соответствующий день.
  void addEvent(CalendarEvent event) {
    final key = _normalizeDate(event.start);
    final list = _eventsByDay.putIfAbsent(key, () => <CalendarEvent>[]);
    list.add(event);
    list.sort((a, b) => a.start.compareTo(b.start));
  }

  /// Отметить / снять отметку «выполнено» у события.
  void toggleEventCompletion(CalendarEvent event) {
    event.isDone = !event.isDone;
  }

  /// Статус произвольного дня для месячного календаря.
  DayMarkerStatus getDayStatus(DateTime date) {
    final key = _normalizeDate(date);
    final list = _eventsByDay[key];
    if (list == null || list.isEmpty) {
      return DayMarkerStatus.free;
    }

    final hasDone = list.any((e) => e.isDone);
    final hasIncomplete = list.any((e) => !e.isDone);

    if (!hasIncomplete && hasDone) {
      // Все завершены
      return DayMarkerStatus.allDone;
    }

    final today = _normalizeDate(DateTime.now());
    if (key.isBefore(today) && hasIncomplete) {
      // В прошлом и есть невыполненные
      return DayMarkerStatus.hasIncomplete;
    }

    // Сегодня или в будущем: просто «есть дела»
    return DayMarkerStatus.hasEvents;
  }

  List<FreeSlot> _computeFreeSlots() {
    final DateTime startOfDay =
    DateTime(day.year, day.month, day.day);
    final DateTime endOfDay =
    startOfDay.add(const Duration(days: 1));

    // Учитываем только НЕвыполненные события — выполненные освобождают время.
    final List<CalendarEvent> activeEvents = _currentEvents
        .where((e) => !e.isDone)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    // Если вообще нет активных событий — весь день свободен.
    if (activeEvents.isEmpty) {
      return [
        FreeSlot(start: startOfDay, end: endOfDay),
      ];
    }

    const int minSlotMinutes = 15; // отсекаем совсем мелкие дырки
    final List<FreeSlot> result = [];

    DateTime cursor = startOfDay;

    for (final event in activeEvents) {
      DateTime eventStart =
      event.start.isBefore(startOfDay) ? startOfDay : event.start;
      DateTime eventEnd =
      event.end.isAfter(endOfDay) ? endOfDay : event.end;

      // Событие полностью внутри уже занятого промежутка.
      if (!eventEnd.isAfter(cursor)) {
        continue;
      }

      // Между курсором и началом события есть свободное окно.
      if (eventStart.isAfter(cursor)) {
        final slot = FreeSlot(start: cursor, end: eventStart);
        if (slot.duration.inMinutes >= minSlotMinutes) {
          result.add(slot);
        }
      }

      cursor = eventEnd;
      if (!cursor.isBefore(endOfDay)) {
        break;
      }
    }

    // Хвост дня после последнего события.
    if (cursor.isBefore(endOfDay)) {
      final lastSlot = FreeSlot(start: cursor, end: endOfDay);
      if (lastSlot.duration.inMinutes >= minSlotMinutes) {
        result.add(lastSlot);
      }
    }

    return result;
  }

  DayOverview _buildOverview({DateTime? now}) {
    final DateTime referenceNow = now ?? DateTime.now();
    final List<CalendarEvent> sorted = [..._currentEvents]
      ..sort((a, b) => a.start.compareTo(b.start));
    final List<FreeSlot> slots = freeSlots;

    final Duration busy =
    sorted.fold(Duration.zero, (sum, e) => sum + e.duration);
    final Duration free =
    slots.fold(Duration.zero, (sum, s) => sum + s.duration);

    final CalendarEvent? firstEvent =
    sorted.isNotEmpty ? sorted.first : null;
    final CalendarEvent? lastEvent =
    sorted.isNotEmpty ? sorted.last : null;

    CalendarEvent? nextEvent;
    if (DateUtils.isSameDay(referenceNow, day)) {
      for (final event in sorted) {
        if (event.end.isAfter(referenceNow)) {
          nextEvent = event;
          break;
        }
      }
    }

    return DayOverview(
      totalEvents: sorted.length,
      busy: busy,
      free: free,
      firstEvent: firstEvent,
      lastEvent: lastEvent,
      nextEvent: nextEvent,
    );
  }

  // Демонстрационные события — для предварительного вида экрана.
  static List<CalendarEvent> _createSampleEvents(DateTime day) {
    final base = DateTime(day.year, day.month, day.day);
    return <CalendarEvent>[
      CalendarEvent(
        title: 'Командный стендап',
        start: base.add(const Duration(hours: 8, minutes: 30)),
        duration: const Duration(minutes: 30),
      ),
      CalendarEvent(
        title: 'Дизайн-ревью',
        start: base.add(const Duration(hours: 9, minutes: 30)),
        duration: const Duration(minutes: 90),
      ),
      CalendarEvent(
        title: 'Персональная работа',
        start: base.add(const Duration(hours: 11)),
        duration: const Duration(minutes: 110),
      ),
      CalendarEvent(
        title: 'Обед',
        start: base.add(const Duration(hours: 13)),
        duration: const Duration(minutes: 60),
      ),
      CalendarEvent(
        title: 'Созвон с клиентом',
        start: base.add(const Duration(hours: 14, minutes: 45)),
        duration: const Duration(minutes: 45),
      ),
      CalendarEvent(
        title: 'Фокус-время',
        start: base.add(const Duration(hours: 16)),
        duration: const Duration(minutes: 120),
      ),
      CalendarEvent(
        title: 'Спорт',
        start: base.add(const Duration(hours: 19)),
        duration: const Duration(minutes: 50),
      ),
    ];
  }
}
