import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class PaymentInfoRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCompletePayment;

  const PaymentInfoRow({
    super.key,
    required this.data,
    required this.onCompletePayment,
  });

  @override
  Widget build(BuildContext context) {
    final paymentStatusRaw = data['paymentStatus'] as String? ?? '';
    final paymentStatus = paymentStatusRaw.trim().toLowerCase();
    final totalFee = (data['totalFee'] as num?)?.toInt() ?? 0;
    final currency = data['currency'] as String? ?? 'EGP';

    if (paymentStatus.isEmpty) return const SizedBox.shrink();

    String badgeText;
    Color badgeTextColor;
    IconData badgeIcon;

    if (totalFee == 0 || paymentStatus == 'free') {
      badgeText = 'No Payment Required';
      badgeTextColor = AppColors.success;
      badgeIcon = Icons.check_circle_outline;
    } else {
      switch (paymentStatus) {
        case 'paid':
          badgeText = 'Paid';
          badgeTextColor = AppColors.success;
          badgeIcon = Icons.check_circle_outline;
          break;
        case 'pay_at_hospital':
          badgeText = 'Pay at Hospital';
          badgeTextColor = AppColors.info;
          badgeIcon = Icons.local_hospital_outlined;
          break;
        default:
          badgeText = _readableStatus(paymentStatusRaw);
          badgeTextColor = AppColors.textSecondary;
          badgeIcon = Icons.info_outline;
      }
    }

    final badgeSurfaceColor = AppColors.statusSurface(badgeTextColor);
    final badgeBorderColor = AppColors.statusBorder(badgeTextColor);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalFee $currency',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeSurfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeTextColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalFee > 0 &&
              paymentStatus != 'pay_at_hospital' &&
              paymentStatus != 'paid' &&
              paymentStatus != 'free') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCompletePayment,
                icon: const Icon(Icons.local_hospital_outlined, size: 18),
                label: const Text('Set Pay at Hospital'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _readableStatus(String rawStatus) {
    final normalized = rawStatus
        .trim()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
