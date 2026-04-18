import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';

class DoctorQueueCard extends StatefulWidget {
  final String doctorId;
  final int avgConsultationTime;

  const DoctorQueueCard({
    super.key,
    required this.doctorId,
    required this.avgConsultationTime,
  });

  @override
  State<DoctorQueueCard> createState() => _DoctorQueueCardState();
}

class _DoctorQueueCardState extends State<DoctorQueueCard> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _queueStatusStream;

  @override
  void initState() {
    super.initState();
    final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final queueKey = '${widget.doctorId}_$dateKey';
    _queueStatusStream = FirebaseFirestore.instance
        .collection('queue_public')
        .doc(queueKey)
        .collection('entries')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _queueStatusStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const SizedBox.shrink();
          }
          final activeDocs = (snapshot.data?.docs ?? const []).where((doc) {
            final status = (doc.data()['status'] as String? ?? '')
                .trim()
                .toLowerCase();
            return status == 'waiting' || status == 'in-progress';
          }).toList();
          final count = activeDocs.length;
          final waitMinutes = count * widget.avgConsultationTime;
          final waitText = waitMinutes == 0
              ? 'No wait - book now!'
              : waitMinutes < 60
              ? '~$waitMinutes min wait if you book now'
              : '~${waitMinutes ~/ 60}h ${waitMinutes % 60}m wait';

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primaryLight,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.people_alt_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 0
                            ? 'Queue is empty'
                            : '$count patient${count == 1 ? '' : 's'} in queue today',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        waitText,
                        style: TextStyle(
                          fontSize: 12,
                          color: count == 0
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: count == 0
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count == 0 ? 'Free Now' : 'Busy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: count == 0 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
