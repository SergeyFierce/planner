import 'package:flutter/material.dart';

/// Data model for a single calendar entry used by the timeline.
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

class CalendarController {
  CalendarController({DateTime? day, List<CalendarEvent>? events})
      : day = DateUtils.dateOnly(day ?? DateTime.now()),
        _events = events ?? _createSampleEvents(DateUtils.dateOnly(day ?? DateTime.now()));

  final DateTime day;
  final List<CalendarEvent> _events;

  String get headline => 'Календарь';
  String get description => 'Планируйте свои события и отслеживайте ближайшие задачи.';

  List<CalendarEvent> get events => List.unmodifiable(_events);

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
