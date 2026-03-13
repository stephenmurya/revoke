import 'package:flutter/material.dart';

enum ScheduleType {
  timeBlock('TIME BLOCK'),
  usageLimit('USAGE LIMIT'),
  launchCount('LAUNCH COUNT');

  final String label;
  const ScheduleType(this.label);
}

class ScheduleBlock {
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const ScheduleBlock({required this.startTime, required this.endTime});

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;

  bool get crossesMidnight => endMinutes <= startMinutes;

  Duration get duration {
    if (endMinutes > startMinutes) {
      return Duration(minutes: endMinutes - startMinutes);
    }
    if (endMinutes < startMinutes) {
      return Duration(minutes: (1440 - startMinutes) + endMinutes);
    }
    return Duration.zero;
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startTime.hour,
      'startMinute': startTime.minute,
      'endHour': endTime.hour,
      'endMinute': endTime.minute,
      'startTime': _timeToString(startTime),
      'endTime': _timeToString(endTime),
    };
  }

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) {
    final start = _parseTime(
      json['startTime'],
      json['startHour'],
      json['startMinute'],
    );
    final end = _parseTime(json['endTime'], json['endHour'], json['endMinute']);
    if (start == null || end == null) {
      throw const FormatException('INVALID_BLOCK_TIME');
    }
    return ScheduleBlock(startTime: start, endTime: end);
  }

  static TimeOfDay? _parseTime(dynamic value, dynamic hour, dynamic minute) {
    if (value is String && value.contains(':')) {
      final parts = value.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    }

    final parsedHour = switch (hour) {
      num() => hour.toInt(),
      String() => int.tryParse(hour),
      _ => null,
    };
    final parsedMinute = switch (minute) {
      num() => minute.toInt(),
      String() => int.tryParse(minute),
      _ => 0,
    };
    if (parsedHour == null ||
        parsedMinute == null ||
        parsedHour < 0 ||
        parsedHour > 23 ||
        parsedMinute < 0 ||
        parsedMinute > 59) {
      return null;
    }

    return TimeOfDay(hour: parsedHour, minute: parsedMinute);
  }

  static String _timeToString(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  ScheduleBlock copyWith({TimeOfDay? startTime, TimeOfDay? endTime}) {
    return ScheduleBlock(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class ScheduleModel {
  static const String defaultEmoji = '\u{1F3AF}';
  static const List<String> curatedEmojis = <String>[
    '\u{1F3AF}',
    '\u{1F4DA}',
    '\u{1F4BC}',
    '\u{1F9E0}',
    '\u{1F3CB}\u{FE0F}',
    '\u{1F9D8}',
    '\u{1F319}',
    '\u{1F3B5}',
    '\u{23F1}\u{FE0F}',
    '\u{1F512}',
    '\u{1F6E1}\u{FE0F}',
    '\u{1F6AB}',
  ];

  final String id;
  final String name;
  final ScheduleType type;
  final List<String> targetApps;
  final List<int> days; // 1-7 (Mon-Sun)
  final List<ScheduleBlock> blocks;
  final Duration? durationLimit;
  final bool isActive;
  final String emoji;

  ScheduleModel({
    required this.id,
    required this.name,
    required this.type,
    required this.targetApps,
    required this.days,
    this.blocks = const <ScheduleBlock>[],
    this.durationLimit,
    this.isActive = true,
    this.emoji = defaultEmoji,
  });

  TimeOfDay? get startTime => blocks.isEmpty ? null : blocks.first.startTime;
  TimeOfDay? get endTime => blocks.isEmpty ? null : blocks.first.endTime;
  bool get hasBlocks => blocks.isNotEmpty;

  Map<String, dynamic> toJson() {
    final safeBlocks = blocks;
    final firstBlock = safeBlocks.isEmpty ? null : safeBlocks.first;
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'targetApps': targetApps,
      'days': days,
      'blocks': safeBlocks.map((block) => block.toJson()).toList(),
      'startHour': firstBlock?.startTime.hour,
      'startMinute': firstBlock?.startTime.minute,
      'endHour': firstBlock?.endTime.hour,
      'endMinute': firstBlock?.endTime.minute,
      'durationSeconds': durationLimit?.inSeconds,
      'isActive': isActive,
      'emoji': emoji,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawType = switch (json['type']) {
      num() => json['type'].toInt(),
      String() => int.tryParse(json['type']) ?? 0,
      _ => 0,
    };
    final safeType = rawType.clamp(0, ScheduleType.values.length - 1);
    final type = ScheduleType.values[safeType];

    final parsedBlocks = <ScheduleBlock>[];
    final rawBlocks = json['blocks'];
    if (rawBlocks is List) {
      for (final raw in rawBlocks) {
        if (raw is! Map) continue;
        try {
          parsedBlocks.add(
            ScheduleBlock.fromJson(Map<String, dynamic>.from(raw)),
          );
        } catch (_) {
          // Skip malformed blocks so one bad payload doesn't break all regimes.
        }
      }
    }

    if (parsedBlocks.isEmpty) {
      final legacyStart = ScheduleBlock._parseTime(
        null,
        json['startHour'],
        json['startMinute'],
      );
      final legacyEnd = ScheduleBlock._parseTime(
        null,
        json['endHour'],
        json['endMinute'],
      );
      if (legacyStart != null && legacyEnd != null) {
        parsedBlocks.add(
          ScheduleBlock(startTime: legacyStart, endTime: legacyEnd),
        );
      }
    }

    final days = List<int>.from(
      json['days'] as List? ?? const <int>[],
    ).map((d) => d.clamp(1, 7)).toSet().toList()..sort();

    final targetApps = List<String>.from(
      json['targetApps'] as List? ?? const <String>[],
    ).map((pkg) => pkg.trim()).where((pkg) => pkg.isNotEmpty).toList();

    final rawEmoji = (json['emoji'] as String?)?.trim();
    final emoji = rawEmoji == null || rawEmoji.isEmpty
        ? defaultEmoji
        : rawEmoji;

    final durationSeconds = switch (json['durationSeconds']) {
      num() => json['durationSeconds'].toInt(),
      String() => int.tryParse(json['durationSeconds']),
      _ => null,
    };

    return ScheduleModel(
      id: (json['id'] as String?)?.trim() ?? '',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'REGIME',
      type: type,
      targetApps: targetApps,
      days: days,
      blocks: parsedBlocks,
      durationLimit: durationSeconds == null
          ? null
          : Duration(seconds: durationSeconds),
      isActive: json['isActive'] ?? true,
      emoji: emoji,
    );
  }

  ScheduleModel copyWith({
    String? name,
    ScheduleType? type,
    List<String>? targetApps,
    List<int>? days,
    List<ScheduleBlock>? blocks,
    Duration? durationLimit,
    bool? isActive,
    String? emoji,
  }) {
    return ScheduleModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetApps: targetApps ?? this.targetApps,
      days: days ?? this.days,
      blocks: blocks ?? this.blocks,
      durationLimit: durationLimit ?? this.durationLimit,
      isActive: isActive ?? this.isActive,
      emoji: emoji ?? this.emoji,
    );
  }
}
