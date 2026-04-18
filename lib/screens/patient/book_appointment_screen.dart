import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'doctor_profile_screen.dart';
import '../../utils/app_colors.dart';

class BookAppointmentScreen extends StatefulWidget {
  final String? initialSpecialization;

  const BookAppointmentScreen({super.key, this.initialSpecialization});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  late Stream<QuerySnapshot> _doctorsStream;

  late String _selectedSpecialization;
  String _selectedPriority = 'normal';

  // Helper to get priority surcharge
  int get _prioritySurcharge {
    switch (_selectedPriority) {
      case 'urgent':
        return 50;
      case 'emergency':
        return 100;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedSpecialization = widget.initialSpecialization ?? 'All';
    _doctorsStream = _createDoctorsStream();
  }

  Stream<QuerySnapshot> _createDoctorsStream() {
    return FirebaseFirestore.instance.collection('doctors').snapshots();
  }

  void _retryLoadingDoctors() {
    setState(() {
      _doctorsStream = _createDoctorsStream();
    });
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value is String ? value.trim() : value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  int _readInt(
    Map<String, dynamic> data,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toInt();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
        final parsed = num.tryParse(cleaned);
        if (parsed != null) return parsed.toInt();
      }
    }
    return fallback;
  }

  double _readDouble(
    Map<String, dynamic> data,
    List<String> keys, {
    double fallback = 0.0,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
        final parsed = num.tryParse(cleaned);
        if (parsed != null) return parsed.toDouble();
      }
    }
    return fallback;
  }

  String _readWorkingHours(Map<String, dynamic> data) {
    final raw = data['workingHours'];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    if (raw is Map) {
      final start = (raw['start'] ?? raw['from'] ?? '').toString().trim();
      final end = (raw['end'] ?? raw['to'] ?? '').toString().trim();
      if (start.isNotEmpty && end.isNotEmpty) {
        return '$start - $end';
      }
    }
    return '9:00 AM - 5:00 PM';
  }

  bool _readBool(
    Map<String, dynamic> data,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
    }
    return fallback;
  }

  String _formatDoctorsError(Object? error) {
    if (error is FirebaseException) {
      final code = error.code.trim();
      final message = (error.message ?? '').trim();
      if (code.isNotEmpty && message.isNotEmpty) return '$code: $message';
      if (message.isNotEmpty) return message;
      if (code.isNotEmpty) return code;
    }
    return 'Please check your internet connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB), // light grey-white
      body: StreamBuilder<QuerySnapshot>(
        stream: _doctorsStream,
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          return CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildSpecializationFilter(docs)),
              SliverToBoxAdapter(child: _buildPrioritySelector()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'Select a Doctor',
                    style: const TextStyle(
                      color: AppColors.textPrimary, // dark text not emerald
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _buildDoctorsList(snapshot, docs),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          );
        },
      ),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.only(left: 60, right: 20, bottom: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Appointment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose a doctor and view their profile to book.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Specialization Filter ────────────────────────────────────────

  Widget _buildSpecializationFilter(List<QueryDocumentSnapshot> docs) {
    // Derive specializations locally — no mutation of class state
    final uniqueByLower = <String, String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final specialization = _readString(data, const ['specialization']);
      if (specialization.isEmpty) continue;
      uniqueByLower.putIfAbsent(
        specialization.toLowerCase(),
        () => specialization,
      );
    }

    final specializations = [
      'All',
      ...uniqueByLower.values.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    ];

    final selectedLower = _selectedSpecialization.trim().toLowerCase();
    if (selectedLower != 'all' &&
        !specializations.any((s) => s.toLowerCase() == selectedLower)) {
      specializations.insert(1, _selectedSpecialization);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: specializations.length,
          itemBuilder: (context, index) {
            final spec = specializations[index];
            final isSelected = _selectedSpecialization == spec;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(spec),
                selected: isSelected,
                onSelected: (isSelected) {
                  setState(() {
                    _selectedSpecialization = isSelected ? spec : 'All';
                  });
                },
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                elevation: isSelected ? 2 : 0,
                pressElevation: 1,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appointment Priority',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPriorityChip('normal', 'Normal'),
                const SizedBox(width: 8),
                _buildPriorityChip('urgent', 'Urgent (+50 EGP)'),
                const SizedBox(width: 8),
                _buildPriorityChip('emergency', 'Emergency (+100 EGP)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label) {
    final isSelected = _selectedPriority == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPriority = value);
        }
      },
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.25),
        width: 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }

  // ─── Doctors List ─────────────────────────────────────────────────

  Widget _buildDoctorsList(
    AsyncSnapshot<QuerySnapshot> snapshot,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return SliverToBoxAdapter(
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          itemBuilder: (_, __) => Shimmer.fromColors(
            baseColor: AppColors.divider,
            highlightColor: AppColors.background,
            child: Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }
    if (snapshot.hasError) {
      final errorMessage = _formatDoctorsError(snapshot.error);
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.error,
                    size: 26,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Could not load doctors',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _retryLoadingDoctors,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (allDocs.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'No doctors available at the moment.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter by specialization (and allow partial matches for seeded queries).
    var docs = allDocs;
    docs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final accountStatus = _readString(data, const [
        'accountStatus',
      ], fallback: 'active').toLowerCase();
      return accountStatus == 'active' || accountStatus == 'approved';
    }).toList();

    if (_selectedSpecialization != 'All') {
      final selectedLower = _selectedSpecialization.trim().toLowerCase();
      docs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final specialization = _readString(data, const [
          'specialization',
        ]).toLowerCase();
        final name = _readString(data, const ['name']).toLowerCase();
        final specializationMatches =
            specialization.isNotEmpty &&
            (specialization == selectedLower ||
                specialization.contains(selectedLower) ||
                selectedLower.contains(specialization));
        return specializationMatches || name.contains(selectedLower);
      }).toList();
    }

    if (docs.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text(
              'No doctors found for "$_selectedSpecialization".',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          return _buildDoctorCard(doc.id, data);
        }, childCount: docs.length),
      ),
    );
  }

  Widget _buildDoctorCard(String doctorId, Map<String, dynamic> data) {
    final String name = _readString(data, const [
      'name',
    ], fallback: 'Unknown Doctor');
    final String specialization = _readString(data, const [
      'specialization',
    ], fallback: 'General');
    final String qualification = _readString(data, const ['qualification']);
    final int experience = _readInt(data, const ['experience'], fallback: 0);
    final double rating = _readDouble(data, const [
      'rating',
    ], fallback: 0.0).clamp(0.0, 5.0);
    final int parsedAvgTime = _readInt(data, const [
      'avgConsultationTime',
    ], fallback: 15);
    final int avgTime = parsedAvgTime > 0 ? parsedAvgTime : 15;
    final String workingHours = _readWorkingHours(data);
    final int baseFee = _readInt(data, const ['consultationFee'], fallback: 0);
    final imageUrl = _readString(data, const ['imageUrl', 'profileImageUrl']);
    final isAvailable = _readBool(data, const ['isAvailable'], fallback: true);
    final accountStatus = _readString(data, const [
      'accountStatus',
    ], fallback: 'active').toLowerCase();
    final isAccountBookable =
        accountStatus == 'active' || accountStatus == 'approved';
    final isBookable = isAvailable && isAccountBookable;
    final availabilityColor = isBookable ? AppColors.success : AppColors.error;
    final availabilityLabel = isBookable ? 'Available' : 'Unavailable';
    final totalFee = baseFee + _prioritySurcharge;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (!isBookable) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This doctor is currently unavailable for booking.',
                ),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorProfileScreen(
                doctorId: doctorId,
                doctorData: data,
                initialPriority: _selectedPriority,
              ),
            ),
          );
        },
        child: Opacity(
          opacity: isBookable ? 1.0 : 0.78,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isBookable
                    ? AppColors.divider
                    : availabilityColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: 'doctor_$doctorId',
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
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
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              specialization,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (qualification.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                qualification,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: availabilityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: availabilityColor.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: Text(
                                availabilityLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: availabilityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isBookable
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : AppColors.textSecondary.withValues(
                                      alpha: 0.12,
                                    ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBookable
                                  ? Icons.arrow_forward_ios
                                  : Icons.lock_clock_outlined,
                              size: 14,
                              color: isBookable
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isBookable
                                  ? AppColors.primaryLight
                                  : AppColors.divider.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isBookable
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.textSecondary.withValues(
                                        alpha: 0.2,
                                      ),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              totalFee == 0 ? 'Free' : '$totalFee EGP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isBookable
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatItem(
                          Icons.work_history_outlined,
                          '$experience yrs',
                          'Exp.',
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          Icons.star,
                          rating.toStringAsFixed(1),
                          'Rating',
                          iconColor: AppColors.warning,
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          Icons.timer_outlined,
                          '$avgTime min',
                          'Avg. Time',
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          Icons.access_time_outlined,
                          workingHours,
                          'Hours',
                          small: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label, {
    Color? iconColor,
    bool small = false,
  }) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: AppColors.divider);
  }
}
