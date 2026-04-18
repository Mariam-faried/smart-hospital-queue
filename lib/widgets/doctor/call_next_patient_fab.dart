import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/queue_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

class CallNextPatientFab extends StatelessWidget {
  final DateTime selectedDate;

  const CallNextPatientFab({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueProvider>(
      builder: (context, queueProvider, _) {
        final hasWaitingPatients = queueProvider.activeQueue.any(
          (e) => e.status == 'waiting',
        );

        return FloatingActionButton.extended(
          onPressed: hasWaitingPatients
              ? () => _callNextPatient(context, queueProvider)
              : null,
          backgroundColor: hasWaitingPatients
              ? AppColors.primary
              : AppColors.textSecondary.withValues(alpha: 0.35),
          foregroundColor: AppColors.onPrimary,
          elevation: hasWaitingPatients ? 4 : 0,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Call Next'),
        );
      },
    );
  }

  Future<void> _callNextPatient(
    BuildContext context,
    QueueProvider queueProvider,
  ) async {
    final doctorId = context.read<AuthProvider>().user?.uid;
    if (doctorId == null) return;

    try {
      final nextPatient = await queueProvider.callNextPatient(
        doctorId,
        selectedDate,
      );

      if (!context.mounted) return;

      if (nextPatient != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Patient Called'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket: ${AppFormatters.formatTicketString(nextPatient.ticketNumber)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Patient: ${nextPatient.patientName}'),
                const SizedBox(height: 4),
                Text('Position: #${nextPatient.position}'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No patients waiting in the queue.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not call the next patient. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
