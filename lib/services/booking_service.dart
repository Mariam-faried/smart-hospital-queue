import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import 'queue_transition_policy.dart';
import 'queue_service.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../screens/patient/patient_main_screen.dart';

class BookingException implements Exception {
  final String message;
  BookingException(this.message);
  @override
  String toString() => message;
}

enum _BookingFlowErrorCode { slotAlreadyBooked, queueFull }

// Priority surcharge calculation
int _getPrioritySurcharge(String priority) {
  switch (priority) {
    case 'urgent':
      return 50;
    case 'emergency':
      return 100;
    default:
      return 0;
  }
}

int _normalizeConsultationFee(num rawFee) {
  final fee = rawFee.toDouble();
  if (!fee.isFinite || fee <= 0) return 0;
  return fee.toInt();
}

class BookingService {
  BookingException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'aborted':
      case 'already-exists':
      case 'failed-precondition':
        return BookingException(
          'This time slot was just booked by another patient. Please select a different slot.',
        );
      case 'resource-exhausted':
      case 'quota-exceeded':
        return BookingException(
          'This doctor\'s queue is full for today (50 patients). Please choose another doctor or try tomorrow.',
        );
      case 'permission-denied':
        return BookingException(
          'Booking failed due to a permissions issue. Please sign out, sign back in, and try again.',
        );
      default:
        return BookingException(
          'Failed to book appointment. Please try again.',
        );
    }
  }

  Future<void> bookAppointment({
    required BuildContext context,
    required String doctorId,
    required String doctorName,
    required String specialization,
    required num consultationFee,
    required Map<String, dynamic> doctorData,
    required DateTime selectedDay,
    required String selectedTimeSlot,
    required String selectedPatientType,
    required String priority,
    required int avgConsultationTime,
    required String currency,
    required String? appointmentIdToCancel,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      if (user == null) {
        throw BookingException('Please sign in to continue booking.');
      }

      final firestore = FirebaseFirestore.instance;

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final patientName = userDoc.data()?['name'] ?? 'Unknown Patient';

      // ── Pre-flight: verify Firestore security rules will accept this user ──
      final userData = userDoc.data();
      if (!userDoc.exists || userData == null) {
        throw BookingException(
          'Your account data was not found. Please sign out, sign back in, and try again.',
        );
      }
      final userRole = (userData['role'] as String? ?? '').trim().toLowerCase();
      if (userRole != 'patient') {
        throw BookingException(
          'Booking is only available for patient accounts. Your account role is "${userRole.isEmpty ? 'missing' : userRole}".',
        );
      }
      final accountStatus = (userData['accountStatus'] as String? ?? 'active').trim().toLowerCase();
      if (accountStatus == 'suspended' || accountStatus == 'rejected' || accountStatus == 'pending') {
        throw BookingException(
          'Your account is currently "$accountStatus". Please contact support.',
        );
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDay);

      // Pre-compute values needed inside the transaction
      final int feeInt = _normalizeConsultationFee(consultationFee);
      final surcharge = _getPrioritySurcharge(priority);
      final int totalFee = feeInt + surcharge;
      double typeMultiplier = selectedPatientType == 'new'
          ? 1.2
          : selectedPatientType == 'followup'
          ? 0.8
          : 1.0;
      double adjustedAvg = avgConsultationTime * typeMultiplier;
      double noShowRate = (doctorData['noShowRate'] as num?)?.toDouble() ?? 0.1;
      final double normalizedNoShowRate = noShowRate.clamp(0.0, 1.0).toDouble();

      // Pre-generate the appointment document ID
      final appointmentDocRef = firestore.collection('appointments').doc();
      final String appointmentId = appointmentDocRef.id;
      final String slotLockId = _buildSlotLockId(
        doctorId: doctorId,
        date: dateStr,
        timeSlot: selectedTimeSlot,
      );

      // Fast pre-check from patient-readable queue projection.
      // This avoids querying private appointments owned by other patients.
      final queueKey = QueueService.publicQueueKey(
        doctorId: doctorId,
        date: dateStr,
      );
      int observedActiveCount = 0;
      bool hasDuplicateSlot = false;

      try {
        final queueEntries = await firestore
            .collection('queue_public')
            .doc(queueKey)
            .collection('entries')
            .get();

        observedActiveCount = queueEntries.docs.length;
        hasDuplicateSlot = queueEntries.docs.any((doc) {
          final data = doc.data();
          final timeSlot = (data['timeSlot'] as String? ?? '').trim();
          final status = (data['status'] as String? ?? '').trim().toLowerCase();
          return timeSlot == selectedTimeSlot &&
              QueueAppointmentStatus.activeSet.contains(status);
        });
      } on FirebaseException {
        final counterSnapshot = await firestore
            .doc('counters/tickets_${doctorId}_$dateStr')
            .get();
        observedActiveCount =
            (counterSnapshot.data()?['activeCount'] as num?)?.toInt() ?? 0;
      }

      if (hasDuplicateSlot) {
        throw BookingException(
          'This time slot was just booked by another patient. Please select a different slot.',
        );
      }

      int ticketNumber;
      late final Map<String, dynamic> result;

      // Booking transaction
      try {
        result = await firestore.runTransaction<Map<String, dynamic>>((
          transaction,
        ) async {
          // ── Step 1: Check for duplicate slot booking ──────────────────
          final slotLockRef = firestore
              .collection('slot_locks')
              .doc(slotLockId);
          final slotLockSnap = await transaction.get(slotLockRef);
          if (slotLockSnap.exists) {
            return {
              'errorCode': _BookingFlowErrorCode.slotAlreadyBooked.name,
            };
          }

          // ── Step 2: Check max queue cap ───────────────────────────────
          final counterRef = firestore.doc(
            'counters/tickets_${doctorId}_$dateStr',
          );

          final counterSnap = await transaction.get(counterRef);

          final counterData = counterSnap.data();
          final current = (counterData?['lastTicket'] as num?)?.toInt() ?? 0;
          final currentActive =
              (counterData?['activeCount'] as num?)?.toInt() ??
              observedActiveCount;

          if (currentActive >= 50) {
            return {'errorCode': _BookingFlowErrorCode.queueFull.name};
          }

          // ── Step 3: Increment ticket counter ─────────────────────────
          transaction.set(slotLockRef, {
            'appointmentId': appointmentId,
            'doctorId': doctorId,
            'date': dateStr,
            'timeSlot': selectedTimeSlot,
            'lockedAt': FieldValue.serverTimestamp(),
          });

          final next = current + 1;

          transaction.set(counterRef, {
            'lastTicket': next,
            'activeCount': currentActive + 1,
            'doctorId': doctorId,
            'date': dateStr,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // ── Step 4: Create appointment atomically ─────────────────────
          final int patientsAhead = next - 1;
          double effectivePatientsAhead =
              patientsAhead * (1 - normalizedNoShowRate);
          final int estimatedWaitTime =
              ((effectivePatientsAhead * adjustedAvg) * 1.1).round();

          transaction.set(appointmentDocRef, {
            'patientId': user.uid,
            'patientName': patientName,
            'doctorId': doctorId,
            'doctorName': doctorName,
            'specialization': specialization,
            'date': dateStr,
            'timeSlot': selectedTimeSlot,
            'ticketNumber': next,
            'status': QueueAppointmentStatus.waiting,
            'slotLockId': slotLockId,
            'estimatedWaitTime': estimatedWaitTime,
            'queuePosition': patientsAhead + 1,
            'patientsAhead': patientsAhead,
            'createdAt': FieldValue.serverTimestamp(),
            'patientType': selectedPatientType,
            'priority': priority,
            'isEmergency': priority == 'emergency',
            'checkedIn': false,
            'consultationFee': feeInt,
            'prioritySurcharge': surcharge,
            'totalFee': totalFee,
            'currency': currency,
            'paymentStatus': 'pay_at_hospital',
            'paymentMethod': 'pay_at_hospital',
            'paidAt': null,
            'transactionId': null,
            'paymentConfirmationShown': false,
          });

          return {
            'ticketNumber': next,
            'estimatedWaitTime': estimatedWaitTime,
            'patientsAhead': patientsAhead,
          };
        });

        final flowErrorCodeRaw = result['errorCode'] as String?;
        if (flowErrorCodeRaw != null) {
          if (flowErrorCodeRaw == _BookingFlowErrorCode.slotAlreadyBooked.name) {
            throw BookingException(
              'This time slot was just booked by another patient. Please select a different slot.',
            );
          }
          if (flowErrorCodeRaw == _BookingFlowErrorCode.queueFull.name) {
            throw BookingException(
              'This doctor\'s queue is full for today (50 patients). Please choose another doctor or try tomorrow.',
            );
          }
          throw BookingException('Failed to book appointment. Please try again.');
        }

        ticketNumber = (result['ticketNumber'] as num?)?.toInt() ?? 0;
      } on FirebaseException catch (e) {
        throw _mapFirebaseException(e);
      } catch (e) {
        final rawError = e.toString().toLowerCase();
        if (rawError.contains('permission-denied')) {
          throw BookingException(
            'Booking failed due to a permissions issue. Please sign out, sign back in, and try again.',
          );
        }
        if (rawError.contains('already-exists') ||
            rawError.contains('failed-precondition') ||
            rawError.contains('future already completed')) {
          throw BookingException(
            'This time slot was just booked by another patient. Please select a different slot.',
          );
        }
        throw BookingException('Failed to book appointment. Please try again.');
      }
      if (ticketNumber <= 0) {
        throw BookingException('Failed to book appointment. Please try again.');
      }
      final String ticketFormatted =
          'T-${ticketNumber.toString().padLeft(3, '0')}';
      final queueService = QueueService(firestore: firestore);

      try {
        await queueService.syncPublicQueueEntryByAppointmentId(appointmentId);
      } catch (_) {}

      try {
        await queueService.updateQueuePositions(
          doctorId: doctorId,
          date: dateStr,
          completedTicketNumber: 0,
        );
      } catch (_) {}

      if (!context.mounted) return;

      await _createBookingNotification(
        uid: user.uid,
        appointmentId: appointmentId,
        doctorId: doctorId,
        doctorName: doctorName,
        date: dateStr,
        timeSlot: selectedTimeSlot,
        ticketFormatted: ticketFormatted,
      );

      // All appointments use pay at hospital
      if (appointmentIdToCancel != null) {
        try {
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentIdToCancel)
              .update({'status': 'cancelled'});
        } catch (_) {}
      }
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const PatientMainScreen(initialTab: 1),
          ),
          (route) => false,
        );
      }
    } on BookingException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw BookingException(e.toString());
    }
  }

  String _buildSlotLockId({
    required String doctorId,
    required String date,
    required String timeSlot,
  }) {
    final safeSlot = timeSlot.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${doctorId}_${date}_$safeSlot';
  }

  Future<void> _createBookingNotification({
    required String uid,
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String date,
    required String timeSlot,
    required String ticketFormatted,
  }) async {
    try {
      await NotificationService().createPatientNotification(
        uid: uid,
        appointmentId: appointmentId,
        doctorId: doctorId,
        actionTab: 2,
        type: 'booking_confirmed',
        title: 'Appointment confirmed',
        message:
            'Dr. $doctorName on $date at $timeSlot. Ticket $ticketFormatted.',
      );
    } catch (_) {
      // Non-blocking: booking succeeds even if notification write fails.
    }
  }

  // ignore: unused_element
  void _showSuccessBottomSheet({
    required BuildContext context,
    required String doctorName,
    required String date,
    required String timeSlot,
    required String ticketFormatted,
    required int estimatedWaitTime,
    required int totalFee,
    required String currency,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your appointment has been successfully booked.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.person, 'Doctor', 'Dr. $doctorName'),
                    const Divider(height: 20),
                    _infoRow(Icons.calendar_today, 'Date', date),
                    const Divider(height: 20),
                    _infoRow(Icons.access_time, 'Time', timeSlot),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.confirmation_number,
                      'Ticket',
                      ticketFormatted,
                    ),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.timer,
                      'Est. Wait',
                      '$estimatedWaitTime minutes',
                    ),
                    const Divider(height: 20),
                    _infoRow(
                      Icons.payments_outlined,
                      'Total Fee',
                      totalFee == 0 ? 'Free' : '$totalFee $currency',
                      valueColor: totalFee == 0
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.pop(context, true); // Close profile screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
