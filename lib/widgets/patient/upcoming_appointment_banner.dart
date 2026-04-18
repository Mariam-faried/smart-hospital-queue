import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/queue_transition_policy.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';
import '../../screens/patient/book_appointment_screen.dart';
import '../../screens/patient/appointment_details_screen.dart';
import 'greeting_header.dart'; // for getStatusColor

class UpcomingAppointmentBanner extends StatefulWidget {
  final String uid;
  final Animation<double> bannerFade;
  final Animation<Offset> bannerSlide;

  const UpcomingAppointmentBanner({
    super.key,
    required this.uid,
    required this.bannerFade,
    required this.bannerSlide,
  });

  @override
  State<UpcomingAppointmentBanner> createState() =>
      _UpcomingAppointmentBannerState();
}

class _UpcomingAppointmentBannerState extends State<UpcomingAppointmentBanner> {
  String _formatStreamError(Object? error) {
    if (error is FirebaseException) {
      final code = error.code.trim().isEmpty ? 'firebase-error' : error.code;
      final message = (error.message ?? '').trim();
      return message.isEmpty ? code : '$code: $message';
    }
    return error?.toString() ?? 'Unknown stream error';
  }

  String _readText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final normalized = value is String ? value.trim() : value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  DateTime? _parseAppointmentDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  DateTime _appointmentSortKey(Map<String, dynamic> data) {
    final date = _parseAppointmentDate(data['date']);
    if (date == null) {
      return DateTime(9999, 1, 1);
    }
    final timeSlot = _readText(data['timeSlot']);
    final parsedTime = timeSlot.isEmpty
        ? null
        : TimeUtils.parseTimeSlot(timeSlot, baseDate: date);
    if (parsedTime != null) {
      return parsedTime;
    }
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  String _readableQueueStatus(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('_', '-') ?? '';
    switch (normalized) {
      case QueueAppointmentStatus.inProgress:
        return 'IN PROGRESS';
      case QueueAppointmentStatus.confirmed:
        return 'CONFIRMED';
      case QueueAppointmentStatus.completed:
        return 'COMPLETED';
      case QueueAppointmentStatus.cancelled:
        return 'CANCELLED';
      case QueueAppointmentStatus.noShow:
        return 'NO SHOW';
      case QueueAppointmentStatus.waiting:
      default:
        return 'WAITING';
    }
  }

  void _openAppointmentDetails({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailsScreen(
          appointmentId: appointmentId,
          appointmentData: appointmentData,
          doctorData: const {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: FadeTransition(
        opacity: widget.bannerFade,
        child: SlideTransition(
          position: widget.bannerSlide,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientId', isEqualTo: widget.uid)
                .where('status', whereIn: QueueAppointmentStatus.activeList)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final errorDetails = _formatStreamError(snapshot.error);
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Unable to load appointment. Please try again.',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              errorDetails,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Loading your next appointment...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Upcoming Appointments',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Book a new appointment to get started',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BookAppointmentScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Book Now'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  return _appointmentSortKey(
                    aData,
                  ).compareTo(_appointmentSortKey(bData));
                });

              final nextApptUrl = docs.first;
              final data = nextApptUrl.data() as Map<String, dynamic>;

              final doctorName = _readText(
                data['doctorName'],
                fallback: 'Doctor',
              );
              final parsedDate = _parseAppointmentDate(data['date']);
              final date = _readText(data['date']);
              final timeSlot = _readText(data['timeSlot']);
              final totalFee = (data['totalFee'] as num?)?.toInt() ?? 0;
              final paymentStatusRaw = data['paymentStatus'] as String? ?? '';
              final paymentStatus = paymentStatusRaw.trim().toLowerCase();

              final formattedDate = parsedDate == null
                  ? date
                  : DateFormat('MMM d, yyyy').format(parsedDate);

              final displayInfo = timeSlot.isNotEmpty
                  ? '$formattedDate - $timeSlot'
                  : formattedDate;

              String badgeLabel;
              Color badgeColor;
              IconData badgeIcon;
              if (totalFee == 0 || paymentStatus == 'free') {
                badgeLabel = 'No Payment';
                badgeColor = AppColors.success;
                badgeIcon = Icons.check_circle_outline;
              } else if (paymentStatus.isEmpty ||
                  paymentStatus == 'pay_at_hospital') {
                badgeLabel = 'Pay at Hospital';
                badgeColor = AppColors.info;
                badgeIcon = Icons.local_hospital_outlined;
              } else if (paymentStatus == 'paid') {
                badgeLabel = 'Paid';
                badgeColor = AppColors.success;
                badgeIcon = Icons.check_circle_outline;
              } else if (paymentStatus == 'pending' ||
                  paymentStatus == 'unpaid') {
                badgeLabel = 'Payment Pending';
                badgeColor = AppColors.warning;
                badgeIcon = Icons.pending_actions_outlined;
              } else if (paymentStatus == 'failed' ||
                  paymentStatus == 'declined') {
                badgeLabel = 'Payment Failed';
                badgeColor = AppColors.error;
                badgeIcon = Icons.error_outline;
              } else {
                badgeLabel = _readablePaymentStatus(paymentStatusRaw);
                badgeColor = AppColors.textSecondary;
                badgeIcon = Icons.info_outline;
              }
              final statusColor = GreetingHeader.getStatusColor(data['status']);

              return InkWell(
                onTap: () => _openAppointmentDetails(
                  appointmentId: nextApptUrl.id,
                  appointmentData: data,
                ),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color:
                        AppColors.cardBackground, // pure white — no cream bleed
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upcoming Appointment',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                alignment: WrapAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusSurface(
                                        statusColor,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.statusBorder(
                                          statusColor,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _readableQueueStatus(
                                        data['status'] as String?,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusSurface(
                                        badgeColor,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.statusBorder(
                                          badgeColor,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          badgeIcon,
                                          size: 12,
                                          color: badgeColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.cardBackground,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.calendar_month,
                                color: AppColors.primary,
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayInfo,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (paymentStatus.isNotEmpty &&
                                      paymentStatus != 'pay_at_hospital' &&
                                      paymentStatus != 'free')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Payment: ${_readablePaymentStatus(paymentStatusRaw)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.chevron_right,
                                color: AppColors.primaryDark,
                              ),
                              onPressed: () => _openAppointmentDetails(
                                appointmentId: nextApptUrl.id,
                                appointmentData: data,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
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
}
