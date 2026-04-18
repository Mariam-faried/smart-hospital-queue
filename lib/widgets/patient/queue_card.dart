import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

import '../../services/queue_service.dart';
import 'queue_stats_widget.dart';
import 'grace_period_warning_widget.dart';

class QueueCard extends StatefulWidget {
  final Map<String, dynamic> appointmentData;
  final String appointmentId;
  final Animation<double> pulseAnimation;
  final int lastKnownPosition;
  final ValueChanged<int> onPositionChanged;

  const QueueCard({
    super.key,
    required this.appointmentData,
    required this.appointmentId,
    required this.pulseAnimation,
    required this.lastKnownPosition,
    required this.onPositionChanged,
  });

  @override
  State<QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<QueueCard> {
  String? _cachedDoctorId;
  Map<String, dynamic>? _cachedDoctorData;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _fetchDoctorDataIfNeeded();
  }

  @override
  void didUpdateWidget(QueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appointmentData['doctorId'] !=
        oldWidget.appointmentData['doctorId']) {
      _fetchDoctorDataIfNeeded();
    }
  }

  Future<void> _fetchDoctorDataIfNeeded() async {
    final doctorId = widget.appointmentData['doctorId'];
    if (doctorId == null) return;

    if (doctorId != _cachedDoctorId) {
      _cachedDoctorId = doctorId;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('doctors')
            .doc(_cachedDoctorId)
            .get();
        if (mounted) {
          setState(() {
            _cachedDoctorData = doc.data();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _handleCheckIn(
    BuildContext context,
    String appointmentId,
  ) async {
    HapticFeedback.mediumImpact();
    setState(() => _isCheckingIn = true);
    try {
      await QueueService().checkInPatient(appointmentId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.onSuccess),
                SizedBox(width: 8),
                Text('Checked in successfully.'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not check in. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  void _showQRCodeSheet(
    BuildContext context,
    String ticketFormatted,
    String appointmentId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground.withValues(alpha: 0),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
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
            Text(
              ticketFormatted,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: QrImageView(
                data: '$ticketFormatted|$appointmentId',
                version: QrVersions.auto,
                size: 200,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: AppColors.primaryDark,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Show this QR code at reception',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareQueueStatus(
    String doctorName,
    String specialization,
    int patientsAhead,
    int waitTime,
    String ticketFormatted,
  ) {
    HapticFeedback.lightImpact();
    final positionText = patientsAhead == 0
        ? 'I am next!'
        : '$patientsAhead patients ahead';
    final text =
        'MediQueue Update\n\n'
        'Ticket: $ticketFormatted\n'
        'Doctor: $doctorName ($specialization)\n'
        'Position: $positionText\n'
        'Est. Wait: ~$waitTime min\n\n'
        'Sent from MediQueue';
    SharePlus.instance.share(ShareParams(text: text));
  }

  String _normalizeStatus(dynamic rawStatus) {
    return rawStatus?.toString().trim().toLowerCase().replaceAll('_', '-') ??
        'waiting';
  }

  @override
  Widget build(BuildContext context) {
    final appointmentData = widget.appointmentData;
    final appointmentId = widget.appointmentId;
    final onPositionChanged = widget.onPositionChanged;
    final lastKnownPosition = widget.lastKnownPosition;

    String? imageUrl;
    String? fetchedDoctorName;
    String? fetchedSpecialization;
    Map<String, dynamic>? doctorData = _cachedDoctorData;

    if (doctorData != null) {
      imageUrl = doctorData['imageUrl'];
      fetchedDoctorName = doctorData['name'];
      fetchedSpecialization = doctorData['specialization'];
    }

    final doctorName =
        fetchedDoctorName ?? appointmentData['doctorName'] ?? 'Unknown Doctor';
    final int pAhead = (appointmentData['patientsAhead'] as num?)?.toInt() ?? 0;
    final int wTime =
        (appointmentData['estimatedWaitTime'] as num?)?.toInt() ?? 0;
    final tNum = appointmentData['ticketNumber'] ?? 0;
    final spec =
        fetchedSpecialization ??
        appointmentData['specialization'] ??
        'Specialist';
    final date = appointmentData['date'] ?? 'Unknown Date';
    final timeSlot = appointmentData['timeSlot'] ?? 'Unknown Time';
    final status = _normalizeStatus(appointmentData['status']);
    final checkedIn = appointmentData['checkedIn'] == true;
    final priority = appointmentData['priority'] ?? 'normal';
    final isEmergency = priority == 'emergency';
    final isUrgent = priority == 'urgent';
    final currentState = doctorData?['currentState'] ?? 'available';
    final graceMinutes = (doctorData?['graceMinutes'] as num?)?.toInt() ?? 15;
    final num? fetchedFee = doctorData?['consultationFee'] as num?;
    final String currency = (doctorData?['currency'] as String?) ?? 'EGP';
    final isPaused =
        currentState == 'on_break' || currentState == 'unavailable';

    final isInWaitingFlow = status == 'waiting' || status == 'confirmed';
    final isNext = pAhead == 0 && isInWaitingFlow;

    if (lastKnownPosition != -1 && lastKnownPosition != pAhead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.mediumImpact();
        if (isNext) HapticFeedback.heavyImpact();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (lastKnownPosition != pAhead) {
        onPositionChanged(pAhead);
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildStatusBanner(isNext, status),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showQRCodeSheet(
                      context,
                      AppFormatters.formatTicket(tNum),
                      appointmentId,
                    );
                  },
                  child: Column(
                    children: [
                      if (isEmergency || isUrgent)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isEmergency
                                ? AppColors.error
                                : AppColors.warning,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            priority.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.cardBackground,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Hero(
                        tag: 'ticket_$appointmentId',
                        child: Text(
                          AppFormatters.formatTicket(tNum),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap for QR Code',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl ?? appointmentData['imageUrl'] ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: AppColors.primary.withValues(alpha: 0.2),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: Text(
                              doctorName.isNotEmpty
                                  ? doctorName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  doctorName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildDoctorStatusDot(currentState),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$spec - $date',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            timeSlot,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (fetchedFee != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.payments_outlined,
                                  size: 14,
                                  color: fetchedFee == 0
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  fetchedFee == 0
                                      ? 'Free consultation'
                                      : '$fetchedFee $currency consultation fee',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: fetchedFee == 0
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shareQueueStatus(
                        doctorName,
                        spec,
                        pAhead,
                        wTime,
                        AppFormatters.formatTicket(tNum),
                      ),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.share_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isPaused)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause_circle_filled,
                          color: AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Doctor is currently on a break. Queue is paused.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                QueueStatsWidget(
                  patientsAhead: pAhead,
                  estimatedWaitTime: wTime,
                  isPaused: isPaused,
                ),
                const SizedBox(height: 20),
                if (isNext && !checkedIn)
                  GracePeriodWarningWidget(
                    graceMinutes: graceMinutes,
                    timeSlot: timeSlot,
                  ),
                if (checkedIn || isInWaitingFlow)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildCheckInButton(
                      context,
                      checkedIn,
                      appointmentId,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isNext, String status) {
    final normalizedStatus = _normalizeStatus(status);
    final isInProgress =
        normalizedStatus == 'in-progress' || normalizedStatus == 'called';

    if (isNext) {
      return AnimatedBuilder(
        animation: widget.pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.pulseAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success,
                AppColors.success.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars, color: AppColors.onSuccess, size: 20),
              SizedBox(width: 8),
              Text(
                'Your turn is next!',
                style: TextStyle(
                  color: AppColors.onSuccess,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isInProgress
              ? [
                  AppColors.statusInProgress,
                  AppColors.statusInProgress.withValues(alpha: 0.8),
                ]
              : [
                  AppColors.statusWaiting,
                  AppColors.statusWaiting.withValues(alpha: 0.8),
                ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isInProgress
                ? Icons.medical_services_rounded
                : Icons.hourglass_top_rounded,
            color: AppColors.onPrimary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isInProgress ? 'Consultation In Progress' : 'Waiting in Queue',
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorStatusDot(String currentState) {
    Color dotColor;
    String dotLabel;
    switch (currentState) {
      case 'in_consultation':
        dotColor = AppColors.warning;
        dotLabel = 'In Consultation';
        break;
      case 'on_break':
        dotColor = AppColors.textSecondary;
        dotLabel = 'On Break';
        break;
      case 'unavailable':
        dotColor = AppColors.error;
        dotLabel = 'Unavailable';
        break;
      case 'available':
      default:
        dotColor = AppColors.success;
        dotLabel = 'Available';
        break;
    }
    return Tooltip(
      message: dotLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: dotColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              dotLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: dotColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInButton(
    BuildContext context,
    bool checkedIn,
    String appointmentId,
  ) {
    if (checkedIn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text(
              'Checked In',
              style: TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCheckingIn
            ? null
            : () => _handleCheckIn(context, appointmentId),
        icon: _isCheckingIn
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.login_rounded),
        label: const Text(
          "I've Arrived - Check In",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
