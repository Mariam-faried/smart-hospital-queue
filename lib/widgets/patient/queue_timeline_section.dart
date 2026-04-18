import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

class QueueTimelineSectionWidget extends StatelessWidget {
  final Map<String, dynamic> currentAppointment;
  final String currentAppointmentId;
  final Stream<QuerySnapshot>? timelineStream;

  const QueueTimelineSectionWidget({
    super.key,
    required this.currentAppointment,
    required this.currentAppointmentId,
    this.timelineStream,
  });

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  int _queuePosition(Map<String, dynamic> data) {
    final queuePosition = _asInt(data['queuePosition'], fallback: -1);
    if (queuePosition > 0) return queuePosition;

    final patientsAhead = _asInt(data['patientsAhead'], fallback: -1);
    if (patientsAhead >= 0) return patientsAhead + 1;

    return _asInt(data['ticketNumber'], fallback: 0);
  }

  String _normalizeStatus(dynamic rawStatus) {
    return rawStatus?.toString().trim().toLowerCase().replaceAll('_', '-') ??
        'waiting';
  }

  @override
  Widget build(BuildContext context) {
    if (timelineStream == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.timeline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text(
              'Queue Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
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
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: timelineStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unable to load queue timeline',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final docs = snapshot.data!.docs.toList();
              docs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;

                final qA = _queuePosition(dataA);
                final qB = _queuePosition(dataB);
                if (qA != qB) return qA.compareTo(qB);

                final tA = _asInt(dataA['ticketNumber']);
                final tB = _asInt(dataB['ticketNumber']);
                return tA.compareTo(tB);
              });

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'No patients in queue',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return Column(
                children: List.generate(docs.length, (index) {
                  final doc = docs[index].data() as Map<String, dynamic>;
                  final timelineAppointmentId =
                      doc['appointmentId']?.toString() ?? '';
                  final currentTicket = _asInt(
                    currentAppointment['ticketNumber'],
                  );
                  final timelineTicket = _asInt(doc['ticketNumber']);
                  final isMe =
                      timelineAppointmentId == currentAppointmentId ||
                      (timelineTicket != 0 && timelineTicket == currentTicket);
                  final docStatus = _normalizeStatus(doc['status']);
                  final isInProgress =
                      docStatus == 'in-progress' || docStatus == 'called';
                  final priority = doc['priority'] ?? 'normal';
                  final isElevatedPriority =
                      priority == 'emergency' || priority == 'urgent';

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Padding(
                      key: ValueKey('${doc['ticketNumber']}_$docStatus'),
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.primary
                                  : isInProgress
                                  ? AppColors.primary
                                  : AppColors.divider,
                              shape: BoxShape.circle,
                              boxShadow: isMe
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: (isMe || isInProgress)
                                      ? AppColors.onPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : isInProgress
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMe
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : isInProgress
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : AppColors.divider,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (isInProgress)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(
                                            Icons.medical_services_rounded,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      Text(
                                        isMe ? 'You' : 'Patient ${index + 1}',
                                        style: TextStyle(
                                          fontWeight: isMe
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isMe
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isElevatedPriority && !isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: priority == 'emergency'
                                                ? AppColors.error
                                                : AppColors.warning,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            priority == 'emergency'
                                                ? 'EMERGENCY'
                                                : 'URGENT',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.onPrimary,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? AppColors.primary.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.textSecondary.withValues(
                                              alpha: 0.1,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppFormatters.formatTicket(
                                        doc['ticketNumber'] ?? 0,
                                      ),
                                      style: TextStyle(
                                        color: isMe
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}
