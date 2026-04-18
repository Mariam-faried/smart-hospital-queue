import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import 'payment_info_row.dart';
import '../../screens/patient/appointment_details_screen.dart';

class AppointmentCard extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> data;
  final bool isUpcoming;
  final Map<String, dynamic>? doctorData;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback onCompletePayment;

  const AppointmentCard({
    super.key,
    required this.appointmentId,
    required this.data,
    required this.isUpcoming,
    required this.doctorData,
    required this.onCancel,
    required this.onReschedule,
    required this.onCompletePayment,
  });

  @override
  Widget build(BuildContext context) {
    String? fetchedDoctorName = doctorData?['name'];
    String? fetchedSpecialization = doctorData?['specialization'];

    final doctorName =
        fetchedDoctorName ?? data['doctorName'] ?? 'Unknown Doctor';
    final spec =
        fetchedSpecialization ?? data['specialization'] ?? 'Specialist';
    final date = data['date'] ?? 'Unknown Date';
    final timeSlot = data['timeSlot'] ?? 'Unknown Time';
    final status = data['status'] ?? 'unknown';
    final tNum = data['ticketNumber'] ?? 0;
    final patientType = data['patientType'] as String?;
    final cancellationReason = data['cancellationReason'] as String?;

    final statusColor = _getStatusColor(status);
    final cardBgColor = (isUpcoming && status == 'waiting')
        ? AppColors.background
        : AppColors.cardBackground;

    return Slidable(
      key: ValueKey(appointmentId),
      enabled: isUpcoming && status == 'waiting',
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onReschedule(),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.cardBackground,
            icon: Icons.edit_calendar,
            label: 'Reschedule',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          SlidableAction(
            onPressed: (_) => onCancel(),
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.cardBackground,
            icon: Icons.cancel_outlined,
            label: 'Cancel',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppointmentDetailsScreen(
                appointmentId: appointmentId,
                appointmentData: data,
                doctorData: doctorData ?? {},
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Container(
                  color: cardBgColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DoctorInfoRow(
                        data: data,
                        doctorData: doctorData,
                        doctorName: doctorName,
                        spec: spec,
                        status: status,
                        statusColor: statusColor,
                        isUpcoming: isUpcoming,
                      ),
                      const SizedBox(height: 16),
                      _DateTimeRow(date: date, timeSlot: timeSlot),
                      const SizedBox(height: 16),
                      _TicketRow(
                        ticketNumber: tNum,
                        isUpcoming: isUpcoming,
                        patientType: patientType,
                      ),
                      if (status == 'cancelled' &&
                          cancellationReason != null &&
                          cancellationReason.isNotEmpty)
                        _CancellationReason(reason: cancellationReason),
                      PaymentInfoRow(
                        data: data,
                        onCompletePayment: onCompletePayment,
                      ),
                    ],
                  ),
                ),
                if (isUpcoming && status == 'waiting') const _SwipeHintRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s.toLowerCase()) {
      case 'waiting':
        return AppColors.statusWaiting;
      case 'in-progress':
        return AppColors.statusInProgress;
      case 'completed':
        return AppColors.statusCompleted;
      case 'cancelled':
      case 'no-show':
        return AppColors.statusCancelled;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _DoctorInfoRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? doctorData;
  final String doctorName;
  final String spec;
  final String status;
  final Color statusColor;
  final bool isUpcoming;

  const _DoctorInfoRow({
    required this.data,
    required this.doctorData,
    required this.doctorName,
    required this.spec,
    required this.status,
    required this.statusColor,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    String? imageUrl = doctorData?['imageUrl'];
    final statusTextColor = statusColor;
    final statusBgColor = AppColors.statusSurface(statusColor);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBackground, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: imageUrl ?? data['imageUrl'] ?? '',
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 56,
                height: 56,
                color: AppColors.cardBackground,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 56,
                height: 56,
                color: AppColors.cardBackground,
                child: Center(
                  child: Text(
                    doctorName
                        .trim()
                        .split(' ')
                        .where((e) => e.isNotEmpty)
                        .take(2)
                        .map((e) => e[0].toUpperCase())
                        .join(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctorName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.statusBorder(statusTextColor),
                ),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusTextColor,
                  fontSize: 11,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isUpcoming && data['patientsAhead'] != null) ...[
              const SizedBox(height: 6),
              Text(
                '${data['patientsAhead']} ahead',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  final String date;
  final String timeSlot;

  const _DateTimeRow({required this.date, required this.timeSlot});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              date,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(
              Icons.access_time_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              timeSlot,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TicketRow extends StatelessWidget {
  final dynamic ticketNumber;
  final bool isUpcoming;
  final String? patientType;

  const _TicketRow({
    required this.ticketNumber,
    required this.isUpcoming,
    required this.patientType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.confirmation_number_outlined,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        Text(
          'Ticket: ${AppFormatters.formatTicket(ticketNumber)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        if (!isUpcoming && patientType != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.tertiary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              patientType == 'followup'
                  ? 'Follow-up'
                  : patientType == 'returning'
                  ? 'Returning'
                  : 'New Patient',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.tertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _CancellationReason extends StatelessWidget {
  final String reason;

  const _CancellationReason({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reason for cancellation:',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHintRow extends StatelessWidget {
  const _SwipeHintRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.swipe_left,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            'Swipe left to manage appointment',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
