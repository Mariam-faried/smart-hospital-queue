import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../services/queue_service.dart';
import '../services/queue_transition_policy.dart';

/// Provider for managing appointments data and state
class AppointmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _toYmd(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // State
  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AppointmentModel> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get upcoming appointments
  List<AppointmentModel> get upcomingAppointments =>
      _appointments.where((apt) => apt.isUpcoming).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// Get completed appointments
  List<AppointmentModel> get completedAppointments =>
      _appointments.where((apt) => apt.isCompleted).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Get cancelled appointments
  List<AppointmentModel> get cancelledAppointments =>
      _appointments.where((apt) => apt.isCancelled).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  // Stream subscription
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  /// Listen to patient appointments
  void listenToPatientAppointments(String patientId) {
    _isLoading = true;
    notifyListeners();

    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .listen(
          (snapshot) {
            _appointments = snapshot.docs
                .map((doc) => AppointmentModel.fromFirestore(doc))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load appointments: $error';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Listen to doctor appointments
  void listenToDoctorAppointments(String doctorId) {
    _isLoading = true;
    notifyListeners();

    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .snapshots()
        .listen(
          (snapshot) {
            _appointments = snapshot.docs
                .map((doc) => AppointmentModel.fromFirestore(doc))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load appointments: $error';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Listen to all appointments (for receptionist/admin)
  void listenToAllAppointments() {
    _isLoading = true;
    notifyListeners();

    _appointmentsSubscription?.cancel();
    _appointmentsSubscription = _firestore
        .collection('appointments')
        .snapshots()
        .listen(
          (snapshot) {
            _appointments = snapshot.docs
                .map((doc) => AppointmentModel.fromFirestore(doc))
                .toList();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load appointments: $error';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Get appointments for specific doctor and date
  Future<List<AppointmentModel>> getAppointmentsByDoctorAndDate(
    String doctorId,
    DateTime date,
  ) async {
    try {
      final dateStr = _toYmd(date);
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshotsById = <String, QueryDocumentSnapshot>{};

      // Canonical format: string date ("yyyy-MM-dd")
      final stringSnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isEqualTo: dateStr)
          .get();
      for (final doc in stringSnapshot.docs) {
        snapshotsById[doc.id] = doc;
      }

      // Backward compatibility for legacy docs with Timestamp date.
      final legacySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      for (final doc in legacySnapshot.docs) {
        snapshotsById.putIfAbsent(doc.id, () => doc);
      }

      return snapshotsById.values
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _error = 'Failed to fetch appointments: $e';
      notifyListeners();
      return [];
    }
  }

  /// Update appointment status
  Future<void> updateAppointmentStatus(
    String appointmentId,
    String status,
  ) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (status == QueueAppointmentStatus.completed)
          'completedAt': FieldValue.serverTimestamp(),
      });
      await QueueService(
        firestore: _firestore,
      ).syncPublicQueueEntryByAppointmentId(appointmentId);
    } catch (e) {
      _error = 'Failed to update appointment status: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Check in patient
  Future<void> checkInPatient(String appointmentId) async {
    try {
      await QueueService(firestore: _firestore).checkInPatient(appointmentId);
    } catch (e) {
      _error = 'Failed to check in patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Cancel appointment
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      final doc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
      final doctorId = doc.data()?['doctorId'] as String? ?? '';
      if (doctorId.isEmpty) {
        throw StateError('Doctor ID not found for appointment $appointmentId');
      }

      await QueueService().markAppointmentStatus(
        appointmentId,
        doctorId,
        QueueAppointmentStatus.cancelled,
      );
    } catch (e) {
      _error = 'Failed to cancel appointment: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get appointment by ID
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final doc = await _firestore
          .collection('appointments')
          .doc(appointmentId)
          .get();
      if (doc.exists) {
        return AppointmentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = 'Failed to fetch appointment: $e';
      notifyListeners();
      return null;
    }
  }

  /// Stop listening to appointments
  void stopListening() {
    _appointmentsSubscription?.cancel();
    _appointments = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }
}
