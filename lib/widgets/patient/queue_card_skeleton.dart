import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class QueueCardSkeleton extends StatefulWidget {
  const QueueCardSkeleton({super.key});

  @override
  State<QueueCardSkeleton> createState() => _QueueCardSkeletonState();
}

class _QueueCardSkeletonState extends State<QueueCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.divider,
                AppColors.background,
                AppColors.divider,
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: GradientRotation(_controller.value * 2 * 3.14159),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildItem(height: 100, borderRadius: 24),
          const SizedBox(height: 20),
          _buildItem(height: 380, borderRadius: 24),
          const SizedBox(height: 20),
          _buildItem(height: 80, borderRadius: 16),
        ],
      ),
    );
  }

  Widget _buildItem({required double height, required double borderRadius}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
