import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_colors.dart';
import '../../screens/patient/doctor_profile_screen.dart';
import '../../screens/patient/doctor_search_screen.dart';

class DoctorSearchResults extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool isLoading;
  final String searchQuery;
  final VoidCallback? onOpenFullResults;

  const DoctorSearchResults({
    super.key,
    required this.docs,
    required this.isLoading,
    required this.searchQuery,
    this.onOpenFullResults,
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

  Widget _buildSearchResultCard(
    BuildContext context,
    String doctorId,
    Map<String, dynamic> data,
  ) {
    final name = _readText(data['name'], fallback: 'Unknown');
    final spec = _readText(data['specialization'], fallback: 'General');
    final rating =
        ((data['rating'] is num)
            ? (data['rating'] as num).toDouble()
            : double.tryParse(data['rating']?.toString() ?? '')) ??
        0.0;
    final consultationFee = _readNum(data['consultationFee'], fallback: 0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DoctorProfileScreen(doctorId: doctorId, doctorData: data),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: data['imageUrl'] ?? '',
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      consultationFee == 0
                          ? 'Free'
                          : '${consultationFee.toInt()} EGP',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 16, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(4, (_) => _buildShimmerDoctorCard()),
      );
    }

    final normalizedQuery = searchQuery.trim().toLowerCase();
    final filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = _readText(data['name']).toLowerCase();
      final spec = _readText(data['specialization']).toLowerCase();
      final accountStatus = _readText(
        data['accountStatus'],
        fallback: 'active',
      ).toLowerCase();
      if (accountStatus != 'active' && accountStatus != 'approved') {
        return false;
      }
      return name.contains(normalizedQuery) || spec.contains(normalizedQuery);
    }).toList();

    if (filteredDocs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 44,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'No doctors found for "$searchQuery"',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search Results (${filteredDocs.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed:
                  onOpenFullResults ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DoctorSearchScreen(initialQuery: searchQuery),
                      ),
                    );
                  },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...filteredDocs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _buildSearchResultCard(context, doc.id, data);
        }),
      ],
    );
  }
}
