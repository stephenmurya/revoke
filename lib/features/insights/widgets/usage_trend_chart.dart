import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/usage_insights_model.dart';
import '../../../core/theme/revoke_tokens.dart';
import '../../../core/utils/theme_extensions.dart';

class UsageTrendChart extends StatelessWidget {
  const UsageTrendChart({
    super.key,
    required this.buckets,
    this.plannedMinutes,
    this.height = 190,
  });

  final List<UsageInsightBucket> buckets;
  final List<int>? plannedMinutes;
  final double height;

  @override
  Widget build(BuildContext context) {
    final active = buckets.where((bucket) => !bucket.isFuture).toList();
    final actual = active.map((bucket) => bucket.minutes).toList();
    final planned = plannedMinutes == null
        ? const <int>[]
        : [
            for (
              var i = 0;
              i < active.length && i < plannedMinutes!.length;
              i++
            )
              plannedMinutes![i],
          ];
    final label = _accessibleSummary(actual, planned);

    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _UsageTrendPainter(
              actual: actual,
              planned: planned,
              labels: active.map((bucket) => bucket.label).toList(),
              accent: context.colors.accent,
              secondary: context.colors.textSecondary,
              grid: context.colors.borderSubtle,
            ),
          ),
        ),
      ),
    );
  }

  String _accessibleSummary(List<int> actual, List<int> planned) {
    if (actual.isEmpty) return 'No usage data recorded for this period.';
    final total = actual.fold<int>(0, (sum, value) => sum + value);
    final average = (total / actual.length).round();
    final planText = planned.isEmpty
        ? ''
        : ' Planned allowance is shown for comparison.';
    return 'Usage trend for ${actual.length} recorded days. Average ${_formatMinutes(average)} per day.$planText';
  }
}

class _UsageTrendPainter extends CustomPainter {
  const _UsageTrendPainter({
    required this.actual,
    required this.planned,
    required this.labels,
    required this.accent,
    required this.secondary,
    required this.grid,
  });

  final List<int> actual;
  final List<int> planned;
  final List<String> labels;
  final Color accent;
  final Color secondary;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(0, 8, size.width, size.height - 36);
    final allValues = [...actual, ...planned, 10];
    final maxValue = allValues.reduce(math.max).toDouble() * 1.18;
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.7)
      ..strokeWidth = RevokeBorders.subtle;
    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    if (actual.isEmpty) return;

    Offset pointFor(List<int> values, int index) {
      final denominator = math.max(1, values.length - 1);
      final x = chart.left + chart.width * index / denominator;
      final y =
          chart.bottom -
          (values[index] / maxValue).clamp(0, 1).toDouble() * chart.height;
      return Offset(x, y);
    }

    if (planned.length == actual.length && planned.isNotEmpty) {
      _drawLine(
        canvas,
        planned,
        chart,
        maxValue,
        secondary.withValues(alpha: 0.8),
        1.5,
        dashed: true,
      );
    }
    _drawLine(canvas, actual, chart, maxValue, accent, 2.5);

    final dotPaint = Paint()..color = accent;
    for (var i = 0; i < actual.length; i++) {
      canvas.drawCircle(pointFor(actual, i), 3, dotPaint);
    }
    _drawLabels(canvas, chart);
  }

  void _drawLine(
    Canvas canvas,
    List<int> values,
    Rect chart,
    double maxValue,
    Color color,
    double strokeWidth, {
    bool dashed = false,
  }) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final denominator = math.max(1, values.length - 1);
      final x = chart.left + chart.width * i / denominator;
      final y =
          chart.bottom -
          (values[i] / maxValue).clamp(0, 1).toDouble() * chart.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (var i = 0; i < values.length - 1; i++) {
      final start = _point(values, chart, maxValue, i);
      final end = _point(values, chart, maxValue, i + 1);
      final distance = (end - start).distance;
      if (distance == 0) continue;
      final direction = (end - start) / distance;
      for (var offset = 0.0; offset < distance; offset += 8) {
        final dashStart = start + direction * offset;
        final dashEnd = start + direction * math.min(offset + 4, distance);
        canvas.drawLine(dashStart, dashEnd, paint);
      }
    }
  }

  Offset _point(List<int> values, Rect chart, double maxValue, int index) {
    final denominator = math.max(1, values.length - 1);
    final x = chart.left + chart.width * index / denominator;
    final y =
        chart.bottom -
        (values[index] / maxValue).clamp(0, 1).toDouble() * chart.height;
    return Offset(x, y);
  }

  void _drawLabels(Canvas canvas, Rect chart) {
    if (labels.isEmpty) return;
    final style = TextStyle(fontSize: 10, color: secondary);
    final indexes = labels.length <= 4
        ? List<int>.generate(labels.length, (index) => index)
        : <int>[0, labels.length ~/ 2, labels.length - 1];
    for (final index in indexes.toSet()) {
      final text = TextPainter(
        text: TextSpan(text: labels[index], style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      final denominator = math.max(1, labels.length - 1);
      final x = chart.left + chart.width * index / denominator;
      final left = (x - text.width / 2).clamp(0.0, chart.width - text.width);
      text.paint(canvas, Offset(left, chart.bottom + RevokeSpacing.sm));
    }
  }

  @override
  bool shouldRepaint(covariant _UsageTrendPainter oldDelegate) {
    return oldDelegate.actual != actual ||
        oldDelegate.planned != planned ||
        oldDelegate.labels != labels ||
        oldDelegate.accent != accent ||
        oldDelegate.secondary != secondary ||
        oldDelegate.grid != grid;
  }
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}
