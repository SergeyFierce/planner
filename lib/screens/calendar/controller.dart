import 'package:flutter/material.dart';

/// Модель одного события календаря.
class CalendarEvent {
  CalendarEvent({
    required this.title,
    required this.start,
    required this.duration,
    this.description,
  });

  final String title;
  final DateTime start;
  final Duration duration;
  final String? description;

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

class CalendarController {
  CalendarController({
    DateTime? day,
    List<CalendarEvent>? events,
  })  : day = DateUtils.dateOnly(day ?? DateTime.now()),
        _events = List<CalendarEvent>.from(
          events ??
              _createSampleEvents(
                DateUtils.dateOnly(day ?? DateTime.now()),
              ),
        ) {
    _events.sort((a, b) => a.start.compareTo(b.start));
  }

  final DateTime day;
  final List<CalendarEvent> _events;

  String get headline => 'Календарь';
  String get description =>
      'Планируйте свои события и отслеживайте ближайшие задачи.';

  /// Все события дня (read-only).
  List<CalendarEvent> get events => List.unmodifiable(_events);

  /// Свободные промежутки внутри дня.
  List<FreeSlot> get freeSlots => _computeFreeSlots();

  /// Самое длинное свободное окно — лучшее для фокусной работы.
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

  /// Добавить событие в день.
  void addEvent(CalendarEvent event) {
    _events.add(event);
    _events.sort((a, b) => a.start.compareTo(b.start));
  }

  List<FreeSlot> _computeFreeSlots() {
    final DateTime startOfDay = DateTime(day.year, day.month, day.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    // Если вообще нет событий — весь день свободен.
    if (_events.isEmpty) {
      return [
        FreeSlot(start: startOfDay, end: endOfDay),
      ];
    }

    const int minSlotMinutes = 15; // отсекаем совсем мелкие дырки
    final List<FreeSlot> result = [];
    final List<CalendarEvent> sorted = [..._events]
      ..sort((a, b) => a.start.compareTo(b.start));

    DateTime cursor = startOfDay;

    for (final event in sorted) {
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
    final List<CalendarEvent> sorted = [..._events]
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
