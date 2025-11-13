import 'package:flutter/material.dart';

import '../../data/local_database.dart';
import 'models.dart';

DateTime _normalizeDate(DateTime d) => DateUtils.dateOnly(d);

class CalendarController extends ChangeNotifier {
  CalendarController({
    LocalDatabase? database,
    DateTime? day,
    List<CalendarEvent>? events,
  })  : _database = database ?? LocalDatabase(),
        _currentDay = _normalizeDate(day ?? DateTime.now()) {
    if (events != null && events.isNotEmpty) {
      for (final event in events) {
        final key = _normalizeDate(event.start);
        final list = _eventsByDay.putIfAbsent(key, () => <CalendarEvent>[]);
        list.add(event);
      }
      _sortAllDays();
      _initialized = true;
    }
  }

  final LocalDatabase _database;
  final Map<DateTime, List<CalendarEvent>> _eventsByDay =
      <DateTime, List<CalendarEvent>>{};

  DateTime _currentDay;
  bool _initialized = false;

  DateTime get day => _currentDay;
  bool get isInitialized => _initialized;

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

  Future<void> initialize() async {
    if (_initialized && _eventsByDay.isNotEmpty) {
      return;
    }

    await _database.init();
    final allEvents = await _database.loadAllEvents();
    _eventsByDay.clear();
    for (final event in allEvents) {
      final key = _normalizeDate(event.start);
      final list = _eventsByDay.putIfAbsent(key, () => <CalendarEvent>[]);
      list.add(event);
    }
    _ensureDayEntry(_currentDay);
    _sortAllDays();
    _initialized = true;
    notifyListeners();
  }

  void _ensureDayEntry(DateTime day) {
    final normalized = _normalizeDate(day);
    _eventsByDay.putIfAbsent(normalized, () => <CalendarEvent>[]);
  }

  void _sortAllDays() {
    for (final list in _eventsByDay.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  /// Переключить текущий день (используется в месячном календаре).
  void setDay(DateTime newDay) {
    final normalized = _normalizeDate(newDay);
    if (normalized == _currentDay) {
      return;
    }
    _currentDay = normalized;
    _ensureDayEntry(_currentDay);
    notifyListeners();
  }

  /// Создать и сразу добавить событие.
  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime start,
    Duration duration = const Duration(minutes: 30),
    String? description,
    String? comment,
  }) async {
    final event = CalendarEvent(
      title: title,
      start: start,
      duration: duration,
      description: description,
      comment: comment,
    );

    await _database.init();
    final int id = await _database.insertEvent(event);
    final stored = event.copyWith(id: id);

    final key = _normalizeDate(start);
    final list = _eventsByDay.putIfAbsent(key, () => <CalendarEvent>[]);
    list
      ..add(stored)
      ..sort((a, b) => a.start.compareTo(b.start));

    notifyListeners();
    return stored;
  }

  /// Отметить / снять отметку «выполнено» у события.
  Future<void> toggleEventCompletion(CalendarEvent event) async {
    event.isDone = !event.isDone;
    await _database.updateEvent(event);
    notifyListeners();
  }

  bool hasOverlap(DateTime start, Duration duration, {CalendarEvent? ignore}) {
    final key = _normalizeDate(start);
    final list = _eventsByDay[key];
    if (list == null || list.isEmpty) {
      return false;
    }

    final DateTime end = start.add(duration);
    for (final event in list) {
      if (ignore != null && event.id == ignore.id) {
        continue;
      }
      final bool overlaps = start.isBefore(event.end) && end.isAfter(event.start);
      if (overlaps) {
        return true;
      }
    }
    return false;
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
    final DateTime startOfDay = DateTime(day.year, day.month, day.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

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
      DateTime eventEnd = event.end.isAfter(endOfDay) ? endOfDay : event.end;

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
}
