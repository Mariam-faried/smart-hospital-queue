import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_colors.dart';

enum LegalDocumentType { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  String get _title {
    switch (type) {
      case LegalDocumentType.privacy:
        return 'Privacy Policy';
      case LegalDocumentType.terms:
        return 'Terms & Conditions';
    }
  }

  String get _version {
    switch (type) {
      case LegalDocumentType.privacy:
        return 'Privacy v1.0';
      case LegalDocumentType.terms:
        return 'Terms v1.0';
    }
  }

  String get _lastUpdated {
    return 'March 27, 2026';
  }

  List<_LegalSection> get _sections {
    if (type == LegalDocumentType.privacy) {
      return const [
        _LegalSection(
          heading: '1. Data We Collect',
          body:
              'MediQueue collects account details, appointment details, queue status, and in-app communication content needed to deliver healthcare queue services.',
        ),
        _LegalSection(
          heading: '2. Why We Use Your Data',
          body:
              'We use your data for appointment scheduling, queue coordination, patient notifications, account security, and support operations.',
        ),
        _LegalSection(
          heading: '3. Data Sharing',
          body:
              'Your data is shared only with authorized hospital staff and platform systems required to deliver your requested care and queue services.',
        ),
        _LegalSection(
          heading: '4. Security & Access',
          body:
              'Access to data is role-based and protected by Firebase authentication and Firestore security rules. Sensitive account actions require re-authentication.',
        ),
        _LegalSection(
          heading: '5. Retention & Support',
          body:
              'We retain operational data according to hospital policy and legal requirements. For deletion or correction requests, contact your hospital administration.',
        ),
      ];
    }
    return const [
      _LegalSection(
        heading: '1. Service Scope',
        body:
            'MediQueue provides queue management, appointment booking, communication, and operational workflows for healthcare providers and patients.',
      ),
      _LegalSection(
        heading: '2. Account Responsibility',
        body:
            'You are responsible for safeguarding your account credentials and ensuring account information is accurate and up to date.',
      ),
      _LegalSection(
        heading: '3. Acceptable Use',
        body:
            'You agree not to misuse the platform, interfere with service operation, or submit inaccurate medical or identity information.',
      ),
      _LegalSection(
        heading: '4. Appointment & Queue Rules',
        body:
            'Appointment status, queue position, and no-show handling follow hospital workflow policies and may change based on real-time operations.',
      ),
      _LegalSection(
        heading: '5. Policy Updates',
        body:
            'We may update terms and privacy documents periodically. Continued use after updates indicates acceptance of the revised documents.',
      ),
    ];
  }

  List<_LegalLink> get _links {
    return const [
      _LegalLink(
        label: 'Hospital Support',
        url: 'https://mediqueue.app/support',
      ),
      _LegalLink(
        label: 'Official Policy Portal',
        url: 'https://mediqueue.app/legal',
      ),
    ];
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid link.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open link. Please try again.'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGrey,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _version,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last updated: $_lastUpdated',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final section in _sections) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
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
                  Text(
                    section.heading,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Text(
            'Reference Links',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final link in _links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => _openExternalLink(context, link.url),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(link.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String heading;
  final String body;

  const _LegalSection({required this.heading, required this.body});
}

class _LegalLink {
  final String label;
  final String url;

  const _LegalLink({required this.label, required this.url});
}

