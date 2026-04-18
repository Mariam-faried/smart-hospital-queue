import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/queue_entry_model.dart';
import '../services/queue_service.dart';
import '../services/queue_transition_policy.dart';

/// Provider for managing real-time queue updates
class QueueProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final QueueService _queueService = QueueService(firestore: _firestore);

  // State
  List<QueueEntryModel> _queueEntries = [];
  QueueEntryModel? _currentPatientQueue;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<QueueEntryModel> get queueEntries => _queueEntries;
  QueueEntryModel? get currentPatientQueue => _currentPatientQueue;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get active queue entries (waiting or called)
  List<QueueEntryModel> get activeQueue =>
      _queueEntries.where((entry) => entry.isActive).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _queueSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _patientQueueSubscription;

  static String _dateYmd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static int _priorityRank(String? priority) {
    switch ((priority ?? '').trim().toLowerCase()) {
      case 'emergency':
        return 0;
      case 'urgent':
        return 1;
      default:
        return 2;
    }
  }

  static int _statusRank(String? rawStatus) {
    final status = QueueTransitionPolicy.normalizeStatus(rawStatus ?? '');
    if (status == QueueAppointmentStatus.inProgress) return 0;
    if (status == QueueAppointmentStatus.confirmed) return 1;
    if (status == QueueAppointmentStatus.waiting) return 2;
    return 3;
  }

  static DateTime _readDateTime(dynamic raw, {DateTime? fallback}) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return fallback ?? DateTime.now();
  }

  QueueEntryModel _entryFromAppointment(
    String appointmentId,
    Map<String, dynamic> data, {
    required int fallbackPosition,
  }) {
    final normalizedStatus = QueueTransitionPolicy.normalizeStatus(
      data['status'] as String? ?? QueueAppointmentStatus.waiting,
    );
    // Keep "called" in the view model so existing doctor widgets keep working.
    final mappedStatus = normalizedStatus == QueueAppointmentStatus.inProgress
        ? 'called'
        : normalizedStatus == QueueAppointmentStatus.noShow
        ? QueueAppointmentStatus.noShow
        : normalizedStatus;

    final patientsAhead = (data['patientsAhead'] as num?)?.toInt();
    final queuePosition = (data['queuePosition'] as num?)?.toInt();
    final computedPosition = patientsAhead != null
        ? (patientsAhead + 1)
        : queuePosition != null
        ? (queuePosition > 0 ? queuePosition : 1)
        : fallbackPosition;

    final checkInSource =
        data['checkedInAt'] ?? data['checkInTime'] ?? data['createdAt'];
    final calledAtSource = data['consultationStartTime'] ?? data['calledAt'];

    return QueueEntryModel(
      id: appointmentId,
      appointmentId: appointmentId,
      doctorId: data['doctorId'] as String? ?? '',
      ticketNumber: QueueTransitionPolicy.parseTicketNumber(
        data['ticketNumber'],
      ),
      patientName: data['patientName'] as String? ?? '',
      position: computedPosition,
      status: mappedStatus,
      estimatedWaitTime: (data['estimatedWaitTime'] as num?)?.toInt() ?? 0,
      date: data['date'] as String? ?? '',
      checkInTime: _readDateTime(checkInSource),
      calledAt: calledAtSource != null ? _readDateTime(calledAtSource) : null,
    );
  }

  Future<String> _requireDoctorId(String appointmentId) async {
    final doc = await _firestore
        .collection('appointments')
        .doc(appointmentId)
        .get();
    final doctorId = doc.data()?['doctorId'] as String? ?? '';
    if (doctorId.trim().isEmpty) {
      throw StateError('Doctor ID not found for appointment $appointmentId');
    }
    return doctorId;
  }

  String _toTargetStatus(String status) {
    switch (QueueTransitionPolicy.normalizeStatus(status)) {
      case 'called':
      case QueueAppointmentStatus.inProgress:
        return QueueAppointmentStatus.inProgress;
      case 'completed':
        return QueueAppointmentStatus.completed;
      case QueueAppointmentStatus.noShow:
        return QueueAppointmentStatus.noShow;
      case 'confirmed':
        return QueueAppointmentStatus.confirmed;
      case 'cancelled':
        return QueueAppointmentStatus.cancelled;
      case 'waiting':
      default:
        return QueueTransitionPolicy.normalizeStatus(status);
    }
  }

  /// Listen to doctor's queue for today
  void listenToDoctorQueue(String doctorId, DateTime date) {
    _isLoading = true;
    notifyListeners();

    final dateString = _dateYmd(date);

    _queueSubscription?.cancel();
    _queueSubscription = _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: dateString)
        .where('status', whereIn: QueueAppointmentStatus.activeList)
        .snapshots()
        .listen(
          (snapshot) {
            final docs = snapshot.docs.toList()
              ..sort((a, b) {
                final aData = a.data();
                final bData = b.data();

                final statusCmp =
                    _statusRank(aData['status'] as String?) -
                    _statusRank(bData['status'] as String?);
                if (statusCmp != 0) return statusCmp;

                final priorityCmp =
                    _priorityRank(aData['priority'] as String?) -
                    _priorityRank(bData['priority'] as String?);
                if (priorityCmp != 0) return priorityCmp;

                final ticketA = QueueTransitionPolicy.parseTicketNumber(
                  aData['ticketNumber'],
                );
                final ticketB = QueueTransitionPolicy.parseTicketNumber(
                  bData['ticketNumber'],
                );
                return ticketA.compareTo(ticketB);
              });

            _queueEntries = [
              for (int i = 0; i < docs.length; i++)
                _entryFromAppointment(
                  docs[i].id,
                  docs[i].data(),
                  fallbackPosition: i + 1,
                ),
            ];
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load queue: $error';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Listen to patient's current queue position
  void listenToPatientQueue(String appointmentId) {
    _patientQueueSubscription?.cancel();
    _patientQueueSubscription = _firestore
        .collection('appointments')
        .doc(appointmentId)
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data();
            if (snapshot.exists && data != null) {
              final status = QueueTransitionPolicy.normalizeStatus(
                data['status'] as String? ?? '',
              );
              if (QueueTransitionPolicy.isActiveStatus(status)) {
                _currentPatientQueue = _entryFromAppointment(
                  snapshot.id,
                  data,
                  fallbackPosition:
                      ((data['patientsAhead'] as num?)?.toInt() ?? 0) + 1,
                );
              } else {
                _currentPatientQueue = null;
              }
            } else {
              _currentPatientQueue = null;
            }
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load your queue position: $error';
            notifyListeners();
          },
        );
  }

  /// Update queue entry status
  Future<void> updateQueueStatus(String queueEntryId, String status) async {
    try {
      final doctorId = await _requireDoctorId(queueEntryId);
      await _queueService.markAppointmentStatus(
        queueEntryId,
        doctorId,
        _toTargetStatus(status),
      );
    } catch (e) {
      _error = 'Failed to update queue status: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Call next patient in queue
  Future<QueueEntryModel?> callNextPatient(
    String doctorId,
    DateTime date,
  ) async {
    try {
      final dateString = _dateYmd(date);

      final snapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: dateString)
          .where(
            'status',
            whereIn: <String>[
              QueueAppointmentStatus.waiting,
              QueueAppointmentStatus.confirmed,
            ],
          )
          .get();

      if (snapshot.docs.isEmpty) return null;

      final docs = snapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data();
          final bData = b.data();

          final priorityCmp =
              _priorityRank(aData['priority'] as String?) -
              _priorityRank(bData['priority'] as String?);
          if (priorityCmp != 0) return priorityCmp;

          final ticketA = QueueTransitionPolicy.parseTicketNumber(
            aData['ticketNumber'],
          );
          final ticketB = QueueTransitionPolicy.parseTicketNumber(
            bData['ticketNumber'],
          );
          return ticketA.compareTo(ticketB);
        });

      final nextDoc = docs.first;
      final nextPatient = _entryFromAppointment(
        nextDoc.id,
        nextDoc.data(),
        fallbackPosition: 1,
      );

      await updateQueueStatus(nextPatient.id, 'called');

      return nextPatient.copyWith(status: 'called');
    } catch (e) {
      _error = 'Failed to call next patient: $e';
      notifyListeners();
      return null;
    }
  }

  /// Complete queue entry
  Future<void> completeQueueEntry(String queueEntryId) async {
    try {
      await updateQueueStatus(queueEntryId, QueueAppointmentStatus.completed);
    } catch (e) {
      _error = 'Failed to complete queue entry: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Mark patient as no-show
  Future<void> markNoShow(String queueEntryId) async {
    try {
      await updateQueueStatus(queueEntryId, QueueAppointmentStatus.noShow);
    } catch (e) {
      _error = 'Failed to mark no-show: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get queue statistics
  Map<String, int> getQueueStats() {
    final inProgressCount = _queueEntries.where((entry) {
      final normalized = QueueTransitionPolicy.normalizeStatus(entry.status);
      return normalized == 'called' ||
          normalized == QueueAppointmentStatus.inProgress;
    }).length;
    final noShowCount = _queueEntries.where((entry) {
      final normalized = QueueTransitionPolicy.normalizeStatus(entry.status);
      return normalized == QueueAppointmentStatus.noShow;
    }).length;

    return {
      'total': _queueEntries.length,
      'waiting': _queueEntries.where((e) => e.status == 'waiting').length,
      'called': _queueEntries.where((e) => e.status == 'called').length,
      'in-progress': inProgressCount,
      'completed': _queueEntries.where((e) => e.status == 'completed').length,
      'no-show': noShowCount,
    };
  }

  /// Stop listening to all queues
  void stopListening() {
    _queueSubscription?.cancel();
    _patientQueueSubscription?.cancel();
    _queueEntries = [];
    _currentPatientQueue = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _patientQueueSubscription?.cancel();
    super.dispose();
  }
}
