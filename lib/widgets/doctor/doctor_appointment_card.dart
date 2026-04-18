import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

class DoctorAppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback onTap;

  const DoctorAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });

  String _statusLabel(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return 'UNKNOWN';
    return normalized.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
  }

  String _normalizedStatus(String status) {
    return status.trim().toLowerCase().replaceAll('_', '-');
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText = _statusLabel(appointment.status);
    switch (_normalizedStatus(appointment.status)) {
      case 'waiting':
        statusColor = AppColors.warning;
        break;
      case 'confirmed':
      case 'in-progress':
        statusColor = AppColors.info;
        break;
      case 'completed':
        statusColor = AppColors.success;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      case 'no-show':
        statusColor = AppColors.statusNoShow;
        break;
      default:
        statusColor = AppColors.statusNoShow;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                AppFormatters.formatTicketString(appointment.ticketNumber),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.patientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        appointment.timeSlot,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.statusSurface(statusColor),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.statusBorder(statusColor)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
