import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class BookingBottomBar extends StatelessWidget {
  final DateTime? selectedDay;
  final String? selectedTimeSlot;
  final bool isBooking;
  final bool isCheckingSlot;
  final String selectedPatientType;
  final ValueChanged<String> onPatientTypeChanged;
  final VoidCallback onBookPressed;

  final bool isAvailable;

  const BookingBottomBar({
    super.key,
    required this.selectedDay,
    required this.selectedTimeSlot,
    required this.isBooking,
    required this.isCheckingSlot,
    required this.selectedPatientType,
    required this.onPatientTypeChanged,
    required this.onBookPressed,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final canBook =
        isAvailable &&
        !isBooking &&
        !isCheckingSlot &&
        selectedDay != null &&
        selectedTimeSlot != null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: const Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Patient Type Selector
            _buildPatientTypeSelector(
              interactionsEnabled: !isBooking && !isCheckingSlot,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canBook ? onBookPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canBook
                      ? AppColors.primary
                      : AppColors.divider,
                  foregroundColor: canBook
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: canBook ? 2 : 0,
                ),
                child: isBooking || isCheckingSlot
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCheckingSlot
                                ? Icons.hourglass_top_rounded
                                : (canBook
                                      ? Icons.check_circle_outline
                                      : Icons.lock_clock),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            !isAvailable
                                ? 'Doctor Unavailable'
                                : isCheckingSlot
                                ? 'Checking Availability...'
                                : canBook
                                ? 'Book Appointment'
                                : 'Select a Date & Time',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientTypeSelector({required bool interactionsEnabled}) {
    final types = [
      {'value': 'new', 'label': 'New'},
      {'value': 'returning', 'label': 'Returning'},
      {'value': 'followup', 'label': 'Follow-up'},
    ];

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: types.map((type) {
          final isSelected = selectedPatientType == type['value'];
          return Expanded(
            child: GestureDetector(
              onTap: interactionsEnabled
                  ? () => onPatientTypeChanged(type['value']!)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.cardBackground.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    type['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.onPrimary
                          : (interactionsEnabled
                                ? AppColors.primary
                                : AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
