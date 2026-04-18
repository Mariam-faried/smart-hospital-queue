import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  final String uid;
  final void Function(int)? onSwitchTab;

  const NotificationsScreen({super.key, required this.uid, this.onSwitchTab});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isMarkingAllAsRead = false;

  Future<void> _markAllAsRead() async {
    if (_isMarkingAllAsRead) return;
    setState(() => _isMarkingAllAsRead = true);
    try {
      await _notificationService.markAllAsRead(widget.uid);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to mark all notifications as read.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllAsRead = false);
      }
    }
  }

  Future<void> _onNotificationTap({
    required String notificationId,
    required Map<String, dynamic> data,
    required bool isRead,
  }) async {
    if (!isRead) {
      try {
        await _notificationService.markAsRead(
          uid: widget.uid,
          notificationId: notificationId,
        );
      } catch (_) {}
    }

    final actionTab = (data['actionTab'] as num?)?.toInt();
    if (actionTab != null && widget.onSwitchTab != null && mounted) {
      widget.onSwitchTab!(actionTab);
      Navigator.pop(context);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'booking_confirmed':
        return Icons.event_available_rounded;
      case 'queue_update':
        return Icons.queue_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'booking_confirmed':
        return AppColors.success;
      case 'queue_update':
        return AppColors.info;
      case 'payment':
        return AppColors.warning;
      case 'reminder':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  String _formatTime(dynamic raw) {
    if (raw is Timestamp) {
      return DateFormat('MMM d, h:mm a').format(raw.toDate());
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateFormat('MMM d, h:mm a').format(parsed);
      }
      return raw;
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationService.streamNotifications(widget.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unable to load notifications.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final unreadCount = docs.where((doc) {
            final data = doc.data();
            return (data['isRead'] as bool?) != true;
          }).length;

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 44,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Appointment updates will appear here.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      unreadCount > 0 ? '$unreadCount unread' : 'All caught up',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: unreadCount == 0 || _isMarkingAllAsRead
                          ? null
                          : _markAllAsRead,
                      icon: _isMarkingAllAsRead
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title =
                        (data['title'] as String?)?.trim().isNotEmpty == true
                        ? data['title'] as String
                        : 'MediQueue Update';
                    final message =
                        (data['message'] as String?)?.trim().isNotEmpty == true
                        ? data['message'] as String
                        : 'You have a new notification.';
                    final type = (data['type'] as String?) ?? 'general';
                    final isRead = (data['isRead'] as bool?) == true;
                    final timeLabel = _formatTime(data['createdAt']);
                    final icon = _iconForType(type);
                    final iconColor = _colorForType(type);

                    return Material(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _onNotificationTap(
                          notificationId: doc.id,
                          data: data,
                          isRead: isRead,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: isRead
                                ? AppColors.cardBackground
                                : iconColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isRead
                                  ? AppColors.divider
                                  : iconColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: isRead
                                                    ? FontWeight.w600
                                                    : FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'NEW',
                                                style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        timeLabel,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}
