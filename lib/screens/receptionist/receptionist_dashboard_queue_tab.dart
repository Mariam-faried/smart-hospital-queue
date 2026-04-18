part of 'receptionist_dashboard.dart';

// =======================================
// TAB 2 - QUEUE MANAGEMENT
// =======================================

class _QueueTab extends StatefulWidget {
  const _QueueTab();

  @override
  State<_QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends State<_QueueTab> {
  String? _selectedDoctorId;
  String _selectedDoctorName = '';
  final QueueService _queueService = QueueService();
  final Set<String> _processingAppointments = <String>{};

  bool _isProcessing(String appointmentId) =>
      _processingAppointments.contains(appointmentId);

  Future<void> _runQueueAction({
    required String appointmentId,
    required Future<void> Function() action,
    required String successMessage,
    required Color successColor,
  }) async {
    if (_isProcessing(appointmentId)) return;

    setState(() => _processingAppointments.add(appointmentId));

    try {
      await action();
      if (!mounted) return;
      _showSnackBar(successMessage, backgroundColor: successColor);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        _friendlyError(error),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() => _processingAppointments.remove(appointmentId));
      }
    }
  }

  void _showSnackBar(
    String message, {
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.toLowerCase().contains('permission-denied')) {
      return 'You do not have permission to perform this action.';
    }
    if (raw.startsWith('Exception:')) {
      return raw.replaceFirst('Exception:', '').trim();
    }
    return 'Action failed. Please try again.';
  }

  Future<void> _checkInPatient(String appointmentId) async {
    await _runQueueAction(
      appointmentId: appointmentId,
      action: () => _queueService.checkInPatient(appointmentId),
      successMessage: 'Patient checked in.',
      successColor: AppColors.success,
    );
  }

  Future<void> _callNextPatient(String appointmentId, String doctorId) async {
    if (doctorId.isEmpty) {
      _showSnackBar(
        'Doctor information is unavailable for this appointment.',
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    await _runQueueAction(
      appointmentId: appointmentId,
      action: () => _queueService.markAppointmentStatus(
        appointmentId,
        doctorId,
        QueueAppointmentStatus.inProgress,
      ),
      successMessage: 'Patient called. Consultation is now in progress.',
      successColor: AppColors.info,
    );
  }

  Future<void> _markComplete(
    String appointmentId,
    String doctorId,
    int ticketNumber,
  ) async {
    if (doctorId.isEmpty) {
      _showSnackBar(
        'Doctor information is unavailable for this appointment.',
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    await _runQueueAction(
      appointmentId: appointmentId,
      action: () => _queueService.markAppointmentStatus(
        appointmentId,
        doctorId,
        QueueAppointmentStatus.completed,
        completedTicketNumber: ticketNumber,
      ),
      successMessage: 'Appointment completed.',
      successColor: AppColors.success,
    );
  }

  Future<void> _markNoShow(String appointmentId, String doctorId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark No Show'),
        content: const Text(
          'Are you sure you want to mark this patient as No Show?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (doctorId.isEmpty) {
      _showSnackBar(
        'Doctor information is unavailable for this appointment.',
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    await _runQueueAction(
      appointmentId: appointmentId,
      action: () => _queueService.markAppointmentStatus(
        appointmentId,
        doctorId,
        QueueAppointmentStatus.noShow,
      ),
      successMessage: 'Patient marked as No Show.',
      successColor: AppColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Doctor Selector
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('doctors')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _buildDoctorSelectorShell(
                    child: Text(
                      'Could not load doctors',
                      style: TextStyle(
                        color: AppColors.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return _buildDoctorSelectorShell(
                    child: Row(
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading doctors...',
                          style: TextStyle(
                            color: AppColors.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allDocs = snap.data?.docs ?? [];
                final doctors = allDocs.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final status = d['accountStatus'] as String? ?? 'active';
                  return status == 'active';
                }).toList();
                if (doctors.isEmpty) {
                  return _buildDoctorSelectorShell(
                    child: Text(
                      'No active doctors available',
                      style: TextStyle(
                        color: AppColors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  );
                }

                final hasValidSelection =
                    _selectedDoctorId != null &&
                    doctors.any((doc) => doc.id == _selectedDoctorId);
                if (!hasValidSelection && _selectedDoctorId != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      _selectedDoctorId = null;
                      _selectedDoctorName = '';
                    });
                  });
                }

                return _buildDoctorSelectorShell(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: hasValidSelection ? _selectedDoctorId : null,
                      hint: Text(
                        'Select a doctor...',
                        style: TextStyle(
                          color: AppColors.onPrimary.withValues(alpha: 0.7),
                        ),
                      ),
                      dropdownColor: AppColors.primary,
                      iconEnabledColor: AppColors.onPrimary,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 15,
                      ),
                      items: doctors.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'Unknown';
                        final spec = data['specialization'] as String? ?? '';
                        final label = spec.isEmpty ? name : '$name - $spec';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;

                        QueryDocumentSnapshot? selectedDoc;
                        for (final doc in doctors) {
                          if (doc.id == id) {
                            selectedDoc = doc;
                            break;
                          }
                        }
                        if (selectedDoc == null) return;

                        final data = selectedDoc.data() as Map<String, dynamic>;
                        setState(() {
                          _selectedDoctorId = id;
                          _selectedDoctorName = data['name'] as String? ?? '';
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Queue List
          Expanded(
            child: _selectedDoctorId == null
                ? _buildEmptyState(
                    icon: Icons.touch_app_outlined,
                    message: 'Select a doctor to view their queue',
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('appointments')
                        .where('doctorId', isEqualTo: _selectedDoctorId)
                        .where('date', isEqualTo: todayStr)
                        .where(
                          'status',
                          whereIn: [
                            QueueAppointmentStatus.waiting,
                            QueueAppointmentStatus.inProgress,
                          ],
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildEmptyState(
                          icon: Icons.error_outline,
                          message: 'Could not load the queue right now',
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      final docs = List<QueryDocumentSnapshot>.from(
                        snapshot.data?.docs ?? const [],
                      );
                      if (docs.isEmpty) {
                        final selectedDoctorLabel =
                            _selectedDoctorName.trim().isEmpty
                            ? 'the selected doctor'
                            : _formatDoctorName(_selectedDoctorName);
                        return _buildEmptyState(
                          icon: Icons.inbox_outlined,
                          message:
                              'No patients in queue for $selectedDoctorLabel',
                        );
                      }

                      // Sort: priority first (emergency > urgent > normal), then by ticket number
                      docs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;

                        // in-progress on top
                        final aStatus = aData['status'] as String? ?? '';
                        final bStatus = bData['status'] as String? ?? '';
                        if (aStatus == QueueAppointmentStatus.inProgress &&
                            bStatus != QueueAppointmentStatus.inProgress) {
                          return -1;
                        }
                        if (bStatus == QueueAppointmentStatus.inProgress &&
                            aStatus != QueueAppointmentStatus.inProgress) {
                          return 1;
                        }

                        int pA = _priorityValue(aData['priority'] as String?);
                        int pB = _priorityValue(bData['priority'] as String?);
                        if (pA != pB) return pA.compareTo(pB);

                        int tA = _readInt(aData['ticketNumber']);
                        int tB = _readInt(bData['ticketNumber']);
                        return tA.compareTo(tB);
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildQueueCard(doc.id, data);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorSelectorShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  int _priorityValue(String? p) {
    if (p == 'emergency') return 1;
    if (p == 'urgent') return 2;
    return 3;
  }

  Widget _buildQueueCard(String appointmentId, Map<String, dynamic> data) {
    final patientName = data['patientName'] as String? ?? 'Unknown';
    final ticket = AppFormatters.formatTicket(data['ticketNumber']);
    final ticketNum = _readInt(data['ticketNumber']);
    final priority = data['priority'] as String? ?? 'normal';
    final status = data['status'] as String? ?? QueueAppointmentStatus.waiting;
    final checkedIn = data['checkedIn'] as bool? ?? false;
    final doctorId = data['doctorId'] as String? ?? '';
    final waitTime = (data['estimatedWaitTime'] as num?)?.toInt() ?? 0;
    final timeSlot = data['timeSlot'] as String? ?? '';
    final priorityColor = priority == 'emergency'
        ? AppColors.error
        : AppColors.warning;
    final priorityLabel = priority
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .toUpperCase();

    final isInProgress = status == QueueAppointmentStatus.inProgress;
    final canCheckIn = !checkedIn && !isInProgress;
    final canCall = checkedIn && !isInProgress;
    final canComplete = isInProgress;
    final canNoShow = !checkedIn && !isInProgress;
    final isProcessing = _isProcessing(appointmentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: isInProgress
            ? Border.all(
                color: AppColors.statusInProgress.withValues(alpha: 0.4),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: ticket + patient name + priority badge
            Row(
              children: [
                // Ticket badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ticket,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeSlot,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Priority badge
                if (priority != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusSurface(priorityColor),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.statusBorder(priorityColor),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          priority == 'emergency'
                              ? Icons.emergency
                              : Icons.priority_high,
                          size: 12,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          priorityLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Status row
            Row(
              children: [
                // Status chip
                _StatusChip(status: status),
                const SizedBox(width: 8),
                // Check-in indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: checkedIn
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        checkedIn ? Icons.how_to_reg : Icons.person_outline,
                        size: 12,
                        color: checkedIn
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        checkedIn ? 'Checked In' : 'Not Checked In',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: checkedIn
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (waitTime > 0 && !isInProgress)
                  Text(
                    '~${AppFormatters.formatWaitTime(waitTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Action buttons
            ReceptionQueueActionRow(
              canCheckIn: canCheckIn,
              canCall: canCall,
              canComplete: canComplete,
              canNoShow: canNoShow,
              isProcessing: isProcessing,
              onCheckIn: () => _checkInPatient(appointmentId),
              onCall: () => _callNextPatient(appointmentId, doctorId),
              onComplete: () =>
                  _markComplete(appointmentId, doctorId, ticketNum),
              onNoShow: () => _markNoShow(appointmentId, doctorId),
            ),
          ],
        ),
      ),
    );
  }
}
