import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_slot_generator.dart';

class DoctorSchedulePicker extends StatelessWidget {
  final String workingDays;
  final String workingHours;
  final int avgConsultationTime;
  final List<String> bookedSlots;
  final DateTime? selectedDay;
  final String? selectedTimeSlot;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<String> onSlotSelected;
  final String? errorMessage;

  const DoctorSchedulePicker({
    super.key,
    required this.workingDays,
    required this.workingHours,
    required this.avgConsultationTime,
    required this.bookedSlots,
    required this.selectedDay,
    required this.selectedTimeSlot,
    required this.onDateSelected,
    required this.onSlotSelected,
    this.errorMessage,
  });

  List<DateTime> _getNext7WorkingDays() {
    if (workingDays.isEmpty || workingDays.trim().isEmpty) {
      return [];
    }

    final now = DateTime.now();
    final days = <DateTime>[];
    final workingDaySet = _parseWorkingDays();

    for (int i = 0; i < 14 && days.length < 7; i++) {
      final day = now.add(Duration(days: i));
      if (workingDaySet.isEmpty || workingDaySet.contains(day.weekday)) {
        days.add(day);
      }
    }
    return days;
  }

  Set<int> _parseWorkingDays() {
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
    final result = <int>{};
    final lower = workingDays.toLowerCase();

    final rangeParts = lower.split('-').map((s) => s.trim()).toList();
    if (rangeParts.length == 2 &&
        dayMap.containsKey(rangeParts[0]) &&
        dayMap.containsKey(rangeParts[1])) {
      final start = dayMap[rangeParts[0]]!;
      final end = dayMap[rangeParts[1]]!;
      if (start <= end) {
        for (int i = start; i <= end; i++) {
          result.add(i);
        }
      }
      return result;
    }

    for (final part in lower.split(',').map((s) => s.trim())) {
      if (dayMap.containsKey(part)) {
        result.add(dayMap[part]!);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDayPicker(),
          if (selectedDay != null) _buildTimeSlotsGrid(context),
        ],
      ),
    );
  }

  Widget _buildDayPicker() {
    final days = _getNext7WorkingDays();
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(
          'No working days are configured for this doctor.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected =
              selectedDay != null &&
              selectedDay!.year == day.year &&
              selectedDay!.month == day.month &&
              selectedDay!.day == day.day;
          final isToday =
              day.year == DateTime.now().year &&
              day.month == DateTime.now().month &&
              day.day == DateTime.now().day;

          final hasAppointments =
              bookedSlots.isNotEmpty &&
              selectedDay != null &&
              day.year == selectedDay!.year &&
              day.month == selectedDay!.month &&
              day.day == selectedDay!.day;

          return GestureDetector(
            onTap: () => onDateSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 68,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.divider,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.onPrimary.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.onPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthNames[day.month - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? AppColors.onPrimary.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (hasAppointments)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.onPrimary
                            : AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlotsGrid(BuildContext context) {
    final allSlots = generateTimeSlots(
      workingHours: workingHours,
      avgConsultationTime: avgConsultationTime,
      selectedDay: selectedDay ?? DateTime.now(),
      bookedSlots: bookedSlots,
    );
    final bookedSlotSet = bookedSlots.toSet();
    final availableSlotsCount = allSlots
        .where((slot) => !bookedSlotSet.contains(slot))
        .length;
    if (allSlots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'No available slots for this date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All slots are booked or unavailable.\nPlease try another date.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Available Time Slots',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$availableSlotsCount available',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Legend
          Row(
            children: [
              _buildLegendItem(AppColors.primary, 'Selected'),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.divider, 'Booked'),
              const SizedBox(width: 16),
              _buildLegendItem(
                AppColors.cardBackground,
                'Available',
                hasBorder: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, // horizontal gap
            runSpacing: 8, // vertical gap
            children: allSlots.map((slot) {
              final isBooked = bookedSlotSet.contains(slot);
              final isSelected = selectedTimeSlot == slot;
              // Each item takes exactly 1/3 of width (20 padding on each side, 8 spacing x 2 = 56 total horizontal space)
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                child: InkWell(
                  onTap: isBooked ? null : () => onSlotSelected(slot),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isBooked
                          ? AppColors.divider
                          : isSelected
                          ? AppColors.primary
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBooked
                            ? AppColors.textSecondary.withValues(alpha: 0.3)
                            : isSelected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isBooked
                              ? AppColors.textSecondary
                              : isSelected
                              ? AppColors.onPrimary
                              : AppColors.textPrimary,
                          decoration: isBooked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: hasBorder
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
