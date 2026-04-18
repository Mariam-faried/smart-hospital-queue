import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class DoctorScheduleHeader extends StatelessWidget {
  final int avgConsultationTime;
  final String workingHours;
  final String workingDays;

  const DoctorScheduleHeader({
    super.key,
    required this.avgConsultationTime,
    required this.workingHours,
    required this.workingDays,
  });

  String _getNextAvailableLabel() {
    final dayMap = {
      'mon': 1,
      'tue': 2,
      'wed': 3,
      'thu': 4,
      'fri': 5,
      'sat': 6,
      'sun': 7,
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    final dayNames = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    // Parse working days
    final workingDaySet = <int>{};
    final lower = workingDays.toLowerCase();

    final rangeParts = lower.split('-').map((s) => s.trim()).toList();
    if (rangeParts.length == 2 &&
        dayMap.containsKey(rangeParts[0]) &&
        dayMap.containsKey(rangeParts[1])) {
      final start = dayMap[rangeParts[0]]!;
      final end = dayMap[rangeParts[1]]!;
      if (start <= end) {
        for (int i = start; i <= end; i++) {
          workingDaySet.add(i);
        }
      }
    } else {
      for (final part in lower.split(',').map((s) => s.trim())) {
        if (dayMap.containsKey(part)) workingDaySet.add(dayMap[part]!);
      }
    }

    if (workingDaySet.isEmpty) { return 'Next available: Today from $workingHours'; }

    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
      if (workingDaySet.contains(day.weekday)) {
        if (i == 0) return 'Next available: Today from $workingHours';
        if (i == 1) return 'Next available: Tomorrow from $workingHours';
        return 'Next available: ${dayNames[day.weekday]} from $workingHours';
      }
    }
    return 'Next available: $workingHours';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Schedule Appointment',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$avgConsultationTime min/slot',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  _getNextAvailableLabel(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
