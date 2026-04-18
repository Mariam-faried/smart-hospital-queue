import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:intl/intl.dart';
import '../../services/queue_service.dart';
import '../../services/queue_transition_policy.dart';
import 'doctor_profile_screen.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

class AppointmentDetailsScreen extends StatelessWidget {
  final String appointmentId;
  final Map<String, dynamic> appointmentData;
  final Map<String, dynamic> doctorData;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointmentId,
    required this.appointmentData,
    required this.doctorData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> currentData = appointmentData;
        if (snapshot.hasData && snapshot.data!.exists) {
          currentData =
              snapshot.data!.data() as Map<String, dynamic>? ?? appointmentData;
        }

        final doctorName =
            doctorData['name'] ?? currentData['doctorName'] ?? 'Unknown Doctor';
        final spec =
            doctorData['specialization'] ??
            currentData['specialization'] ??
            'Specialist';
        final date = currentData['date'] ?? 'Unknown Date';
        final timeSlot = currentData['timeSlot'] ?? 'Unknown Time';
        final status = currentData['status'] ?? 'unknown';
        final tNum = currentData['ticketNumber'] ?? 0;
        final String ticketStr = AppFormatters.formatTicket(tNum);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Appointment Details'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Doctor Info
                Center(
                  child: Hero(
                    tag: 'doc_avatar_$appointmentId',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl:
                              doctorData['imageUrl'] ??
                              currentData['imageUrl'] ??
                              '',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.divider,
                            child: const Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  doctorName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  spec,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Date & Time Card
                Card(
                  elevation: 0,
                  color: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildInfoColumn(
                                Icons.calendar_today,
                                'Date',
                                date,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_calendar,
                                color: AppColors.primary,
                              ),
                              tooltip: 'Add to Calendar',
                              onPressed: () {
                                DateTime startDate = DateTime.now();
                                try {
                                  final parsedDate = DateTime.tryParse(date);
                                  if (parsedDate != null) {
                                    DateTime? parsedTime;
                                    try {
                                      parsedTime = DateFormat(
                                        'hh:mm a',
                                      ).parse(timeSlot.trim().toUpperCase());
                                    } catch (_) {
                                      try {
                                        parsedTime = DateFormat(
                                          'h:mm a',
                                        ).parse(timeSlot.trim().toUpperCase());
                                      } catch (_) {}
                                    }
                                    if (parsedTime != null) {
                                      startDate = DateTime(
                                        parsedDate.year,
                                        parsedDate.month,
                                        parsedDate.day,
                                        parsedTime.hour,
                                        parsedTime.minute,
                                      );
                                    }
                                  }
                                } catch (_) {
                                  // Fall back to current time if parsing fails.
                                }

                                final Event event = Event(
                                  title: 'Appointment with $doctorName',
                                  description:
                                      'Smart Hospital Appointment - $spec consultation.\nStatus: $status\nTicket: $ticketStr',
                                  startDate: startDate,
                                  endDate: startDate.add(
                                    const Duration(minutes: 30),
                                  ),
                                  iosParams: const IOSParams(
                                    reminder: Duration(minutes: 60),
                                  ),
                                  androidParams: const AndroidParams(
                                    emailInvites: [],
                                  ),
                                );

                                Add2Calendar.addEvent2Cal(event);
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoColumn(Icons.access_time, 'Time', timeSlot),
                        const Divider(height: 24),
                        _buildInfoColumn(Icons.info_outline, 'Status', status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payment and Fee Info
                _buildPaymentCard(currentData: currentData),
                const SizedBox(height: 24),

                // Pre-visit Instructions
                _buildInstructionsCard(),
                const SizedBox(height: 24),

                // QR Code Section
                if (status == 'waiting') ...[
                  const Text(
                    'Show this code at reception',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: appointmentId,
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticketStr,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons Section
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _cancelAppointment(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text(
                            'Reschedule',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _rescheduleAppointment(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard({required Map<String, dynamic> currentData}) {
    final paymentStatusRaw = currentData['paymentStatus'] as String? ?? '';
    final paymentStatus = paymentStatusRaw.trim().toLowerCase();
    final totalFee = (currentData['totalFee'] as num?)?.toInt() ?? 0;
    final currency = currentData['currency'] as String? ?? 'EGP';
    final transactionId = currentData['transactionId'] as String?;

    String badgeText = 'Pay at Hospital';
    Color badgeColor = AppColors.info;
    IconData badgeIcon = Icons.local_hospital_outlined;

    if (totalFee == 0 || paymentStatus == 'free') {
      badgeText = 'No Payment Required';
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle;
    } else if (paymentStatus == 'paid') {
      badgeText = 'Paid';
      badgeColor = AppColors.success;
      badgeIcon = Icons.check_circle;
    } else if (paymentStatus.isNotEmpty && paymentStatus != 'pay_at_hospital') {
      badgeText = _readablePaymentStatus(paymentStatusRaw);
      badgeColor = AppColors.textSecondary;
      badgeIcon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consultation Fee',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                totalFee == 0 ? 'Free' : '$totalFee $currency',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusSurface(badgeColor),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.statusBorder(badgeColor)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalFee > 0) ...[
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(
                  Icons.local_hospital_outlined,
                  size: 16,
                  color: AppColors.info,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please pay at the reception before your consultation.',
                    style: TextStyle(fontSize: 13, color: AppColors.info),
                  ),
                ),
              ],
            ),
            if (paymentStatus.isNotEmpty && paymentStatus != 'pay_at_hospital')
              const SizedBox(height: 10),
            if (paymentStatus.isNotEmpty && paymentStatus != 'pay_at_hospital')
              Text(
                'Current saved status: ${_readablePaymentStatus(paymentStatusRaw)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
          if (paymentStatus == 'paid' &&
              totalFee > 0 &&
              transactionId != null &&
              transactionId.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaction ID',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  transactionId,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _readablePaymentStatus(String value) {
    final normalized = value.trim().replaceAll('_', ' ').replaceAll('-', ' ');
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-visit Instructions',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBulletPoint(
                  'Please arrive 15 minutes before your scheduled appointment.',
                ),
                const SizedBox(height: 4),
                _buildBulletPoint(
                  'Bring your National ID and insurance card if applicable.',
                ),
                const SizedBox(height: 4),
                _buildBulletPoint(
                  'Use the QR code below at the reception kiosk to check in automatically.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '- ',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.info,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: AppColors.info, height: 1.5),
          ),
        ),
      ],
    );
  }

  Future<void> _cancelAppointment(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final doctorId = appointmentData['doctorId'] as String? ?? '';
        if (doctorId.isEmpty) {
          throw StateError('Doctor ID not found for this appointment.');
        }

        await QueueService().markAppointmentStatus(
          appointmentId,
          doctorId,
          QueueAppointmentStatus.cancelled,
        );
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({'cancellationReason': 'Cancelled by patient'});

        if (context.mounted) {
          Navigator.pop(context); // close loading
          Navigator.pop(context); // close screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          Navigator.pop(context); // close loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not cancel appointment. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _rescheduleAppointment(BuildContext context) async {
    final doctorId = appointmentData['doctorId'];
    if (doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor information is unavailable.')),
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reschedule Appointment'),
        content: const Text(
          'You will be redirected to the doctor\'s profile to book a new time slot. '
          'Your current appointment will be automatically cancelled after a successful booking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Proceed to Book',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .get();
      if (context.mounted) {
        Navigator.pop(context); // close loading
        if (doc.exists) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorProfileScreen(
                doctorId: doctorId,
                doctorData: doc.data() as Map<String, dynamic>,
                appointmentIdToCancel: appointmentId,
              ),
            ),
          );
          if (result == true && context.mounted) {
            Navigator.pop(
              context,
            ); // Close details screen to return to list since old appointment is cancelled
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor profile could not be found.')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open doctor profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
