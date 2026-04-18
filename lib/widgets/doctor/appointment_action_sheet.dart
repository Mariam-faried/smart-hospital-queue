import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../services/queue_service.dart';
import '../../services/queue_transition_policy.dart';
import '../../utils/app_colors.dart';
import 'doctor_patient_info_card.dart';

class AppointmentActionSheet extends StatelessWidget {
  final AppointmentModel appointment;
  static final QueueService _queueService = QueueService();

  const AppointmentActionSheet({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = QueueTransitionPolicy.normalizeStatus(
      appointment.status,
    );
    final bool isCompleted =
        normalizedStatus == QueueAppointmentStatus.completed;
    final bool isCancelled =
        normalizedStatus == QueueAppointmentStatus.cancelled ||
        normalizedStatus == QueueAppointmentStatus.noShow;
    final bool canStartConsultation =
        normalizedStatus == QueueAppointmentStatus.waiting ||
        normalizedStatus == QueueAppointmentStatus.confirmed;
    final bool canCompleteConsultation =
        normalizedStatus == QueueAppointmentStatus.inProgress;
    final bool canMarkNoShow = canStartConsultation;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Appointment Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DoctorPatientInfoCard(appointment: appointment),
          const SizedBox(height: 24),

          if (!isCompleted && !isCancelled) ...[
            if (canStartConsultation)
              ElevatedButton.icon(
                onPressed: () => _updateStatus(
                  context,
                  QueueAppointmentStatus.inProgress,
                  successMessage: 'Consultation started.',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow, color: AppColors.onInfo),
                label: const Text(
                  'Start Consultation',
                  style: TextStyle(color: AppColors.onInfo, fontSize: 16),
                ),
              ),
            if (canCompleteConsultation)
              ElevatedButton.icon(
                onPressed: () => _updateStatus(
                  context,
                  QueueAppointmentStatus.completed,
                  successMessage: 'Consultation completed.',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.check_circle,
                  color: AppColors.onSuccess,
                ),
                label: const Text(
                  'Complete Consultation',
                  style: TextStyle(color: AppColors.onSuccess, fontSize: 16),
                ),
              ),
            if (canStartConsultation || canCompleteConsultation)
              const SizedBox(height: 12),
            if (canMarkNoShow)
              OutlinedButton.icon(
                onPressed: () => _updateStatus(
                  context,
                  QueueAppointmentStatus.noShow,
                  successMessage: 'Patient marked as no-show.',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.person_off),
                label: const Text(
                  'Mark No Show',
                  style: TextStyle(fontSize: 16),
                ),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted
                    ? 'Consultation Completed'
                    : 'Appointment Cancelled/No Show',
                style: TextStyle(
                  color: isCompleted ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Bad state:')) {
      return raw.replaceFirst('Bad state:', '').trim();
    }
    if (raw.startsWith('StateError:')) {
      return raw.replaceFirst('StateError:', '').trim();
    }
    return 'Could not update appointment status. Please try again.';
  }

  Future<void> _updateStatus(
    BuildContext context,
    String targetStatus, {
    required String successMessage,
  }) async {
    Navigator.pop(context); // Close sheet early for better UX

    try {
      final doctorId = appointment.doctorId.trim();
      if (doctorId.isEmpty) {
        throw StateError('Doctor ID is missing for this appointment.');
      }

      await _queueService.markAppointmentStatus(
        appointment.id,
        doctorId,
        targetStatus,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
