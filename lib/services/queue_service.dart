import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../utils/time_utils.dart';
import 'queue_transition_policy.dart';

class QueueService {
  final FirebaseFirestore _firestore;
  static const String _publicQueueCollection = 'queue_public';
  static const List<String> _publicTimelineStatuses = <String>[
    QueueAppointmentStatus.waiting,
    QueueAppointmentStatus.inProgress,
  ];

  QueueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  void _logDebug(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'QueueService');
    }
  }

  static String publicQueueKey({
    required String doctorId,
    required String date,
  }) {
    return '${doctorId}_$date';
  }

  DocumentReference<Map<String, dynamic>> _publicQueueEntryRef({
    required String doctorId,
    required String date,
    required String appointmentId,
  }) {
    return _firestore
        .collection(_publicQueueCollection)
        .doc(publicQueueKey(doctorId: doctorId, date: date))
        .collection('entries')
        .doc(appointmentId);
  }

  DocumentReference<Map<String, dynamic>> _publicQueueMetaRef({
    required String doctorId,
    required String date,
  }) {
    return _firestore
        .collection(_publicQueueCollection)
        .doc(publicQueueKey(doctorId: doctorId, date: date));
  }

  String _normalizePriority(String? rawPriority) {
    final priority = (rawPriority ?? 'normal').trim().toLowerCase();
    if (priority == 'emergency' || priority == 'urgent') {
      return priority;
    }
    return 'normal';
  }

  int _patientsAheadFromQueuePosition(dynamic rawQueuePosition) {
    if (rawQueuePosition is num) {
      final queuePosition = rawQueuePosition.toInt();
      if (queuePosition <= 1) return 0;
      return queuePosition - 1;
    }
    if (rawQueuePosition is String) {
      final parsed = int.tryParse(rawQueuePosition.trim());
      if (parsed != null) {
        if (parsed <= 1) return 0;
        return parsed - 1;
      }
    }
    return 0;
  }

  Map<String, dynamic> _buildPublicQueuePayload({
    required String appointmentId,
    required String doctorId,
    required String date,
    required String timeSlot,
    required String status,
    required int ticketNumber,
    required String priority,
    required int patientsAhead,
    required double estimatedWaitTime,
  }) {
    return <String, dynamic>{
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'date': date,
      'timeSlot': timeSlot,
      'status': status,
      'ticketNumber': ticketNumber,
      'priority': priority,
      'patientsAhead': patientsAhead,
      'queuePosition': patientsAhead + 1,
      'estimatedWaitTime': estimatedWaitTime,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _buildPublicQueueMetaPayload({
    required String doctorId,
    required String date,
  }) {
    return <String, dynamic>{
      'doctorId': doctorId,
      'date': date,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _upsertPublicQueueMeta({
    required String doctorId,
    required String date,
  }) async {
    await _publicQueueMetaRef(doctorId: doctorId, date: date).set(
      _buildPublicQueueMetaPayload(doctorId: doctorId, date: date),
      SetOptions(merge: true),
    );
  }

  Future<void> deletePublicQueueEntry({
    required String appointmentId,
    required String doctorId,
    required String date,
  }) async {
    if (appointmentId.trim().isEmpty ||
        doctorId.trim().isEmpty ||
        date.trim().isEmpty) {
      return;
    }
    try {
      await _publicQueueEntryRef(
        doctorId: doctorId,
        date: date,
        appointmentId: appointmentId,
      ).delete();
    } catch (_) {}
  }

  Future<void> syncPublicQueueEntryByAppointmentId(String appointmentId) async {
    if (appointmentId.trim().isEmpty) return;
    final snapshot = await _firestore
        .collection('appointments')
        .doc(appointmentId)
        .get();
    if (!snapshot.exists) return;
    final data = snapshot.data();
    if (data == null) return;
    await syncPublicQueueEntryFromData(
      appointmentId: appointmentId,
      appointmentData: data,
    );
  }

  Future<void> syncPublicQueueEntryFromData({
    required String appointmentId,
    required Map<String, dynamic> appointmentData,
    String? statusOverride,
  }) async {
    final doctorId = appointmentData['doctorId'] as String? ?? '';
    final date = appointmentData['date'] as String? ?? '';
    if (doctorId.trim().isEmpty || date.trim().isEmpty) return;

    final status = QueueTransitionPolicy.normalizeStatus(
      statusOverride ?? appointmentData['status'] as String? ?? '',
    );

    if (!_publicTimelineStatuses.contains(status)) {
      await deletePublicQueueEntry(
        appointmentId: appointmentId,
        doctorId: doctorId,
        date: date,
      );
      return;
    }

    final ticketNumber = QueueTransitionPolicy.parseTicketNumber(
      appointmentData['ticketNumber'],
    );
    final timeSlot = appointmentData['timeSlot'] as String? ?? '';
    final patientsAhead =
        (appointmentData['patientsAhead'] as num?)?.toInt() ??
        _patientsAheadFromQueuePosition(appointmentData['queuePosition']);
    final estimatedWaitTime =
        (appointmentData['estimatedWaitTime'] as num?)?.toDouble() ?? 0.0;

    final payload = _buildPublicQueuePayload(
      appointmentId: appointmentId,
      doctorId: doctorId,
      date: date,
      timeSlot: timeSlot,
      status: status,
      ticketNumber: ticketNumber,
      priority: _normalizePriority(appointmentData['priority'] as String?),
      patientsAhead: patientsAhead,
      estimatedWaitTime: estimatedWaitTime,
    );

    await _upsertPublicQueueMeta(doctorId: doctorId, date: date);

    await _publicQueueEntryRef(
      doctorId: doctorId,
      date: date,
      appointmentId: appointmentId,
    ).set(payload, SetOptions(merge: true));
  }

  Future<void> checkInPatient(String appointmentId) async {
    final docRef = _firestore.collection('appointments').doc(appointmentId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Appointment $appointmentId not found');
    }

    final currentStatus = QueueTransitionPolicy.normalizeStatus(
      data['status'] as String? ?? QueueAppointmentStatus.waiting,
    );
    if (!QueueTransitionPolicy.isActiveStatus(currentStatus)) {
      throw StateError(
        'Cannot check in appointment with status "$currentStatus".',
      );
    }

    await docRef.update({
      'checkedIn': true,
      'checkedInAt': FieldValue.serverTimestamp(),
      'checkInTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await syncPublicQueueEntryByAppointmentId(appointmentId);
  }

  Future<void> leaveQueue(String appointmentId, {String? doctorId}) async {
    String resolvedDoctorId = doctorId?.trim() ?? '';
    if (resolvedDoctorId.isEmpty) {
      final snapshot = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
      final data = snapshot.data();
      resolvedDoctorId = data?['doctorId'] as String? ?? '';
      if (resolvedDoctorId.trim().isEmpty) {
        throw StateError('Doctor ID not found for appointment $appointmentId');
      }
    }

    await markAppointmentStatus(
      appointmentId,
      resolvedDoctorId,
      QueueAppointmentStatus.cancelled,
    );
  }

  double calculateSmartWaitTime({
    required int patientsAhead,
    required double avgConsultationTime,
    required String patientType,
    required double noShowRate,
  }) {
    double typeMultiplier = patientType == 'new'
        ? 1.2
        : patientType == 'followup'
        ? 0.8
        : 1.0;
    double adjustedAvg = avgConsultationTime * typeMultiplier;
    double effectivePatientsAhead = patientsAhead * (1 - noShowRate);
    double baseWait = effectivePatientsAhead * adjustedAvg;
    return (baseWait * 1.1).roundToDouble(); // 10% safety buffer
  }

  Future<void> markAppointmentStatus(
    String appointmentId,
    String doctorId,
    String newStatus, {
    int? completedTicketNumber,
  }) async {
    final docRef = _firestore.collection('appointments').doc(appointmentId);
    final snapshot = await docRef.get();
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Appointment $appointmentId not found');
    }

    final targetStatus = QueueTransitionPolicy.normalizeStatus(newStatus);
    final currentStatus = QueueTransitionPolicy.normalizeStatus(
      data['status'] as String? ?? QueueAppointmentStatus.waiting,
    );
    final checkedIn = data['checkedIn'] == true;
    final date = data['date'] as String? ?? '';
    final ticketNumber = QueueTransitionPolicy.parseTicketNumber(
      completedTicketNumber ?? data['ticketNumber'],
    );
    final requiresDoctorScopedUpdates =
        targetStatus == QueueAppointmentStatus.inProgress ||
        targetStatus == QueueAppointmentStatus.completed ||
        targetStatus == QueueAppointmentStatus.noShow ||
        targetStatus == QueueAppointmentStatus.cancelled;
    if (requiresDoctorScopedUpdates && doctorId.trim().isEmpty) {
      throw StateError('Doctor ID is required for "$targetStatus" transition');
    }

    final validation = QueueTransitionPolicy.validate(
      fromStatus: currentStatus,
      toStatus: targetStatus,
      checkedIn: checkedIn,
    );
    if (!validation.isAllowed) {
      throw StateError(
        validation.message ?? 'Invalid appointment status transition',
      );
    }
    final shouldDecreaseActiveCount =
        QueueTransitionPolicy.isActiveStatus(currentStatus) &&
        !QueueTransitionPolicy.isActiveStatus(targetStatus);

    if (targetStatus == QueueAppointmentStatus.inProgress) {
      try {
        await docRef.update({
          'status': targetStatus,
          'consultationStartTime': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        _logDebug('Failed to update appointment status: $e');
        rethrow;
      }

      try {
        final syncedData = Map<String, dynamic>.from(data);
        syncedData['status'] = targetStatus;
        await syncPublicQueueEntryFromData(
          appointmentId: appointmentId,
          appointmentData: syncedData,
          statusOverride: targetStatus,
        );
      } catch (e) {
        _logDebug('Failed to sync public queue entry: $e');
      }

      try {
        await updateDoctorState(doctorId, 'in_consultation');
      } catch (e) {
        _logDebug('Failed to update doctor state: $e');
      }
      return;
    }

    if (targetStatus == QueueAppointmentStatus.completed) {
      final startTimestamp = data['consultationStartTime'] as Timestamp?;
      int actualDuration = 15; // fallback
      if (startTimestamp != null) {
        final startTime = startTimestamp.toDate();
        final now = DateTime.now();
        actualDuration = now.difference(startTime).inMinutes;
        if (actualDuration < 1) actualDuration = 1; // min 1 minute
      }

      try {
        await docRef.update({
          'status': targetStatus,
          'actualDurationMinutes': actualDuration,
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        _logDebug('Failed to update appointment status: $e');
        rethrow;
      }

      try {
        final syncedData = Map<String, dynamic>.from(data);
        syncedData['status'] = targetStatus;
        await syncPublicQueueEntryFromData(
          appointmentId: appointmentId,
          appointmentData: syncedData,
          statusOverride: targetStatus,
        );
      } catch (e) {
        _logDebug('Failed to sync public queue entry: $e');
      }

      if (date.isNotEmpty) {
        try {
          await _releaseSlotLockAndAdjustCounter(
            appointmentData: data,
            doctorId: doctorId,
            date: date,
            shouldDecrementActiveCount: shouldDecreaseActiveCount,
          );
        } catch (e) {
          _logDebug('Failed to release slot lock/counter: $e');
        }
      }

      try {
        await updateDoctorState(doctorId, 'available');
      } catch (e) {
        _logDebug('Failed to update doctor state: $e');
      }

      try {
        await updateDoctorAverageConsultationTime(doctorId, actualDuration);
      } catch (e) {
        _logDebug('Failed to update consultation time: $e');
      }

      if (QueueTransitionPolicy.shouldRecalculateQueue(targetStatus) &&
          date.isNotEmpty) {
        try {
          await updateQueuePositions(
            doctorId: doctorId,
            date: date,
            completedTicketNumber: ticketNumber,
          );
        } catch (e) {
          _logDebug('Failed to update queue positions: $e');
        }
      }

      final estimatedWaitTime = data['estimatedWaitTime'] as num? ?? 15;
      final patientType = data['patientType'] as String? ?? 'new';
      final now = DateTime.now();
      double accuracy =
          100.0 -
          ((estimatedWaitTime - actualDuration).abs() / actualDuration * 100);
      if (accuracy < 0) accuracy = 0;

      try {
        await logQueueAnalytics(
          doctorId: doctorId,
          date: date,
          dayOfWeek: now.weekday.toString(), // 1=Mon, 7=Sun
          hourOfDay: now.hour,
          actualDuration: actualDuration,
          estimatedDuration: estimatedWaitTime.toInt(),
          patientType: patientType,
          accuracy: accuracy,
        );
      } catch (e) {
        _logDebug('Failed to log analytics: $e');
      }
      return;
    }

    final updatePayload = <String, dynamic>{
      'status': targetStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (targetStatus == QueueAppointmentStatus.noShow) {
      updatePayload['noShowMarkedAt'] = FieldValue.serverTimestamp();
    }

    try {
      await docRef.update(updatePayload);
    } catch (e) {
      _logDebug('Failed to update appointment status: $e');
      rethrow;
    }

    try {
      final syncedData = Map<String, dynamic>.from(data);
      syncedData['status'] = targetStatus;
      await syncPublicQueueEntryFromData(
        appointmentId: appointmentId,
        appointmentData: syncedData,
        statusOverride: targetStatus,
      );
    } catch (e) {
      _logDebug('Failed to sync public queue entry: $e');
    }

    if (date.isNotEmpty) {
      try {
        await _releaseSlotLockAndAdjustCounter(
          appointmentData: data,
          doctorId: doctorId,
          date: date,
          shouldDecrementActiveCount: shouldDecreaseActiveCount,
        );
      } catch (e) {
        _logDebug('Failed to release slot lock/counter: $e');
      }
    }

    if (QueueTransitionPolicy.shouldRecalculateQueue(targetStatus) &&
        date.isNotEmpty) {
      try {
        await updateQueuePositions(
          doctorId: doctorId,
          date: date,
          completedTicketNumber: 0,
        );
      } catch (e) {
        _logDebug('Failed to update queue positions: $e');
      }
    }

    if (QueueTransitionPolicy.shouldUpdateNoShowRate(targetStatus)) {
      try {
        await updateDoctorNoShowRate(doctorId);
      } catch (e) {
        _logDebug('Failed to update no-show rate: $e');
      }
    }
  }

  String? _resolveSlotLockId(
    Map<String, dynamic> appointmentData, {
    required String doctorId,
    required String date,
  }) {
    final existingSlotLockId = appointmentData['slotLockId'] as String?;
    if (existingSlotLockId != null && existingSlotLockId.isNotEmpty) {
      return existingSlotLockId;
    }

    final timeSlot = appointmentData['timeSlot'] as String?;
    if (timeSlot == null || timeSlot.isEmpty) return null;
    final safeSlot = timeSlot.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${doctorId}_${date}_$safeSlot';
  }

  Future<void> _releaseSlotLockAndAdjustCounter({
    required Map<String, dynamic> appointmentData,
    required String doctorId,
    required String date,
    required bool shouldDecrementActiveCount,
  }) async {
    final slotLockId = _resolveSlotLockId(
      appointmentData,
      doctorId: doctorId,
      date: date,
    );

    if (slotLockId != null && slotLockId.isNotEmpty) {
      try {
        await _firestore.collection('slot_locks').doc(slotLockId).delete();
      } catch (_) {}
    }

    if (shouldDecrementActiveCount && doctorId.isNotEmpty && date.isNotEmpty) {
      await _decrementActiveCount(doctorId: doctorId, date: date);
    }
  }

  Future<void> _decrementActiveCount({
    required String doctorId,
    required String date,
    int count = 1,
  }) async {
    final counterRef = _firestore.doc('counters/tickets_${doctorId}_$date');
    await _firestore.runTransaction((transaction) async {
      final counterSnap = await transaction.get(counterRef);
      final currentActive =
          (counterSnap.data()?['activeCount'] as num?)?.toInt() ?? 0;
      final safeCount = count < 1 ? 1 : count;
      final updatedActive = currentActive > safeCount
          ? currentActive - safeCount
          : 0;
      transaction.set(counterRef, {
        'activeCount': updatedActive,
        'doctorId': doctorId,
        'date': date,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> decrementActiveCounter({
    required String doctorId,
    required String date,
    int count = 1,
  }) async {
    if (doctorId.trim().isEmpty || date.trim().isEmpty) return;
    await _decrementActiveCount(doctorId: doctorId, date: date, count: count);
  }

  Future<void> updateDoctorState(String doctorId, String newState) async {
    await _firestore.collection('doctors').doc(doctorId).update({
      'currentState': newState,
      'stateUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDoctorAverageConsultationTime(
    String doctorId,
    int actualDurationMinutes,
  ) async {
    final docRef = _firestore.collection('doctors').doc(doctorId);
    return _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data()!;
      final double oldAvg =
          (data['avgConsultationTime'] as num?)?.toDouble() ?? 15.0;
      final int totalCompleted =
          (data['totalCompletedAppointments'] as num?)?.toInt() ?? 0;

      final double newAvg =
          ((oldAvg * totalCompleted) + actualDurationMinutes) /
          (totalCompleted + 1);

      transaction.update(docRef, {
        'avgConsultationTime': newAvg,
        'totalCompletedAppointments': totalCompleted + 1,
      });
    });
  }

  Future<void> updateDoctorNoShowRate(String doctorId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final thirtyDaysAgoStr = thirtyDaysAgo.toIso8601String().substring(0, 10);

      // Composite index required: doctorId + status + date
      final completed = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: QueueAppointmentStatus.completed)
          .where('date', isGreaterThanOrEqualTo: thirtyDaysAgoStr)
          .get();

      // Composite index required: doctorId + status + date
      final noShows = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('status', isEqualTo: QueueAppointmentStatus.noShow)
          .where('date', isGreaterThanOrEqualTo: thirtyDaysAgoStr)
          .get();

      int totalCount = completed.docs.length + noShows.docs.length;
      if (totalCount == 0) return;

      int noShowCount = noShows.docs.length;
      double noShowRate = noShowCount / totalCount;

      await _firestore.collection('doctors').doc(doctorId).update({
        'noShowRate': noShowRate,
      });
    } catch (e) {
      _logDebug('QueueService: Error updating no-show rate: $e');
    }
  }

  Future<int> checkAndAutoNoShow(String doctorId, String date) async {
    final doctorDoc = await _firestore
        .collection('doctors')
        .doc(doctorId)
        .get();
    if (!doctorDoc.exists) return 0;

    final doctorData = doctorDoc.data()!;
    final int graceMinutes =
        (doctorData['graceMinutes'] as num?)?.toInt() ?? 15;

    final querySnapshot = await _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .where('date', isEqualTo: date)
        .where('status', isEqualTo: QueueAppointmentStatus.waiting)
        .get();

    final now = DateTime.now();
    int noShowCount = 0;
    final batch = _firestore.batch();

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final bool checkedIn = data['checkedIn'] ?? false;
      if (!checkedIn) {
        final timeSlot =
            data['timeSlot'] as String?; // e.g., "09:00 AM - 09:30 AM"
        if (timeSlot != null) {
          try {
            final scheduledTime = TimeUtils.parseTimeSlot(
              timeSlot,
              baseDate: now,
            );
            if (scheduledTime != null) {
              if (now.isAfter(
                scheduledTime.add(Duration(minutes: graceMinutes)),
              )) {
                batch.update(doc.reference, {
                  'status': QueueAppointmentStatus.noShow,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                batch.delete(
                  _publicQueueEntryRef(
                    doctorId: doctorId,
                    date: date,
                    appointmentId: doc.id,
                  ),
                );
                final slotLockId = _resolveSlotLockId(
                  data,
                  doctorId: doctorId,
                  date: date,
                );
                if (slotLockId != null && slotLockId.isNotEmpty) {
                  batch.delete(
                    _firestore.collection('slot_locks').doc(slotLockId),
                  );
                }
                noShowCount++;
              }
            }
          } catch (e) {
            _logDebug('Error parsing time slot for auto no-show: $e');
          }
        }
      }
    }

    if (noShowCount > 0) {
      await batch.commit();
      await decrementActiveCounter(
        doctorId: doctorId,
        date: date,
        count: noShowCount,
      );
      await updateQueuePositions(
        doctorId: doctorId,
        date: date,
        completedTicketNumber: 0,
      );
      await updateDoctorNoShowRate(doctorId);
    }

    return noShowCount;
  }

  Future<void> logQueueAnalytics({
    required String doctorId,
    required String date,
    required String dayOfWeek,
    required int hourOfDay,
    required int actualDuration,
    required int estimatedDuration,
    required String patientType,
    required double accuracy,
  }) async {
    // Legacy queue_analytics collection is intentionally deprecated.
    // Keep this method as a non-throwing hook so consultation completion flow
    // is not blocked while analytics are derived from appointments elsewhere.
    _logDebug(
      'QueueService: queue_analytics write skipped (deprecated) '
      'doctor=$doctorId date=$date day=$dayOfWeek hour=$hourOfDay '
      'actual=$actualDuration estimated=$estimatedDuration '
      'patientType=$patientType accuracy=${accuracy.toStringAsFixed(2)}',
    );
  }

  Future<void> updateQueuePositions({
    required String doctorId,
    required String date,
    required int completedTicketNumber,
  }) async {
    try {
      final doctorDoc = await _firestore
          .collection('doctors')
          .doc(doctorId)
          .get();
      if (!doctorDoc.exists) {
        _logDebug('QueueService: Doctor $doctorId not found');
        return;
      }
      final doctorData = doctorDoc.data() as Map<String, dynamic>;
      final double avgConsultationTime =
          (doctorData['avgConsultationTime'] as num?)?.toDouble() ?? 15.0;
      final double noShowRate =
          (doctorData['noShowRate'] as num?)?.toDouble() ?? 0.1;

      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: date)
          .where('status', isEqualTo: QueueAppointmentStatus.waiting)
          .get();

      final docs = querySnapshot.docs.toList();

      int priorityValue(String? p) {
        // Priority Sorting Test Scenario:
        // Input: T-001 (normal), T-002 (normal), T-003 (emergency)
        // Output Expected:
        // Position 1: T-003 (emergency - highest priority)
        // Position 2: T-001 (normal - lower ticket no.)
        // Position 3: T-002 (normal - higher ticket no.)

        if (p == 'emergency') return 1;
        if (p == 'urgent') return 2;
        return 3;
      }

      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        int pA = priorityValue(aData['priority'] as String?);
        int pB = priorityValue(bData['priority'] as String?);
        if (pA != pB) return pA.compareTo(pB);
        int tA = QueueTransitionPolicy.parseTicketNumber(aData['ticketNumber']);
        int tB = QueueTransitionPolicy.parseTicketNumber(bData['ticketNumber']);
        return tA.compareTo(tB);
      });

      if (docs.isEmpty) {
        _logDebug('QueueService: No waiting appointments to update');
        return;
      }

      final batch = _firestore.batch();
      batch.set(
        _publicQueueMetaRef(doctorId: doctorId, date: date),
        _buildPublicQueueMetaPayload(doctorId: doctorId, date: date),
        SetOptions(merge: true),
      );
      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data();
        final String patientType = data['patientType'] ?? 'new';

        final double estimatedWaitTime = calculateSmartWaitTime(
          patientsAhead: i,
          avgConsultationTime: avgConsultationTime,
          patientType: patientType,
          noShowRate: noShowRate,
        );

        batch.update(doc.reference, {
          'patientsAhead': i,
          'queuePosition': i + 1,
          'estimatedWaitTime': estimatedWaitTime,
        });

        batch.set(
          _publicQueueEntryRef(
            doctorId: doctorId,
            date: date,
            appointmentId: doc.id,
          ),
          _buildPublicQueuePayload(
            appointmentId: doc.id,
            doctorId: doctorId,
            date: date,
            timeSlot: data['timeSlot'] as String? ?? '',
            status: QueueAppointmentStatus.waiting,
            ticketNumber: QueueTransitionPolicy.parseTicketNumber(
              data['ticketNumber'],
            ),
            priority: _normalizePriority(data['priority'] as String?),
            patientsAhead: i,
            estimatedWaitTime: estimatedWaitTime,
          ),
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      _logDebug(
        'QueueService: Updated ${docs.length} appointments for doctor $doctorId on $date',
      );
    } catch (e) {
      _logDebug('QueueService: Error updating queue positions: $e');
      rethrow;
    }
  }
}
