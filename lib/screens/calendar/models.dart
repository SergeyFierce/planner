/// Модель одного события календаря.
class CalendarEvent {
  CalendarEvent({
    this.id,
    required this.title,
    required this.start,
    required this.duration,
    this.description,
    this.comment,
    this.isDone = false,
  });

  final int? id;
  final String title;
  final DateTime start;
  final Duration duration;
  final String? description;
  final String? comment;

  /// Флаг выполнения задачи
  bool isDone;

  DateTime get end => start.add(duration);

  CalendarEvent copyWith({
    int? id,
    String? title,
    DateTime? start,
    Duration? duration,
    String? description,
    String? comment,
    bool? isDone,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      description: description ?? this.description,
      comment: comment ?? this.comment,
      isDone: isDone ?? this.isDone,
    );
  }

  factory CalendarEvent.fromDatabase(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] as int?,
      title: map['title'] as String,
      start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int),
      duration: Duration(minutes: map['duration_minutes'] as int),
      description: map['description'] as String?,
      comment: map['comment'] as String?,
      isDone: (map['is_done'] as int) == 1,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'start': start.millisecondsSinceEpoch,
      'duration_minutes': duration.inMinutes,
      'description': description,
      'comment': comment,
      'is_done': isDone ? 1 : 0,
    };
  }
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
  free, // день свободен
  hasEvents, // есть дела в этот день (будущее / сегодня)
  hasIncomplete, // есть невыполненные дела (в прошлом / сегодня)
  allDone, // все дела выполнены
}
