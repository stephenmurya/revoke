class TaperPlanModel {
  final String id;
  final String scheduleId;
  final String status;
  final List<String> targetApps;
  final int baselineDailyMinutes;
  final int targetDailyMinutes;
  final int durationDays;
  final DateTime startDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaperPlanModel({
    required this.id,
    required this.scheduleId,
    required this.status,
    required this.targetApps,
    required this.baselineDailyMinutes,
    required this.targetDailyMinutes,
    required this.durationDays,
    required this.startDate,
    required this.createdAt,
    required this.updatedAt,
  });

  List<int> get dailyLimits {
    final safeDuration = durationDays.clamp(1, 365).toInt();
    final safeBaseline = baselineDailyMinutes.clamp(1, 1440).toInt();
    final safeTarget = targetDailyMinutes.clamp(1, safeBaseline).toInt();
    if (safeDuration == 1) return <int>[safeTarget];

    return List<int>.generate(safeDuration, (index) {
      final ratio = index / (safeDuration - 1);
      final value = safeBaseline + ((safeTarget - safeBaseline) * ratio);
      return value.round().clamp(safeTarget, safeBaseline).toInt();
    });
  }

  int dayIndexFor(DateTime date) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final current = DateTime(date.year, date.month, date.day);
    final maxIndex = (durationDays - 1).clamp(0, 364).toInt();
    return current.difference(start).inDays.clamp(0, maxIndex).toInt();
  }

  int limitFor(DateTime date) {
    final limits = dailyLimits;
    if (limits.isEmpty) return targetDailyMinutes;
    return limits[dayIndexFor(date).clamp(0, limits.length - 1).toInt()];
  }

  double progressFor(DateTime date) {
    if (durationDays <= 1) return 1;
    final index = dayIndexFor(date);
    return ((index + 1) / durationDays).clamp(0, 1).toDouble();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheduleId': scheduleId,
      'status': status,
      'targetApps': targetApps,
      'baselineDailyMinutes': baselineDailyMinutes,
      'targetDailyMinutes': targetDailyMinutes,
      'durationDays': durationDays,
      'startDateMs': startDate.millisecondsSinceEpoch,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
      'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      'dailyLimits': dailyLimits,
      'todayLimitMinutes': limitFor(DateTime.now()),
      'progress': progressFor(DateTime.now()),
    };
  }

  factory TaperPlanModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return TaperPlanModel(
      id: (json['id'] as String?)?.trim() ?? '',
      scheduleId: (json['scheduleId'] as String?)?.trim() ?? '',
      status: (json['status'] as String?)?.trim() ?? 'active',
      targetApps: List<String>.from(
        json['targetApps'] as List? ?? const <String>[],
      ).map((pkg) => pkg.trim()).where((pkg) => pkg.isNotEmpty).toList(),
      baselineDailyMinutes: _intFromJson(json['baselineDailyMinutes'], 1),
      targetDailyMinutes: _intFromJson(json['targetDailyMinutes'], 1),
      durationDays: _intFromJson(json['durationDays'], 1),
      startDate: _dateFromMs(json['startDateMs'], now),
      createdAt: _dateFromMs(json['createdAtMs'], now),
      updatedAt: _dateFromMs(json['updatedAtMs'], now),
    );
  }

  TaperPlanModel copyWith({
    String? id,
    String? scheduleId,
    String? status,
    List<String>? targetApps,
    int? baselineDailyMinutes,
    int? targetDailyMinutes,
    int? durationDays,
    DateTime? startDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaperPlanModel(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      status: status ?? this.status,
      targetApps: targetApps ?? this.targetApps,
      baselineDailyMinutes: baselineDailyMinutes ?? this.baselineDailyMinutes,
      targetDailyMinutes: targetDailyMinutes ?? this.targetDailyMinutes,
      durationDays: durationDays ?? this.durationDays,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _intFromJson(dynamic value, int fallback) {
    return switch (value) {
      num() => value.toInt(),
      String() => int.tryParse(value) ?? fallback,
      _ => fallback,
    };
  }

  static DateTime _dateFromMs(dynamic value, DateTime fallback) {
    final parsed = _intFromJson(value, 0);
    if (parsed <= 0) return fallback;
    return DateTime.fromMillisecondsSinceEpoch(parsed);
  }
}
