import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';

class DoctorProfileAppBar extends StatelessWidget {
  final String doctorId;
  final Map<String, dynamic> doctorData;
  final String name;
  final String specialization;
  final String qualification;
  final double rating;
  final int totalPatients;
  final bool isAvailable;

  const DoctorProfileAppBar({
    super.key,
    required this.doctorId,
    required this.doctorData,
    required this.name,
    required this.specialization,
    required this.qualification,
    required this.rating,
    required this.totalPatients,
    required this.isAvailable,
  });

  void _showSnackBar(BuildContext context, String msg) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildDoctorBadges() {
    final badges = <Map<String, dynamic>>[];

    if (rating >= 4.8) {
      badges.add({'label': 'Top Rated', 'color': AppColors.warning});
    }
    if (totalPatients >= 2000) {
      badges.add({'label': 'Most Booked', 'color': AppColors.info});
    }
    if (doctorData['isVerified'] == true) {
      badges.add({'label': 'Verified', 'color': AppColors.success});
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: badges.map((badge) {
          final color = badge['color'] as Color;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.75)),
            ),
            child: Text(
              badge['label'] as String,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availabilityLabel = isAvailable ? 'Available Now' : 'Unavailable';

    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Builder(
            builder: (context) {
              final isFav = context.watch<AuthProvider>().isFavorite(doctorId);
              return Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AppColors.error : AppColors.onPrimary,
              );
            },
          ),
          onPressed: () async {
            await context.read<AuthProvider>().toggleFavorite(doctorId);
            if (!context.mounted) return;
            final newIsFavorite = context.read<AuthProvider>().isFavorite(
              doctorId,
            );
            _showSnackBar(
              context,
              newIsFavorite ? 'Added to favorites' : 'Removed from favorites',
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: AppColors.onPrimary),
          onPressed: () async {
            await SharePlus.instance.share(
              ShareParams(
                text:
                    'Check out $name - $specialization at MediQueue! Book your appointment today.',
                subject: '$name | MediQueue',
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _MedicalPatternPainter()),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.onPrimary.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: Hero(
                        tag: 'doctor_$doctorId',
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: doctorData['imageUrl'] ?? '',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 100,
                              height: 100,
                              color: AppColors.primary.withValues(alpha: 0.2),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.onPrimary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.onPrimary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isAvailable
                              ? AppColors.success
                              : AppColors.textSecondary,
                          border: Border.all(
                            color: AppColors.onPrimary,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isAvailable
                                          ? AppColors.success
                                          : AppColors.textSecondary)
                                      .withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  specialization,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.85),
                    fontSize: 16,
                  ),
                ),
                if (qualification.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    qualification,
                    style: TextStyle(
                      color: AppColors.onPrimary.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
                _buildDoctorBadges(),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isAvailable
                                ? AppColors.success
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvailable ? Icons.circle : Icons.circle_outlined,
                        size: 8,
                        color: isAvailable
                            ? AppColors.success
                            : AppColors.onPrimary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        availabilityLabel,
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.onPrimary.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const spacing = 40.0;
    const crossSize = 12.0;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        canvas.drawLine(
          Offset(x - crossSize / 2, y),
          Offset(x + crossSize / 2, y),
          paint,
        );
        canvas.drawLine(
          Offset(x, y - crossSize / 2),
          Offset(x, y + crossSize / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
