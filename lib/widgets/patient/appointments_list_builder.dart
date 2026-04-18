import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_colors.dart';
import 'appointment_card.dart';
import '../../screens/patient/book_appointment_screen.dart';

class AppointmentsListBuilder extends StatefulWidget {
  final Stream<List<QueryDocumentSnapshot>>? stream;
  final List<String> statuses;
  final String emptyMsg;
  final IconData emptyIcon;
  final Map<String, Map<String, dynamic>> doctorsCache;
  final Set<String> shownPaymentConfirmations;
  final Function(String, Map<String, dynamic>) onCancel;
  final Function(String, String?, Map<String, dynamic>?) onReschedule;
  final Function(String, Map<String, dynamic>) onCompletePayment;

  const AppointmentsListBuilder({
    super.key,
    required this.stream,
    required this.statuses,
    required this.emptyMsg,
    required this.emptyIcon,
    required this.doctorsCache,
    required this.shownPaymentConfirmations,
    required this.onCancel,
    required this.onReschedule,
    required this.onCompletePayment,
  });

  @override
  State<AppointmentsListBuilder> createState() =>
      _AppointmentsListBuilderState();
}

class _AppointmentsListBuilderState extends State<AppointmentsListBuilder> {
  String _formatStreamError(Object? error) {
    if (error is FirebaseException) {
      final code = error.code.trim().isEmpty ? 'firebase-error' : error.code;
      final message = (error.message ?? '').trim();
      return message.isEmpty ? code : '$code: $message';
    }
    return error?.toString() ?? 'Unknown stream error';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Shimmer.fromColors(
                baseColor: AppColors.divider,
                highlightColor: AppColors.background,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              );
            },
          );
        }

        if (snapshot.hasError) {
          final errorDetails = _formatStreamError(snapshot.error);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load appointments',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorDetails,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.emptyIcon,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.emptyMsg,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.statuses.contains('waiting')) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookAppointmentScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Book Now'),
                  ),
                ],
              ],
            ),
          );
        }

        final docs = snapshot.data!;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final doc in docs) {
            final dataMap = doc.data() as Map<String, dynamic>;
            if (dataMap['paymentStatus'] == 'paid' &&
                dataMap['paymentConfirmationShown'] == false) {
              final docId = doc.id;
              if (!widget.shownPaymentConfirmations.contains(docId)) {
                widget.shownPaymentConfirmations.add(docId);
                final doctorName = dataMap['doctorName'] ?? 'Doctor';

                FirebaseFirestore.instance
                    .collection('appointments')
                    .doc(docId)
                    .update({'paymentConfirmationShown': true});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Your payment for Dr. $doctorName has been confirmed.',
                    ),
                    backgroundColor: AppColors.success,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          }
        });

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 800));
          },
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final doctorId = data['doctorId'] as String?;
              final doctorData = doctorId != null
                  ? widget.doctorsCache[doctorId]
                  : null;

              return AppointmentCard(
                appointmentId: doc.id,
                data: data,
                isUpcoming:
                    widget.statuses.contains('waiting') ||
                    widget.statuses.contains('in-progress'),
                doctorData: doctorData,
                onCancel: () => widget.onCancel(doc.id, data),
                onReschedule: () =>
                    widget.onReschedule(doc.id, doctorId, doctorData),
                onCompletePayment: () => widget.onCompletePayment(doc.id, data),
              );
            },
          ),
        );
      },
    );
  }
}
