import 'package:flutter/material.dart';
import 'countdown_timer_widget.dart';
import '../../utils/app_colors.dart';

class QueueStatsWidget extends StatelessWidget {
  final int patientsAhead;
  final int estimatedWaitTime;
  final bool isPaused;

  const QueueStatsWidget({
    super.key,
    required this.patientsAhead,
    required this.estimatedWaitTime,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  (patientsAhead == 0 ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    (patientsAhead == 0 ? AppColors.success : AppColors.primary)
                        .withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  patientsAhead == 0
                      ? Icons.celebration_rounded
                      : Icons.people_rounded,
                  color: patientsAhead == 0
                      ? AppColors.success
                      : AppColors.primary,
                  size: 28,
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    patientsAhead == 0 ? 'Your Turn!' : '$patientsAhead',
                    key: ValueKey(patientsAhead),
                    style: TextStyle(
                      fontSize: patientsAhead == 0 ? 16 : 20,
                      fontWeight: FontWeight.bold,
                      color: patientsAhead == 0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                ),
                if (patientsAhead > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Patients Ahead',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: CountdownTimerWidget(
            totalMinutes: estimatedWaitTime,
            isPaused: isPaused,
          ),
        ),
      ],
    );
  }
}
