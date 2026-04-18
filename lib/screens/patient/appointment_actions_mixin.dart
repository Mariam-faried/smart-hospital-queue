import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/queue_service.dart';
import '../../services/queue_transition_policy.dart';
import 'doctor_profile_screen.dart';
import '../../utils/app_colors.dart';

mixin AppointmentActionsMixin<T extends StatefulWidget> on State<T> {
  Future<void> cancelAppointment(
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
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
      try {
        final doctorId = data['doctorId'] as String? ?? '';
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

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled.')),
          );
        }
      } catch (_) {
        if (mounted) {
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

  void rescheduleAppointment(
    String appointmentId,
    String? doctorId,
    Map<String, dynamic>? cachedDoctorData,
  ) {
    if (doctorId != null) {
      FirebaseFirestore.instance.collection('doctors').doc(doctorId).get().then(
        (doc) {
          if (doc.exists && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DoctorProfileScreen(
                  doctorId: doctorId,
                  doctorData: doc.data() as Map<String, dynamic>,
                  appointmentIdToCancel: appointmentId,
                ),
              ),
            );
          }
        },
      );
    }
  }

  Future<void> completePayment(
    String appointmentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'paymentStatus': 'pay_at_hospital',
            'paymentMethod': 'pay_at_hospital',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment method set to Pay at Hospital.'),
          backgroundColor: AppColors.info,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update payment method. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

