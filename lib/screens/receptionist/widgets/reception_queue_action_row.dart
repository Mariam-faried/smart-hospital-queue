import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';

class ReceptionQueueActionRow extends StatelessWidget {
  final bool canCheckIn;
  final bool canCall;
  final bool canComplete;
  final bool canNoShow;
  final bool isProcessing;
  final VoidCallback? onCheckIn;
  final VoidCallback? onCall;
  final VoidCallback? onComplete;
  final VoidCallback? onNoShow;

  const ReceptionQueueActionRow({
    super.key,
    required this.canCheckIn,
    required this.canCall,
    required this.canComplete,
    required this.canNoShow,
    required this.isProcessing,
    this.onCheckIn,
    this.onCall,
    this.onComplete,
    this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addAction({
      required Key key,
      required IconData icon,
      required String label,
      required Color color,
      required bool visible,
      required VoidCallback? onTap,
    }) {
      if (!visible) return;
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 8));
      }
      children.add(
        Expanded(
          child: _QueueActionButton(
            key: key,
            icon: icon,
            label: label,
            color: color,
            enabled: !isProcessing,
            onTap: onTap,
          ),
        ),
      );
    }

    addAction(
      key: const Key('queue-action-checkin'),
      icon: Icons.how_to_reg,
      label: 'Check In',
      color: AppColors.success,
      visible: canCheckIn,
      onTap: onCheckIn,
    );
    addAction(
      key: const Key('queue-action-call'),
      icon: Icons.campaign,
      label: 'Call',
      color: AppColors.info,
      visible: canCall,
      onTap: onCall,
    );
    addAction(
      key: const Key('queue-action-complete'),
      icon: Icons.check_circle,
      label: 'Complete',
      color: AppColors.success,
      visible: canComplete,
      onTap: onComplete,
    );
    addAction(
      key: const Key('queue-action-noshow'),
      icon: Icons.person_off,
      label: 'No Show',
      color: AppColors.error,
      visible: canNoShow,
      onTap: onNoShow,
    );

    if (children.isEmpty) return const SizedBox.shrink();

    return Row(children: children);
  }
}

class _QueueActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _QueueActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = enabled ? color : AppColors.textSecondary;
    final backgroundColor = enabled
        ? AppColors.statusSurface(color)
        : AppColors.textSecondary.withValues(alpha: 0.08);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? AppColors.statusBorder(color) : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
