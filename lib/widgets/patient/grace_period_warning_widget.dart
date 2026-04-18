import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/time_utils.dart';

// ── Feature 6: Auto No-Show Live Countdown ───────────────────────────

class GracePeriodWarningWidget extends StatefulWidget {
  final int graceMinutes;
  final String timeSlot;

  const GracePeriodWarningWidget({
    super.key,
    required this.graceMinutes,
    required this.timeSlot,
  });

  @override
  State<GracePeriodWarningWidget> createState() =>
      _GracePeriodWarningWidgetState();
}

class _GracePeriodWarningWidgetState extends State<GracePeriodWarningWidget> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateRemaining();
    });
  }

  void _updateRemaining() {
    try {
      final now = DateTime.now();
      final scheduledTime = TimeUtils.parseTimeSlot(
        widget.timeSlot,
        baseDate: now,
      );
      if (scheduledTime != null) {
        final expiresAt = scheduledTime.add(
          Duration(minutes: widget.graceMinutes),
        );
        setState(() {
          _remaining = expiresAt.difference(now);
          if (_remaining.isNegative) {
            _remaining = Duration.zero;
          }
        });
      }
    } catch (_) {
      setState(() {
        _remaining = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String timeStr;
    if (_remaining.inSeconds > 0) {
      final m = _remaining.inMinutes;
      final s = _remaining.inSeconds % 60;
      timeStr = '${m}m ${s}s';
    } else {
      timeStr = '0m 0s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Check in within $timeStr or you will be marked as no-show',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
