import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/doctor_model.dart';

/// Provider for managing doctors data and state
class DoctorProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State
  List<DoctorModel> _doctors = [];
  List<DoctorModel> _filteredDoctors = [];
  bool _isLoading = false;
  String? _error;
  String _selectedSpecialization = 'All';

  // Getters
  List<DoctorModel> get doctors => _doctors;
  List<DoctorModel> get filteredDoctors => _filteredDoctors;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedSpecialization => _selectedSpecialization;

  /// Get available doctors (isAvailable = true)
  List<DoctorModel> get availableDoctors =>
      _doctors.where((doc) => doc.isAvailableNow).toList();

  /// Get top-rated doctors (rating >= 4.5)
  List<DoctorModel> get topRatedDoctors =>
      _doctors.where((doc) => doc.rating >= 4.5).toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));

  // Stream subscription
  StreamSubscription<QuerySnapshot>? _doctorsSubscription;

  /// Initialize and start listening to doctors collection
  void initialize() {
    _listenToDoctors();
  }

  /// Listen to real-time doctor updates
  void _listenToDoctors() {
    _isLoading = true;
    notifyListeners();

    _doctorsSubscription = _firestore
        .collection('doctors')
        .snapshots()
        .listen(
          (snapshot) {
            _doctors = snapshot.docs
                .map((doc) => DoctorModel.fromFirestore(doc))
                .toList();
            _applyFilter();
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            _error = 'Failed to load doctors: $error';
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  /// Filter doctors by specialization
  void filterBySpecialization(String specialization) {
    _selectedSpecialization = specialization;
    _applyFilter();
    notifyListeners();
  }

  /// Apply current filter
  void _applyFilter() {
    if (_selectedSpecialization == 'All') {
      _filteredDoctors = _doctors;
    } else {
      _filteredDoctors = _doctors
          .where((doc) => doc.specialization == _selectedSpecialization)
          .toList();
    }
  }

  /// Search doctors by name or specialization
  void searchDoctors(String query) {
    if (query.isEmpty) {
      _filteredDoctors = _doctors;
    } else {
      final lowerQuery = query.toLowerCase();
      _filteredDoctors = _doctors.where((doctor) {
        return doctor.name.toLowerCase().contains(lowerQuery) ||
            doctor.specialization.toLowerCase().contains(lowerQuery);
      }).toList();
    }
    notifyListeners();
  }

  /// Get doctor by ID
  Future<DoctorModel?> getDoctorById(String doctorId) async {
    try {
      final doc = await _firestore.collection('doctors').doc(doctorId).get();
      if (doc.exists) {
        return DoctorModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _error = 'Failed to fetch doctor: $e';
      notifyListeners();
      return null;
    }
  }

  /// Update doctor availability status
  Future<void> updateDoctorAvailability(
    String doctorId,
    bool isAvailable,
    String currentState,
  ) async {
    try {
      await _firestore.collection('doctors').doc(doctorId).update({
        'isAvailable': isAvailable,
        'currentState': currentState,
      });
    } catch (e) {
      _error = 'Failed to update doctor availability: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get all unique specializations
  List<String> getSpecializations() {
    final specs = _doctors.map((doc) => doc.specialization).toSet().toList();
    specs.sort();
    return ['All', ...specs];
  }

  @override
  void dispose() {
    _doctorsSubscription?.cancel();
    super.dispose();
  }
}
