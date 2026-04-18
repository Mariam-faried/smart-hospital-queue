import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/patient/doctor_stats_card.dart';
import '../../widgets/patient/doctor_reviews_section.dart';
import '../../widgets/patient/doctor_schedule_picker.dart';
import '../../widgets/patient/booking_bottom_bar.dart';
import '../../services/booking_service.dart';
import '../../services/queue_transition_policy.dart';
import '../../utils/app_colors.dart';
import '../../widgets/patient/doctor_queue_card.dart';
import '../../widgets/patient/doctor_hospital_info.dart';
import '../../widgets/patient/doctor_profile_app_bar.dart';
import '../../widgets/patient/doctor_quick_actions.dart';
import '../../widgets/patient/doctor_about_section.dart';
import '../../widgets/patient/doctor_working_info.dart';
import '../../widgets/patient/doctor_schedule_header.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  final String? initialPriority;
  final String? appointmentIdToCancel;

  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    required this.doctorData,
    this.initialPriority,
    this.appointmentIdToCancel,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  DateTime? _selectedDay;
  String? _selectedTimeSlot;
  String _selectedPatientType = 'new';
  late String _priority;
  bool _isBooking = false;
  bool _isCheckingSlot = false;
  final Map<String, List<String>> _bookedSlotsCache = {};

  Stream<QuerySnapshot>? _reviewsStream;
  Stream<QuerySnapshot>? _bookedSlotsStream;
  String? _bookedSlotsStreamDate;

  late final String _name,
      _specialization,
      _qualification,
      _workingHours,
      _workingDays,
      _about,
      _currency;
  late final double _initialRating;
  double _currentRating = 0.0;
  late final int _experience,
      _totalPatients,
      _avgConsultationTime,
      _initialReviewCount;
  int _currentReviewCount = 0;
  late final num _consultationFee;
  late final bool _isAvailable;
  bool _isSubmittingReview = false;

  int get _prioritySurcharge {
    switch (_priority) {
      case 'urgent':
        return 50;
      case 'emergency':
        return 100;
      default:
        return 0;
    }
  }

  String get _priorityLabel {
    switch (_priority) {
      case 'urgent':
        return 'Urgent';
      case 'emergency':
        return 'Emergency';
      default:
        return 'Normal';
    }
  }

  String _normalizePriority(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'urgent':
      case 'emergency':
      case 'normal':
        return value!.trim().toLowerCase();
      default:
        return 'normal';
    }
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value is String ? value.trim() : value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _readInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      final parsed = num.tryParse(cleaned);
      if (parsed != null) return parsed.toInt();
    }
    return fallback;
  }

  double _readDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      final parsed = num.tryParse(cleaned);
      if (parsed != null) return parsed.toDouble();
    }
    return fallback;
  }

  bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  String _readWorkingHours(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Map) {
      final start = _readString(value['start'] ?? value['from']);
      final end = _readString(value['end'] ?? value['to']);
      if (start.isNotEmpty && end.isNotEmpty) {
        return '$start - $end';
      }
    }
    return '9:00 AM - 5:00 PM';
  }

  String _readWorkingDays(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List) {
      final days = value
          .map((item) => _readString(item))
          .where((item) => item.isNotEmpty)
          .toList();
      if (days.isNotEmpty) return days.join(', ');
    }
    return 'Mon-Fri';
  }

  @override
  void initState() {
    super.initState();
    _priority = _normalizePriority(widget.initialPriority);
    final d = widget.doctorData;
    _name = _readString(d['name'], fallback: 'Unknown Doctor');
    _specialization = _readString(d['specialization'], fallback: 'General');
    _qualification = _readString(d['qualification']);
    _initialRating = _readDouble(d['rating'], fallback: 0.0).clamp(0.0, 5.0);
    _currentRating = _initialRating;
    _experience = _readInt(d['experience'], fallback: 0);
    _totalPatients = _readInt(d['totalPatients'], fallback: _experience * 200);
    final parsedAvgConsultationTime = _readInt(
      d['avgConsultationTime'],
      fallback: 15,
    );
    _avgConsultationTime = parsedAvgConsultationTime > 0
        ? parsedAvgConsultationTime
        : 15;
    _workingHours = _readWorkingHours(d['workingHours']);
    _workingDays = _readWorkingDays(d['workingDays']);
    final aboutText = _readString(d['about']);
    _about = aboutText.isNotEmpty
        ? aboutText
        : '$_name is a highly experienced $_specialization specialist with $_experience years of practice dedicated to providing exceptional patient care.';
    _consultationFee = _readDouble(d['consultationFee'], fallback: 0.0);
    _currency = _readString(d['currency'], fallback: 'EGP');
    _isAvailable = _readBool(d['isAvailable'], fallback: true);
    _initialReviewCount = _readInt(
      d['reviewCount'],
      fallback: _readInt(d['totalReviews'], fallback: _experience * 40),
    );
    _currentReviewCount = _initialReviewCount;

    _reviewsStream = FirebaseFirestore.instance
        .collection('doctors')
        .doc(widget.doctorId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  void _updateBookedSlotsStream(DateTime day) {
    final dateString = DateFormat('yyyy-MM-dd').format(day);

    if (_bookedSlotsStreamDate == dateString && _bookedSlotsStream != null) {
      return;
    }
    final queueKey = '${widget.doctorId}_$dateString';

    setState(() {
      _bookedSlotsStreamDate = dateString;
      _bookedSlotsStream = FirebaseFirestore.instance
          .collection('queue_public')
          .doc(queueKey)
          .collection('entries')
          .snapshots();
    });
  }

  int _parseReviewStars(dynamic value, {int fallback = 5}) {
    final parsed = _readInt(value, fallback: fallback);
    return parsed.clamp(1, 5).toInt();
  }

  Future<void> _openReviewDialog({
    required String patientId,
    required String patientName,
    Map<String, dynamic>? existingReview,
  }) async {
    final draft = await showDialog<_ReviewDraft>(
      context: context,
      builder: (_) => _ReviewEditorDialog(
        isEdit: existingReview != null,
        initialStars: _parseReviewStars(existingReview?['stars'], fallback: 5),
        initialComment: (existingReview?['text'] as String? ?? '').trim(),
      ),
    );
    if (draft == null) return;

    // Let the dialog route fully settle before mutating parent state/workflows.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    await _submitReview(
      patientId: patientId,
      patientName: patientName,
      stars: draft.stars,
      comment: draft.comment,
    );
  }

  Future<void> _submitReview({
    required String patientId,
    required String patientName,
    required int stars,
    required String comment,
  }) async {
    if (_isSubmittingReview) return;
    if (mounted) {
      setState(() => _isSubmittingReview = true);
    } else {
      _isSubmittingReview = true;
    }

    final normalizedComment = comment.trim();
    final normalizedName = patientName.trim().isEmpty
        ? 'Patient'
        : patientName.trim();

    try {
      final reviewRef = FirebaseFirestore.instance
          .collection('doctors')
          .doc(widget.doctorId)
          .collection('reviews')
          .doc(patientId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existing = await transaction.get(reviewRef);
        final payload = <String, dynamic>{
          'patientId': patientId,
          'patientName': normalizedName,
          'rating': stars.clamp(1, 5),
          'comment': normalizedComment,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (existing.exists) {
          transaction.update(reviewRef, payload);
        } else {
          transaction.set(reviewRef, {
            ...payload,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted successfully.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'You are not allowed to submit this review right now.'
          : 'Could not submit review. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit review. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      } else {
        _isSubmittingReview = false;
      }
    }
  }

  void _syncDisplayedRating({
    required double averageRating,
    required int reviewCount,
  }) {
    final normalizedRating = averageRating.clamp(0.0, 5.0).toDouble();
    final normalizedCount = reviewCount < 0 ? 0 : reviewCount;
    final ratingChanged = (_currentRating - normalizedRating).abs() >= 0.001;
    final countChanged = _currentReviewCount != normalizedCount;
    if (!ratingChanged && !countChanged) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentRating = normalizedRating;
        _currentReviewCount = normalizedCount;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.uid;
    final canSubmitReview =
        authProvider.userRole == 'patient' && currentUserId != null;
    final patientName = authProvider.userName.trim().isEmpty
        ? 'Patient'
        : authProvider.userName.trim();

    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      body: CustomScrollView(
        slivers: [
          DoctorProfileAppBar(
            doctorId: widget.doctorId,
            doctorData: widget.doctorData,
            name: _name,
            specialization: _specialization,
            qualification: _qualification,
            rating: _currentRating,
            totalPatients: _totalPatients,
            isAvailable: _isAvailable,
          ),
          SliverToBoxAdapter(
            child: DoctorStatsCard(
              totalPatients: _totalPatients,
              experience: _experience,
              rating: _currentRating,
              consultationFee: _consultationFee,
              currency: _currency,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Center(
                child: Text(
                  'Consultation fee is paid at the hospital',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DoctorQueueCard(
              doctorId: widget.doctorId,
              avgConsultationTime: _avgConsultationTime,
            ),
          ),
          SliverToBoxAdapter(
            child: DoctorQuickActions(
              doctorId: widget.doctorId,
              phoneNumber: _readString(widget.doctorData['phone']).isNotEmpty
                  ? _readString(widget.doctorData['phone'])
                  : _readString(widget.doctorData['phoneNumber']),
              doctorName: _name,
            ),
          ),
          SliverToBoxAdapter(child: DoctorAboutSection(about: _about)),
          SliverToBoxAdapter(
            child: DoctorHospitalInfo(doctorData: widget.doctorData),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: _reviewsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return DoctorReviewsSection(
                    averageRating: _currentRating,
                    reviewCount: _currentReviewCount,
                    reviews: const [],
                    isLoading: true,
                    canSubmitReview: canSubmitReview,
                    isSubmittingReview: _isSubmittingReview,
                  );
                }

                List<Map<String, dynamic>> reviews;
                Map<String, dynamic>? currentUserReview;
                double sectionAverageRating = _currentRating;
                int sectionReviewCount = _currentReviewCount;
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  reviews = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'patientId': (data['patientId'] as String? ?? '').trim(),
                      'name': data['patientName'] ?? 'Patient',
                      'stars': _parseReviewStars(data['rating']),
                      'text': data['comment'] ?? '',
                      'timeAgo': _formatTimeAgo(data['createdAt']),
                    };
                  }).toList();

                  final totalStars = reviews.fold<int>(
                    0,
                    (runningTotal, item) =>
                        runningTotal + _parseReviewStars(item['stars']),
                  );
                  sectionReviewCount = reviews.length;
                  sectionAverageRating = sectionReviewCount == 0
                      ? 0.0
                      : totalStars / sectionReviewCount;

                  if (currentUserId != null) {
                    for (final review in reviews) {
                      if ((review['patientId'] as String?) == currentUserId) {
                        currentUserReview = review;
                        break;
                      }
                    }
                  }
                } else {
                  reviews = const [];
                  sectionAverageRating = _initialRating;
                  sectionReviewCount = _initialReviewCount;
                }

                _syncDisplayedRating(
                  averageRating: sectionAverageRating,
                  reviewCount: sectionReviewCount,
                );

                return DoctorReviewsSection(
                  averageRating: sectionAverageRating,
                  reviewCount: sectionReviewCount,
                  reviews: reviews.take(5).toList(),
                  canSubmitReview: canSubmitReview,
                  hasCurrentUserReview: currentUserReview != null,
                  isSubmittingReview: _isSubmittingReview,
                  onSubmitReview: canSubmitReview
                      ? () => _openReviewDialog(
                          patientId: currentUserId,
                          patientName: patientName,
                          existingReview: currentUserReview,
                        )
                      : null,
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: DoctorWorkingInfo(
              workingHours: _workingHours,
              workingDays: _workingDays,
            ),
          ),
          SliverToBoxAdapter(
            child: DoctorScheduleHeader(
              avgConsultationTime: _avgConsultationTime,
              workingHours: _workingHours,
              workingDays: _workingDays,
            ),
          ),
          SliverToBoxAdapter(
            child: _selectedDay == null
                ? DoctorSchedulePicker(
                    workingDays: _workingDays,
                    workingHours: _workingHours,
                    avgConsultationTime: _avgConsultationTime,
                    bookedSlots: const [],
                    selectedDay: _selectedDay,
                    selectedTimeSlot: _selectedTimeSlot,
                    onDateSelected: (day) {
                      setState(() {
                        _selectedDay = day;
                        _selectedTimeSlot = null;
                      });
                      _updateBookedSlotsStream(day);
                    },
                    onSlotSelected: (slot) => setState(
                      () => _selectedTimeSlot = _selectedTimeSlot == slot
                          ? null
                          : slot,
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _bookedSlotsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return DoctorSchedulePicker(
                          workingDays: _workingDays,
                          workingHours: _workingHours,
                          avgConsultationTime: _avgConsultationTime,
                          bookedSlots: const [],
                          selectedDay: _selectedDay,
                          selectedTimeSlot: _selectedTimeSlot,
                          onDateSelected: (day) {
                            setState(() {
                              _selectedDay = day;
                              _selectedTimeSlot = null;
                            });
                            _updateBookedSlotsStream(day);
                          },
                          onSlotSelected: (_) {}, // disable selection on error
                          errorMessage:
                              'Unable to load availability. Please try again.',
                        );
                      }

                      List<String> bookedSlots = [];
                      final selectedDateKey = _bookedSlotsStreamDate;
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        if (selectedDateKey != null) {
                          bookedSlots =
                              _bookedSlotsCache[selectedDateKey] ??
                              const <String>[];
                        }
                      } else if (snapshot.hasData) {
                        final uniqueSlots = <String>{};
                        for (final doc in snapshot.data!.docs) {
                          final slot =
                              (doc.data() as Map<String, dynamic>)['timeSlot'];
                          if (slot is String && slot.trim().isNotEmpty) {
                            uniqueSlots.add(slot.trim());
                          }
                        }
                        bookedSlots = uniqueSlots.toList();
                        if (selectedDateKey != null) {
                          _bookedSlotsCache[selectedDateKey] = bookedSlots;
                        }
                      }

                      if (_selectedTimeSlot != null &&
                          bookedSlots.contains(_selectedTimeSlot)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (_selectedTimeSlot != null &&
                              bookedSlots.contains(_selectedTimeSlot)) {
                            setState(() => _selectedTimeSlot = null);
                          }
                        });
                      }

                      return DoctorSchedulePicker(
                        workingDays: _workingDays,
                        workingHours: _workingHours,
                        avgConsultationTime: _avgConsultationTime,
                        bookedSlots: bookedSlots,
                        selectedDay: _selectedDay,
                        selectedTimeSlot: _selectedTimeSlot,
                        onDateSelected: (day) {
                          setState(() {
                            _selectedDay = day;
                            _selectedTimeSlot = null;
                          });
                          _updateBookedSlotsStream(day);
                        },
                        onSlotSelected: (slot) => setState(
                          () => _selectedTimeSlot = _selectedTimeSlot == slot
                              ? null
                              : slot,
                        ),
                      );
                    },
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: BookingBottomBar(
        selectedDay: _selectedDay,
        selectedTimeSlot: _selectedTimeSlot,
        isBooking: _isBooking,
        isCheckingSlot: _isCheckingSlot,
        selectedPatientType: _selectedPatientType,
        onPatientTypeChanged: (type) =>
            setState(() => _selectedPatientType = type),
        onBookPressed: _handleBooking,
        isAvailable: _isAvailable,
      ),
    );
  }

  Future<bool> _verifySelectedSlotAvailability() async {
    final day = _selectedDay;
    final slot = _selectedTimeSlot;
    if (day == null || slot == null) return false;

    final dateString = DateFormat('yyyy-MM-dd').format(day);
    final queueKey = '${widget.doctorId}_$dateString';

    try {
      final queueEntryFuture = FirebaseFirestore.instance
          .collection('queue_public')
          .doc(queueKey)
          .collection('entries')
          .where('timeSlot', isEqualTo: slot)
          .limit(1)
          .get();

      final queueEntrySnapshot = await queueEntryFuture;

      final isTakenByQueue = queueEntrySnapshot.docs.any((doc) {
        final status = ((doc.data())['status'] as String? ?? '')
            .trim()
            .toLowerCase();
        return QueueAppointmentStatus.activeSet.contains(status);
      });
      if (!isTakenByQueue) return true;

      if (mounted) {
        setState(() => _selectedTimeSlot = null);
        _updateBookedSlotsStream(day);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This slot was just booked. Please choose another time.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return false;
    } on FirebaseException catch (error) {
      if (mounted) {
        final message = error.code == 'permission-denied'
            ? 'Could not pre-verify slot availability. We will verify during booking.'
            : 'Could not verify slot availability. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
      if (error.code == 'permission-denied') {
        return true;
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not verify slot availability. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _handleBooking() async {
    if (_selectedDay == null ||
        _selectedTimeSlot == null ||
        _isBooking ||
        _isCheckingSlot) {
      return;
    }

    setState(() => _isCheckingSlot = true);
    final isSlotAvailable = await _verifySelectedSlotAvailability();
    if (mounted) {
      setState(() => _isCheckingSlot = false);
    }
    if (!isSlotAvailable || !mounted) return;

    // Confirmation dialog
    final dateStr = DateFormat('MMM dd, yyyy').format(_selectedDay!);
    final baseFee = _consultationFee.toInt();
    final surcharge = _prioritySurcharge;
    final totalFee = baseFee + surcharge;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.event_available, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Confirm Booking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow(Icons.person, 'Doctor', _name),
            const SizedBox(height: 8),
            _confirmRow(Icons.calendar_today, 'Date', dateStr),
            const SizedBox(height: 8),
            _confirmRow(Icons.access_time, 'Time', _selectedTimeSlot!),
            const SizedBox(height: 8),
            _confirmRow(
              Icons.local_fire_department_outlined,
              'Priority',
              _priorityLabel,
            ),
            const SizedBox(height: 8),
            _confirmRow(
              Icons.payments_outlined,
              'Fee',
              totalFee == 0 ? 'Free' : '$totalFee $_currency',
            ),
            if (surcharge > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Includes +$surcharge $_currency priority surcharge',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Duplicate appointment check
    try {
      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.user?.uid;
      if (uid != null) {
        final existing = await FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: uid)
            .where('doctorId', isEqualTo: widget.doctorId)
            .where('status', whereIn: QueueAppointmentStatus.activeList)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Existing Appointment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                'You already have an active appointment with this doctor. Do you still want to book another one?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Book Anyway',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (proceed != true || !mounted) return;
        }
      }
    } catch (_) {
      // Non-blocking: continue with booking if duplicate check fails
    }

    // Proceed with booking
    if (!mounted) return;
    setState(() => _isBooking = true);
    try {
      await BookingService().bookAppointment(
        context: context,
        doctorId: widget.doctorId,
        doctorName: _name,
        specialization: _specialization,
        consultationFee: _consultationFee,
        doctorData: widget.doctorData,
        selectedDay: _selectedDay!,
        selectedTimeSlot: _selectedTimeSlot!,
        selectedPatientType: _selectedPatientType,
        priority: _priority,
        avgConsultationTime: _avgConsultationTime,
        currency: _currency,
        appointmentIdToCancel: widget.appointmentIdToCancel,
      );
    } on BookingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final date = (timestamp as Timestamp).toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inDays < 1) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      final weeks = (diff.inDays / 7).floor();
      if (diff.inDays < 30) {
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      }
      final months = (diff.inDays / 30).floor();
      if (diff.inDays < 365) {
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      }
      final years = (diff.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } catch (_) {
      return 'Recently';
    }
  }
}

class _ReviewDraft {
  final int stars;
  final String comment;

  const _ReviewDraft({required this.stars, required this.comment});
}

class _ReviewEditorDialog extends StatefulWidget {
  final bool isEdit;
  final int initialStars;
  final String initialComment;

  const _ReviewEditorDialog({
    required this.isEdit,
    required this.initialStars,
    required this.initialComment,
  });

  @override
  State<_ReviewEditorDialog> createState() => _ReviewEditorDialogState();
}

class _ReviewEditorDialogState extends State<_ReviewEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _commentController;
  late int _selectedStars;

  @override
  void initState() {
    super.initState();
    _selectedStars = widget.initialStars.clamp(1, 5).toInt();
    _commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ReviewDraft(
        stars: _selectedStars,
        comment: _commentController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      scrollable: true,
      title: Text(widget.isEdit ? 'Edit Review' : 'Rate This Doctor'),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your rating',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: List.generate(5, (index) {
                  final starNumber = index + 1;
                  final isActive = starNumber <= _selectedStars;
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() => _selectedStars = starNumber);
                    },
                    icon: Icon(
                      isActive ? Icons.star_rounded : Icons.star_outline,
                      color: AppColors.warning,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _commentController,
                textInputAction: TextInputAction.done,
                minLines: 3,
                maxLines: 5,
                maxLength: 320,
                decoration: InputDecoration(
                  hintText: 'Share your experience with this doctor...',
                  filled: true,
                  fillColor: AppColors.surfaceGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Please write a short review.';
                  if (text.length < 6) {
                    return 'Review is too short. Please add more details.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
