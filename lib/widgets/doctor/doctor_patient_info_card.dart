import 'package:flutter/material.dart';
import '../../models/appointment_model.dart';
import '../../utils/app_colors.dart';

class DoctorPatientInfoCard extends StatelessWidget {
  final AppointmentModel appointment;

  const DoctorPatientInfoCard({super.key, required this.appointment});

  String _readableLabel(String value) {
    final normalized = value.trim().replaceAll('_', ' ').replaceAll('-', ' ');
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(
                  appointment.patientName.isNotEmpty
                      ? appointment.patientName[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Priority: ${_readableLabel(appointment.priority)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: appointment.priority == 'emergency'
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontWeight: appointment.priority == 'emergency'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(
            Icons.receipt_long,
            'Ticket',
            appointment.formattedTicketNumber,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            _paymentIcon(appointment.paymentStatus),
            'Payment',
            _paymentLabel(appointment.paymentStatus),
            iconColor: _paymentColor(appointment.paymentStatus),
            valueColor: _paymentColor(appointment.paymentStatus),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.access_time, 'Time Slot', appointment.timeSlot),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _paymentLabel(String status) {
    final normalized = status.trim().toLowerCase();
    if (normalized == 'pay_at_hospital') return 'Pay at Hospital';
    return _readableLabel(status);
  }

  IconData _paymentIcon(String status) {
    return status.trim().toLowerCase() == 'pay_at_hospital'
        ? Icons.local_hospital_outlined
        : Icons.payment;
  }

  Color _paymentColor(String status) {
    return status.trim().toLowerCase() == 'pay_at_hospital'
        ? AppColors.info
        : AppColors.textPrimary;
  }
}
