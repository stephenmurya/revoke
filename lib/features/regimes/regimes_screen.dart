import 'package:flutter/material.dart';

import '../../core/services/schedule_service.dart';
import '../../core/models/schedule_model.dart';
import '../monitor/home_screen.dart';

class RegimesScreen extends StatelessWidget {
  const RegimesScreen({super.key});

  String _buildRegimeKey(List<ScheduleModel> regimes) {
    return regimes
        .map(
          (r) =>
              '${r.id}:${r.isActive ? 1 : 0}:${r.name}:${r.targetApps.length}',
        )
        .join('|');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleModel>>(
      stream: ScheduleService.watchSchedules(),
      builder: (context, snapshot) {
        final regimes = snapshot.data ?? const <ScheduleModel>[];
        final refreshKey = _buildRegimeKey(regimes);
        // Rebuild the existing dashboard when regime data changes.
        return KeyedSubtree(
          key: ValueKey(refreshKey),
          child: HomeScreen(schedules: regimes),
        );
      },
    );
  }
}
