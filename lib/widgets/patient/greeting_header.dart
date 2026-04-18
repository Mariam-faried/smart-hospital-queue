import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';
import 'package:smart_hospital_queue/utils/formatters.dart';

class GreetingHeader extends StatelessWidget {
  final String uid;
  final VoidCallback? onNotificationsPressed;

  const GreetingHeader({
    super.key,
    required this.uid,
    this.onNotificationsPressed,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 21 || hour < 5) return 'Good Night';
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static Color getStatusColor(String? status) {
    final normalized = status?.trim().toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'waiting':
        return AppColors.statusWaiting;
      case 'confirmed':
        return AppColors.primary;
      case 'in-progress':
        return AppColors.statusInProgress;
      case 'completed':
        return AppColors.statusCompleted;
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'no-show':
        return AppColors.statusNoShow;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: false,
      pinned: false,
      backgroundColor: AppColors.primary,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Subtle dotted pattern overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.07,
                child: CustomPaint(painter: _DotPatternPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 56.0,
                left: 20.0,
                right: 12.0,
              ),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String name = 'Patient';
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null && data.containsKey('name')) {
                      final rawName = data['name'];
                      if (rawName is String && rawName.trim().isNotEmpty) {
                        name = rawName.trim();
                      } else if (rawName != null) {
                        final value = rawName.toString().trim();
                        if (value.isNotEmpty) {
                          name = value;
                        }
                      }
                    }
                  }
                  final initials = AppFormatters.getInitials(name);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Profile Avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cardBackground.withValues(
                                  alpha: 0.2,
                                ),
                                border: Border.all(
                                  color: AppColors.cardBackground.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cardBackground.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: AppColors.cardBackground,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_getGreeting()},',
                                    style: TextStyle(
                                      color: AppColors.cardBackground
                                          .withValues(alpha: 0.7),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: AppColors.cardBackground,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('notifications')
                            .where('isRead', isEqualTo: false)
                            .limit(100)
                            .snapshots(),
                        builder: (context, unreadSnapshot) {
                          final unreadCount =
                              unreadSnapshot.data?.docs.length ?? 0;
                          final showBadge = unreadCount > 0;
                          final unreadLabel = unreadCount > 99
                              ? '99+'
                              : unreadCount.toString();

                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.cardBackground,
                                ),
                                tooltip: 'Notifications',
                                onPressed: onNotificationsPressed,
                              ),
                              if (showBadge)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primaryDark,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Text(
                                      unreadLabel,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painter for Subtle Dotted Background ───────────────────
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cardBackground
      ..style = PaintingStyle.fill;

    const double spacing = 16.0;
    const double radius = 1.5;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        // Offset alternate rows slightly to make a diagonal pattern
        double offsetX = x + ((y / spacing) % 2 == 0 ? 0 : spacing / 2);
        if (offsetX < size.width) {
          canvas.drawCircle(Offset(offsetX, y), radius, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
