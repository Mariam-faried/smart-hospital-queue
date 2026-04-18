import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class QueueProgressWidget extends StatelessWidget {
  final Animation<double> stepperAnimation;
  final Map<String, dynamic> appointmentData;

  const QueueProgressWidget({
    super.key,
    required this.stepperAnimation,
    required this.appointmentData,
  });

  int _getStepperIndex(Map<String, dynamic> data) {
    final status =
        data['status']?.toString().trim().toLowerCase().replaceAll('_', '-') ??
        'waiting';
    final checkedIn = data['checkedIn'] == true;
    final pAhead = (data['patientsAhead'] as num?)?.toInt() ?? 0;
    final isInProgress = status == 'in-progress' || status == 'called';
    final isWaitingFlow = status == 'waiting' || status == 'confirmed';

    if (isInProgress) return 3;
    if (pAhead == 0 && isWaitingFlow) return 2;
    if (checkedIn || status == 'confirmed') return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _getStepperIndex(appointmentData);
    final steps = const [
      _StepData(Icons.login_rounded, 'Check In'),
      _StepData(Icons.hourglass_top_rounded, 'Waiting'),
      _StepData(Icons.notifications_active_rounded, 'Your Turn'),
      _StepData(Icons.medical_services_rounded, 'Consultation'),
    ];

    return AnimatedBuilder(
      animation: stepperAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: stepperAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - stepperAnimation.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: List.generate(steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepBefore = i ~/ 2;
              final isCompleted = stepBefore < currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: isCompleted
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.success],
                          )
                        : null,
                    color: isCompleted ? null : AppColors.divider,
                  ),
                ),
              );
            }

            final stepIndex = i ~/ 2;
            final step = steps[stepIndex];
            final isActive = stepIndex == currentStep;
            final isCompleted = stepIndex < currentStep;

            return _buildStepIcon(step, isActive, isCompleted);
          }),
        ),
      ),
    );
  }

  Widget _buildStepIcon(_StepData step, bool isActive, bool isCompleted) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          width: isActive ? 46 : 36,
          height: isActive ? 46 : 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.primary
                : isCompleted
                ? AppColors.success
                : AppColors.background,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : step.icon,
            color: (isActive || isCompleted)
                ? AppColors.onPrimary
                : AppColors.textSecondary.withValues(alpha: 0.6),
            size: isActive ? 22 : 18,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          step.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? AppColors.primary
                : isCompleted
                ? AppColors.success
                : AppColors.textSecondary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _StepData {
  final IconData icon;
  final String label;
  const _StepData(this.icon, this.label);
}
