import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../services/queue_transition_policy.dart';

// Extracted widgets
import '../../widgets/patient/queue_progress_widget.dart';
import '../../widgets/patient/queue_card.dart';
import '../../widgets/patient/queue_action_buttons.dart';
import '../../widgets/patient/queue_timeline_section.dart';
import '../../widgets/patient/empty_queue_widget.dart';
import '../../widgets/patient/queue_card_skeleton.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/time_utils.dart';

class QueueTab extends StatefulWidget {
  const QueueTab({super.key});

  @override
  State<QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends State<QueueTab> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _stepperController;
  late Animation<double> _stepperAnimation;

  int _lastKnownPosition = -1; // for haptic on position change

  Stream<QuerySnapshot>? _queueStream;
  String? _cachedUserId;

  Stream<QuerySnapshot>? _timelineStream;
  String? _cachedDoctorId;
  String? _cachedDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).user;
    if (user == null) {
      if (_cachedUserId != null ||
          _queueStream != null ||
          _timelineStream != null) {
        _cachedUserId = null;
        _queueStream = null;
        _cachedDoctorId = null;
        _cachedDate = null;
        _timelineStream = null;
      }
      return;
    }

    if (user.uid != _cachedUserId) {
      _cachedUserId = user.uid;
      _cachedDoctorId = null;
      _cachedDate = null;
      _timelineStream = null;
      _queueStream = FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: user.uid)
          .where('status', whereIn: QueueAppointmentStatus.activeList)
          .snapshots();
    }
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _stepperController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _stepperAnimation = CurvedAnimation(
      parent: _stepperController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stepperController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────

  int _statusRank(Map<String, dynamic> data) {
    final status = QueueTransitionPolicy.normalizeStatus(
      data['status']?.toString() ?? QueueAppointmentStatus.waiting,
    );
    if (status == QueueAppointmentStatus.inProgress) return 0;
    if (status == QueueAppointmentStatus.waiting) return 1;
    if (status == QueueAppointmentStatus.confirmed) return 2;
    return 3;
  }

  DateTime _sortDateTime(Map<String, dynamic> data) {
    final rawDate = data['date']?.toString().trim() ?? '';
    final parsedDate = DateTime.tryParse(rawDate);
    final baseDate = parsedDate ?? DateTime(2100);
    final parsedSlot = TimeUtils.parseTimeSlot(
      data['timeSlot']?.toString() ?? '',
      baseDate: baseDate,
    );
    return parsedSlot ?? baseDate;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final notificationsEnabled = context
        .watch<AuthProvider>()
        .notificationsEnabled;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Queue',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.onPrimary,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final authProvider = context.read<AuthProvider>();
              final newValue = !authProvider.notificationsEnabled;
              authProvider.setNotificationsEnabled(newValue);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newValue ? 'Notifications enabled' : 'Notifications muted',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                notificationsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                key: ValueKey(notificationsEnabled),
                color: AppColors.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _queueStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: QueueCardSkeleton(),
            );
          }

          if (snapshot.hasError) {
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
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load your queue',
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
                      'If this keeps happening, please try again in a moment.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {});
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyQueueWidget();
          }

          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final statusRankCompare = _statusRank(
              dataA,
            ).compareTo(_statusRank(dataB));
            if (statusRankCompare != 0) return statusRankCompare;

            final dateTimeCompare = _sortDateTime(
              dataA,
            ).compareTo(_sortDateTime(dataB));
            if (dateTimeCompare != 0) return dateTimeCompare;

            return AppFormatters.parseTicketNumber(
              dataA['ticketNumber'],
            ).compareTo(AppFormatters.parseTicketNumber(dataB['ticketNumber']));
          });

          final currentDoc = docs.first;
          final currentAppointment = currentDoc.data() as Map<String, dynamic>;
          final appointmentId = currentDoc.id;

          final doctorId = currentAppointment['doctorId'] as String?;
          final date = currentAppointment['date'] as String?;

          if (doctorId != null &&
              doctorId.isNotEmpty &&
              date != null &&
              date.isNotEmpty) {
            if (_timelineStream == null ||
                _cachedDoctorId != doctorId ||
                _cachedDate != date) {
              _cachedDoctorId = doctorId;
              _cachedDate = date;
              final queueKey = '${doctorId}_$date';
              _timelineStream = FirebaseFirestore.instance
                  .collection('queue_public')
                  .doc(queueKey)
                  .collection('entries')
                  .where('status', whereIn: ['waiting', 'in-progress'])
                  .snapshots();
            }
          } else if (_timelineStream != null ||
              _cachedDoctorId != null ||
              _cachedDate != null) {
            _timelineStream = null;
            _cachedDoctorId = null;
            _cachedDate = null;
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  QueueProgressWidget(
                    stepperAnimation: _stepperAnimation,
                    appointmentData: currentAppointment,
                  ),
                  const SizedBox(height: 20),
                  QueueCard(
                    appointmentData: currentAppointment,
                    appointmentId: appointmentId,
                    pulseAnimation: _pulseAnimation,
                    lastKnownPosition: _lastKnownPosition,
                    onPositionChanged: (pos) => _lastKnownPosition = pos,
                  ),
                  const SizedBox(height: 16),
                  ActionButtonsWidget(
                    appointmentData: currentAppointment,
                    appointmentId: appointmentId,
                  ),
                  const SizedBox(height: 24),
                  QueueTimelineSectionWidget(
                    currentAppointment: currentAppointment,
                    currentAppointmentId: appointmentId,
                    timelineStream: _timelineStream,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
