import '../models/commitment_draft.dart';
import '../models/circle_models.dart';
import '../models/schedule_model.dart';
import '../../features/commitments/commitment_presentation.dart';
import 'circle_service.dart';
import 'regime_service.dart';
import 'schedule_service.dart';
import 'taper_plan_service.dart';

class OnboardingActivationException implements Exception {
  const OnboardingActivationException(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// Coordinates the existing local-first schedule boundary with the later
/// authority and Credit steps. It is intentionally not a global transaction:
/// behavioral persistence and server Credit backing have different authorities.
class OnboardingActivationCoordinator {
  const OnboardingActivationCoordinator._();

  static Future<CommitmentViewModel> prepareBehavioralCommitment(
    CommitmentDraft draft, {
    bool requireCloud = false,
  }) async {
    if (draft.targetApps.isEmpty || draft.days.isEmpty) {
      throw const OnboardingActivationException(
        'Choose at least one app and one active day.',
        retryable: false,
      );
    }

    try {
      if (draft.isReduce) {
        await TaperPlanService.savePlanLocalFirst(draft.toReducePlan());
      } else {
        await ScheduleService.saveSchedule(draft.toProtectSchedule());
      }
    } on FormatException catch (error) {
      throw OnboardingActivationException(
        'The Commitment draft is incomplete: ${error.message}',
        retryable: false,
      );
    } catch (_) {
      throw const OnboardingActivationException(
        'The Commitment could not be saved on this device. Try again.',
      );
    }

    final schedules = await ScheduleService.getSchedules();
    ScheduleModel? schedule;
    for (final item in schedules) {
      if (item.id == draft.scheduleId) {
        schedule = item;
        break;
      }
    }
    if (schedule == null) {
      throw const OnboardingActivationException(
        'The Commitment was saved, but its enforcement rule is not ready yet.',
      );
    }

    var cloudSynced = false;
    try {
      // The normal ScheduleService path remains local-first. This awaited
      // write is only needed before server-owned authority/hold operations.
      await RegimeService.saveRegime(schedule);
      cloudSynced = true;
    } catch (_) {
      if (requireCloud) {
        throw const OnboardingActivationException(
          'Connect to Revoke to finish activating this Commitment safely.',
        );
      }
    }

    try {
      await ScheduleService.syncWithNative();
    } catch (_) {
      throw const OnboardingActivationException(
        'Android enforcement could not be synchronized. Check permissions and try again.',
      );
    }

    if (requireCloud && !cloudSynced) {
      throw const OnboardingActivationException(
        'The Commitment needs a server confirmation before this option can continue.',
      );
    }

    final plan = draft.isReduce ? draft.toReducePlan() : null;
    return CommitmentPresentationAdapter.fromSchedule(
      schedule,
      taperPlan: plan,
    );
  }

  static Future<void> persistAuthority({
    required String commitmentId,
    required String authority,
    List<String> selectedMemberIds = const <String>[],
  }) async {
    if (authority == 'self') return;
    try {
      await CircleService.setPolicy(
        commitmentId: commitmentId,
        authority: OverrideAuthority.values.firstWhere(
          (item) => item.wireName == authority,
          orElse: () => OverrideAuthority.self,
        ),
        selectedMemberIds: selectedMemberIds,
      );
    } catch (_) {
      throw const OnboardingActivationException(
        'Override Authority could not be confirmed. Check your connection and try again.',
      );
    }
  }
}
