import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_colors.dart';
import 'package:smart_hospital_queue/utils/formatters.dart';
import '../../screens/patient/book_appointment_screen.dart';
import '../../screens/patient/doctor_profile_screen.dart';

class TopDoctorsSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool isLoading;
  final Animation<double> doctorsFade;
  final Animation<Offset> doctorsSlide;
  final bool isServerRanked;

  const TopDoctorsSection({
    super.key,
    required this.docs,
    required this.isLoading,
    required this.doctorsFade,
    required this.doctorsSlide,
    this.isServerRanked = false,
  });

  Widget _buildShimmerDoctorCard() {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.background,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  double _extractRating(Map<String, dynamic> data) {
    final r = data['rating'];
    if (r is num) return r.toDouble();
    if (r is String) return double.tryParse(r) ?? 0.0;
    return 0.0;
  }

  int _extractInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = num.tryParse(value.trim());
      if (parsed != null) return parsed.toInt();
    }
    return fallback;
  }

  num _extractFee(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
      final parsed = num.tryParse(cleaned);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  String _readText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final normalized = value is String ? value.trim() : value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  bool _isDoctorProfileVisible(Map<String, dynamic> data) {
    final status = _readText(
      data['accountStatus'],
      fallback: 'active',
    ).toLowerCase();
    return status == 'active' || status == 'approved';
  }

  String _formatFee(num fee) {
    final amount = fee.toDouble();
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Widget _buildTopDoctorCard(
    BuildContext context,
    String doctorId,
    Map<String, dynamic> data, {
    bool fullWidth = false,
  }) {
    final name = _readText(data['name'], fallback: 'Unknown');
    final spec = _readText(data['specialization'], fallback: 'General');
    final rating = _extractRating(data);
    final reviewCount = _extractInt(data['reviewCount']);
    final fallbackReviewCount = _extractInt(data['experience']) * 40;
    final initials = AppFormatters.getInitials(name);
    final fee = _extractFee(data['consultationFee']);

    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground, // pure white — no cream bleed
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.cardBackground.withValues(alpha: 0),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DoctorProfileScreen(doctorId: doctorId, doctorData: data),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: Hero(
                          tag: 'doctor_$doctorId',
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: _readText(data['imageUrl']),
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.2),
                                      AppColors.primaryDark.withValues(
                                        alpha: 0.15,
                                      ),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  spec,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
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
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '(${reviewCount > 0 ? reviewCount : fallbackReviewCount})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    fee == 0 ? 'Free' : '${_formatFee(fee)} EGP',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: card);
    }
    return card;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: doctorsFade,
      child: SlideTransition(
        position: doctorsSlide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.star_outline,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Top Doctors',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BookAppointmentScreen(
                          initialSpecialization: 'All',
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'See All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              GridView.count(
                padding: EdgeInsets.zero,
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(4, (_) => _buildShimmerDoctorCard()),
              )
            else if (docs.isEmpty)
              const Center(
                child: Text(
                  'No doctors available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Builder(
                builder: (context) {
                  var validDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = _readText(data['name']);
                    return name.isNotEmpty &&
                        name.toLowerCase() != 'unknown' &&
                        _isDoctorProfileVisible(data);
                  }).toList();

                  if (!isServerRanked) {
                    validDocs.sort((a, b) {
                      final rA = _extractRating(
                        a.data() as Map<String, dynamic>,
                      );
                      final rB = _extractRating(
                        b.data() as Map<String, dynamic>,
                      );
                      return rB.compareTo(rA);
                    });
                  }
                  if (validDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No complete doctor profiles available yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  if (validDocs.length > 6) validDocs = validDocs.sublist(0, 6);

                  return Column(
                    children: [
                      for (int i = 0; i < validDocs.length - 1; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTopDoctorCard(
                                  context,
                                  validDocs[i].id,
                                  validDocs[i].data() as Map<String, dynamic>,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTopDoctorCard(
                                  context,
                                  validDocs[i + 1].id,
                                  validDocs[i + 1].data()
                                      as Map<String, dynamic>,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (validDocs.length.isOdd)
                        _buildTopDoctorCard(
                          context,
                          validDocs.last.id,
                          validDocs.last.data() as Map<String, dynamic>,
                          fullWidth: true,
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
