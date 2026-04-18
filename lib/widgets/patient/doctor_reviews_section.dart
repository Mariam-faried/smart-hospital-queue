import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class DoctorReviewsSection extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final double averageRating;
  final int reviewCount;
  final bool isLoading;
  final bool canSubmitReview;
  final bool hasCurrentUserReview;
  final bool isSubmittingReview;
  final VoidCallback? onSubmitReview;

  const DoctorReviewsSection({
    super.key,
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
    this.isLoading = false,
    this.canSubmitReview = false,
    this.hasCurrentUserReview = false,
    this.isSubmittingReview = false,
    this.onSubmitReview,
  });

  int _parseStars(dynamic value, {int fallback = 5}) {
    if (value is int) return value.clamp(1, 5).toInt();
    if (value is num) return value.toInt().clamp(1, 5).toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed.clamp(1, 5).toInt();
    }
    return fallback;
  }

  String _safeName(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return 'Patient';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Reviews & Ratings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$reviewCount reviews',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (canSubmitReview) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: isSubmittingReview ? null : onSubmitReview,
                  icon: isSubmittingReview
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          hasCurrentUserReview
                              ? Icons.edit_outlined
                              : Icons.rate_review_outlined,
                          size: 16,
                        ),
                  label: Text(
                    hasCurrentUserReview
                        ? 'Edit Your Review'
                        : 'Write a Review',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (isLoading) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Loading reviews...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (reviews.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 40,
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No reviews yet',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Be the first to review this doctor!',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (canSubmitReview) ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: isSubmittingReview ? null : onSubmitReview,
                          icon: isSubmittingReview
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : const Icon(
                                  Icons.rate_review_outlined,
                                  size: 16,
                                ),
                          label: Text(
                            hasCurrentUserReview
                                ? 'Edit Your Review'
                                : 'Write First Review',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Compute star breakdown from actual reviews
              Builder(
                builder: (_) {
                  final starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
                  for (final r in reviews) {
                    final s = _parseStars(r['stars']);
                    if (s >= 1 && s <= 5) starCounts[s] = starCounts[s]! + 1;
                  }
                  final total = reviews.length;
                  final fullStars = averageRating.floor().clamp(0, 5).toInt();
                  final hasHalfStar =
                      averageRating - fullStars >= 0.5 && fullStars < 5;
                  return Row(
                    children: [
                      Column(
                        children: [
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              final icon = i < fullStars
                                  ? Icons.star
                                  : (hasHalfStar && i == fullStars
                                        ? Icons.star_half
                                        : Icons.star_border);
                              return Icon(
                                icon,
                                size: 16,
                                color: AppColors.warning,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildRatingBar(
                              5,
                              total > 0 ? starCounts[5]! / total : 0,
                            ),
                            const SizedBox(height: 4),
                            _buildRatingBar(
                              4,
                              total > 0 ? starCounts[4]! / total : 0,
                            ),
                            const SizedBox(height: 4),
                            _buildRatingBar(
                              3,
                              total > 0 ? starCounts[3]! / total : 0,
                            ),
                            const SizedBox(height: 4),
                            _buildRatingBar(
                              2,
                              total > 0 ? starCounts[2]! / total : 0,
                            ),
                            const SizedBox(height: 4),
                            _buildRatingBar(
                              1,
                              total > 0 ? starCounts[1]! / total : 0,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              ...reviews.map((review) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildReviewCard(
                    _safeName(review['name']),
                    _parseStars(review['stars']),
                    (review['text'] as String? ?? '').trim(),
                    (review['timeAgo'] as String? ?? 'Recently').trim(),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    // Ensure minimum visibility — never completely empty
    final displayPercentage = percentage < 0.02 ? 0.02 : percentage;

    Color barColor;
    switch (stars) {
      case 5:
        barColor = AppColors.warning;
      case 4:
        barColor = AppColors.warning.withValues(alpha: 0.75);
      case 3:
        barColor = AppColors.warning.withValues(alpha: 0.55);
      case 2:
        barColor = AppColors.textSecondary.withValues(alpha: 0.5);
      case 1:
        barColor = AppColors.error.withValues(alpha: 0.4);
      default:
        barColor = AppColors.divider;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              '$stars',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: displayPercentage, // minimum 2% always visible
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 7, // slightly taller for visibility
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String name, int stars, String text, String timeAgo) {
    final avatarLetter = name.isNotEmpty ? name.substring(0, 1) : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  avatarLetter.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      ...List.generate(
                        stars,
                        (_) => const Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
