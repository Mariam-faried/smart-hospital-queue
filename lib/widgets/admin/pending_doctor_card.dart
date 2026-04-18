import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../services/notification_service.dart';

class PendingDoctorCard extends StatelessWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  static final NotificationService _notificationService = NotificationService();

  const PendingDoctorCard({
    super.key,
    required this.doctorId,
    required this.doctorData,
  });

  Future<void> _approveDoctor(BuildContext context) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final approvedBy = FirebaseAuth.instance.currentUser?.uid;

      // Update doctor document
      batch.update(
        FirebaseFirestore.instance.collection('doctors').doc(doctorId),
        {
          'accountStatus': 'approved',
          'isAvailable': true,
          'currentState': 'available',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': approvedBy,
        },
      );

      // Update user document
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(doctorId),
        {'accountStatus': 'active'},
      );

      await batch.commit();

      try {
        await _notificationService.createPatientNotification(
          uid: doctorId,
          title: 'Account Approved',
          message:
              'Your doctor account has been approved. You can now receive bookings.',
          type: 'account_update',
          metadata: <String, dynamic>{
            'status': 'approved',
            'doctorId': doctorId,
            'reviewedBy': approvedBy,
          },
        );
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor approved.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not approve doctor. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectDoctor(BuildContext context) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Doctor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject Dr. ${doctorData['name']}? This action cannot be undone.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Add optional rejection reason',
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();

    if (reason == null) return;
    final normalizedReason = reason.trim();

    try {
      final batch = FirebaseFirestore.instance.batch();
      final rejectedAt = FieldValue.serverTimestamp();
      final rejectedBy = FirebaseAuth.instance.currentUser?.uid;

      // Update doctor document
      batch.update(
        FirebaseFirestore.instance.collection('doctors').doc(doctorId),
        {
          'accountStatus': 'rejected',
          'rejectedAt': rejectedAt,
          'rejectedBy': rejectedBy,
          if (normalizedReason.isNotEmpty) 'rejectedReason': normalizedReason,
        },
      );

      // Update user document
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(doctorId),
        {
          'accountStatus': 'rejected',
          if (normalizedReason.isNotEmpty)
            'lastRejectionReason': normalizedReason,
        },
      );

      await batch.commit();

      try {
        await _notificationService.createPatientNotification(
          uid: doctorId,
          title: 'Account Rejected',
          message: normalizedReason.isEmpty
              ? 'Your doctor account request was rejected. Please contact administration for details.'
              : 'Your doctor account request was rejected. Reason: $normalizedReason',
          type: 'account_update',
          metadata: <String, dynamic>{
            'status': 'rejected',
            'doctorId': doctorId,
            'reason': normalizedReason,
            'reviewedBy': rejectedBy,
          },
        );
      } catch (_) {}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor rejected.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reject doctor. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawName = doctorData['name'];
    final doctorName = rawName is String
        ? rawName.trim()
        : rawName?.toString().trim() ?? '';
    final rawSpecialization = doctorData['specialization'];
    final specialization = rawSpecialization is String
        ? rawSpecialization.trim()
        : rawSpecialization?.toString().trim() ?? '';
    final rawQualification = doctorData['qualification'];
    final qualification = rawQualification is String
        ? rawQualification.trim()
        : rawQualification?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    doctorName.isNotEmpty ? doctorName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctorName.isNotEmpty ? doctorName : 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialization.isEmpty ? 'N/A' : specialization,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        qualification.isEmpty ? 'N/A' : qualification,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Details
            _buildDetailRow(Icons.email, doctorData['email'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.phone, doctorData['phone'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.work_outline,
              '${doctorData['experience'] ?? 0} years experience',
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectDoctor(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveDoctor(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.onSuccess,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
