import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class CountdownTimerWidget extends StatefulWidget {
  final int totalMinutes;
  final bool isPaused;

  const CountdownTimerWidget({
    super.key,
    required this.totalMinutes,
    this.isPaused = false,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  late int _countdownSeconds;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.totalMinutes != widget.totalMinutes) {
      _startTimer();
    } else if (oldWidget.isPaused != widget.isPaused) {
      if (widget.isPaused) {
        // Paused now, just stop visually updating without changing the time needed
      } else {
        // Resumed, push the endpoint further so that pause duration didn't tick it down
        _endTime = DateTime.now().add(Duration(seconds: _countdownSeconds));
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _countdownSeconds = widget.totalMinutes * 60;
    _endTime = DateTime.now().add(Duration(seconds: _countdownSeconds));

    if (_countdownSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (widget.isPaused) {
        // Push endpoint so it doesn't decay while paused
        _endTime = DateTime.now().add(Duration(seconds: _countdownSeconds));
        return;
      }

      if (_endTime != null) {
        final remaining = _endTime!.difference(DateTime.now()).inSeconds;
        if (remaining > 0) {
          setState(() {
            _countdownSeconds = remaining;
          });
        } else {
          setState(() {
            _countdownSeconds = 0;
          });
          timer.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _getWaitTimeColor(int minutes) {
    if (minutes < 15) return AppColors.success;
    if (minutes < 30) return AppColors.warning;
    return AppColors.error;
  }

  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getWaitTimeColor(widget.totalMinutes);
    final progress = widget.totalMinutes > 0
        ? (_countdownSeconds / (widget.totalMinutes * 60)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(56, 56),
                  painter: _WaitTimeArcPainter(
                    progress: progress,
                    color: color,
                  ),
                ),
                Icon(Icons.timer_rounded, color: color, size: 24),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _countdownSeconds > 0
                  ? _formatCountdown(_countdownSeconds)
                  : '${widget.totalMinutes} min',
              key: ValueKey(_countdownSeconds),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated Wait',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Feature 13: Wait Time Arc Painter ─────────────────────────────

class _WaitTimeArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaitTimeArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background arc
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WaitTimeArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
