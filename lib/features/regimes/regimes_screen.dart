import 'package:flutter/material.dart';

import '../../core/services/schedule_service.dart';
import '../../core/models/schedule_model.dart';
import '../monitor/home_screen.dart';

class RegimesScreen extends StatefulWidget {
  const RegimesScreen({super.key});

  @override
  State<RegimesScreen> createState() => _RegimesScreenState();
}

class _RegimesScreenState extends State<RegimesScreen> {
  // Created once per State lifetime. A new stream object must never be
  // constructed inside build(): StreamBuilder treats a changed stream
  // identity as a reset (waiting/null data) and re-subscribes from scratch.
  late final Stream<List<ScheduleModel>> _schedulesStream;

  @override
  void initState() {
    super.initState();
    _schedulesStream = ScheduleService.watchSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleModel>>(
      stream: _schedulesStream,
      builder: (context, snapshot) {
        final regimes = snapshot.data ?? const <ScheduleModel>[];
        // Deliberately no KeyedSubtree/ValueKey here: keying HomeScreen by
        // data content destroyed its State on every emission (scroll reset,
        // animation replays, timers re-armed). HomeScreen.didUpdateWidget
        // already diffs schedule changes and updates itself in place.
        return HomeScreen(schedules: regimes);
      },
    );
  }
}
