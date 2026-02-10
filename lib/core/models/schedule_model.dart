import 'package:flutter/material.dart';

enum ScheduleType {
  timeBlock('TIME BLOCK'),
  usageLimit('USAGE LIMIT'),
  launchCount('LAUNCH COUNT');

  final String label;
  const ScheduleType(this.label);
}

class ScheduleModel {
  final String id;
  final String name;
  final ScheduleType type;
  final List<String> targetApps;
  final List<int> days; // 1-7 (Mon-Sun)
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Duration? durationLimit;
  final bool isActive;

  ScheduleModel({
    required this.id,
    required this.name,
    required this.type,
    required this.targetApps,
    required this.days,
    this.startTime,
    this.endTime,
    this.durationLimit,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'targetApps': targetApps,
      'days': days,
      'startHour': startTime?.hour,
      'startMinute': startTime?.minute,
      'endHour': endTime?.hour,
      'endMinute': endTime?.minute,
      'durationSeconds': durationLimit?.inSeconds,
      'isActive': isActive,
    };
  }

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'],
      name: json['name'],
      type: ScheduleType.values[json['type']],
      targetApps: List<String>.from(json['targetApps']),
      days: List<int>.from(json['days']),
      startTime: json['startHour'] != null
          ? TimeOfDay(hour: json['startHour'], minute: json['startMinute'])
          : null,
      endTime: json['endHour'] != null
          ? TimeOfDay(hour: json['endHour'], minute: json['endMinute'])
          : null,
      durationLimit: json['durationSeconds'] != null
          ? Duration(seconds: json['durationSeconds'])
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  ScheduleModel copyWith({
    String? name,
    ScheduleType? type,
    List<String>? targetApps,
    List<int>? days,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    Duration? durationLimit,
    bool? isActive,
  }) {
    return ScheduleModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      targetApps: targetApps ?? this.targetApps,
      days: days ?? this.days,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationLimit: durationLimit ?? this.durationLimit,
      isActive: isActive ?? this.isActive,
    );
  }
}
