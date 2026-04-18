import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import 'doctor_profile_screen.dart';

class DoctorSearchScreen extends StatefulWidget {
  final String initialQuery;

  const DoctorSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Stream<QuerySnapshot> _doctorsStream =
      FirebaseFirestore.instance.collection('doctors').snapshots();

  String _query = '';
  String _selectedSpecialization = 'All';
  String _selectedAvailability = 'all';
  String _selectedSort = 'rating_desc';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim().toLowerCase();
    _searchController.text = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _readText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final normalized = value is String ? value.trim() : value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  num _readNum(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      final parsed = num.tryParse(cleaned);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    return fallback;
  }

  bool _isDoctorAvailable(Map<String, dynamic> data) {
    final accountStatus = _readText(
      data['accountStatus'],
      fallback: 'active',
    ).toLowerCase();
    if (accountStatus != 'active' && accountStatus != 'approved') {
      return false;
    }
    return _readBool(data['isAvailable'], fallback: true);
  }

  double _ratingOf(Map<String, dynamic> data) {
    return _readNum(data['rating'], fallback: 0).toDouble();
  }

  num _feeOf(Map<String, dynamic> data) {
    return _readNum(data['consultationFee'], fallback: 0);
  }

  List<QueryDocumentSnapshot> _filterAndSortDoctors(
    List<QueryDocumentSnapshot> docs,
  ) {
    final query = _query.trim();
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = _readText(data['name']).toLowerCase();
      final specialization = _readText(data['specialization']).toLowerCase();
      final accountStatus = _readText(
        data['accountStatus'],
        fallback: 'active',
      ).toLowerCase();
      if (accountStatus != 'active' && accountStatus != 'approved') {
        return false;
      }

      if (query.isNotEmpty &&
          !name.contains(query) &&
          !specialization.contains(query)) {
        return false;
      }

      if (_selectedSpecialization != 'All') {
        final selected = _selectedSpecialization.toLowerCase();
        if (specialization != selected) return false;
      }

      if (_selectedAvailability == 'available' && !_isDoctorAvailable(data)) {
        return false;
      }
      if (_selectedAvailability == 'unavailable' && _isDoctorAvailable(data)) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      switch (_selectedSort) {
        case 'fee_asc':
          return _feeOf(aData).compareTo(_feeOf(bData));
        case 'fee_desc':
          return _feeOf(bData).compareTo(_feeOf(aData));
        case 'name_asc':
          return _readText(
            aData['name'],
            fallback: 'Unknown',
          ).toLowerCase().compareTo(
            _readText(bData['name'], fallback: 'Unknown').toLowerCase(),
          );
        case 'rating_desc':
        default:
          return _ratingOf(bData).compareTo(_ratingOf(aData));
      }
    });

    return filtered;
  }

  List<String> _extractSpecializations(List<QueryDocumentSnapshot> docs) {
    final uniqueByLower = <String, String>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final accountStatus = _readText(
        data['accountStatus'],
        fallback: 'active',
      ).toLowerCase();
      if (accountStatus != 'active' && accountStatus != 'approved') continue;

      final specialization = _readText(data['specialization']);
      if (specialization.isEmpty) continue;
      uniqueByLower.putIfAbsent(
        specialization.toLowerCase(),
        () => specialization,
      );
    }
    final values = uniqueByLower.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...values];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: const Text('Search Doctors'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            color: AppColors.cardBackground,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _query = value.trim().toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by doctor or specialization',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip(
                        label: 'Top Rated',
                        selected: _selectedSort == 'rating_desc',
                        onTap: () => setState(() => _selectedSort = 'rating_desc'),
                      ),
                      _chip(
                        label: 'Fee Low-High',
                        selected: _selectedSort == 'fee_asc',
                        onTap: () => setState(() => _selectedSort = 'fee_asc'),
                      ),
                      _chip(
                        label: 'Fee High-Low',
                        selected: _selectedSort == 'fee_desc',
                        onTap: () => setState(() => _selectedSort = 'fee_desc'),
                      ),
                      _chip(
                        label: 'A-Z',
                        selected: _selectedSort == 'name_asc',
                        onTap: () => setState(() => _selectedSort = 'name_asc'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _doctorsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load doctors right now.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                final specializations = _extractSpecializations(docs);

                final filtered = _filterAndSortDoctors(docs);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No doctors matched your search.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: AppColors.cardBackground,
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final specialization in specializations)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(specialization),
                                        selected:
                                            _selectedSpecialization ==
                                            specialization,
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedSpecialization =
                                                specialization;
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.filter_alt_outlined,
                              color: AppColors.primary,
                            ),
                            onSelected: (value) {
                              setState(() => _selectedAvailability = value);
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'all',
                                child: Text('All Availability'),
                              ),
                              PopupMenuItem(
                                value: 'available',
                                child: Text('Available Only'),
                              ),
                              PopupMenuItem(
                                value: 'unavailable',
                                child: Text('Unavailable Only'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = _readText(data['name'], fallback: 'Unknown');
                          final specialization = _readText(
                            data['specialization'],
                            fallback: 'General',
                          );
                          final rating = _ratingOf(data);
                          final fee = _feeOf(data);
                          final available = _isDoctorAvailable(data);
                          final availabilityColor = available
                              ? AppColors.success
                              : AppColors.error;

                          return Material(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DoctorProfileScreen(
                                      doctorId: doc.id,
                                      doctorData: data,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: _readText(data['imageUrl']),
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 56,
                                          height: 56,
                                          color: AppColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            AppFormatters.getInitials(name),
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            specialization,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star_rounded,
                                                size: 14,
                                                color: AppColors.warning,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                rating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: availabilityColor.withValues(
                                                    alpha: 0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(100),
                                                  border: Border.all(
                                                    color:
                                                        availabilityColor.withValues(
                                                          alpha: 0.3,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  available
                                                      ? 'Available'
                                                      : 'Unavailable',
                                                  style: TextStyle(
                                                    color: availabilityColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        fee == 0 ? 'Free' : '${fee.toInt()} EGP',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
