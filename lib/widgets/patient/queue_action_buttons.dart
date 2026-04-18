import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_colors.dart';
import '../../services/queue_service.dart';

class ActionButtonsWidget extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  final String appointmentId;

  const ActionButtonsWidget({
    super.key,
    required this.appointmentData,
    required this.appointmentId,
  });

  @override
  State<ActionButtonsWidget> createState() => _ActionButtonsWidgetState();
}

class _ActionButtonsWidgetState extends State<ActionButtonsWidget> {
  bool _isLeaving = false;

  void _showLeaveQueueDialog(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      barrierDismissible: !_isLeaving,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.exit_to_app_rounded,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Leave Queue'),
              ],
            ),
            content: const Text(
              'Are you sure you want to leave the queue? You will lose your current position and need to book a new appointment.',
            ),
            actions: [
              TextButton(
                onPressed: _isLeaving ? null : () => Navigator.pop(ctx),
                child: Text(
                  'Keep Position',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isLeaving
                    ? null
                    : () async {
                        HapticFeedback.lightImpact();
                        setStateDialog(() => _isLeaving = true);
                        setState(() => _isLeaving = true);
                        try {
                          final doctorId =
                              widget.appointmentData['doctorId'] as String? ??
                              '';
                          await QueueService().leaveQueue(
                            appointmentId,
                            doctorId: doctorId,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('You left the queue.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Could not leave the queue. Please try again.',
                                ),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLeaving = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLeaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppColors.onError,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Leave Queue'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLeaving
                ? null
                : () => _showLeaveQueueDialog(context, widget.appointmentId),
            icon: const Icon(Icons.exit_to_app_rounded, size: 20),
            label: const Text(
              'Leave Queue',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
