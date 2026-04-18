import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class DoctorStatsCard extends StatelessWidget {
  final int totalPatients;
  final int experience;
  final double rating;
  final num consultationFee;
  final String currency;

  const DoctorStatsCard({
    super.key,
    required this.totalPatients,
    required this.experience,
    required this.rating,
    required this.consultationFee,
    required this.currency,
  });

  String _formatFee() {
    if (consultationFee <= 0) return 'Free';
    final amount = consultationFee.toDouble();
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStat(
                '$totalPatients+',
                'Patients',
                Icons.people_outline,
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _buildStat(
                '$experience',
                'Years Exp.',
                Icons.work_history_outlined,
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _buildStat(
                rating.toStringAsFixed(1),
                'Rating',
                Icons.star,
                iconColor: AppColors.warning,
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _buildStat(
                _formatFee(),
                consultationFee <= 0 ? 'Fee' : 'Fee ($currency)',
                Icons.payments_outlined,
                iconColor: AppColors.primary,
                valueColor: consultationFee <= 0
                    ? AppColors.success
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    String value,
    String label,
    IconData icon, {
    Color? iconColor,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: iconColor ?? AppColors.primary),
        const SizedBox(height: 8),
        SizedBox(
          height: 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.textPrimary,
              ),
              maxLines: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(height: 44, width: 1, color: AppColors.divider);
  }
}
