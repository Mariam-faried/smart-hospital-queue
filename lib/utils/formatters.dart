/// MediQueue centralized formatting utilities.
abstract class AppFormatters {
  static int parseTicketNumber(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) return fallback;

      final direct = int.tryParse(value);
      if (direct != null) return direct;

      final normalized = value.toUpperCase().startsWith('T-')
          ? value.substring(2)
          : value;
      final prefixed = int.tryParse(normalized);
      if (prefixed != null) return prefixed;

      final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isNotEmpty) {
        final parsed = int.tryParse(digitsOnly);
        if (parsed != null) return parsed;
      }
    }

    return fallback;
  }

  /// Formats a ticket number into the standard 'T-XXX' format.
  static String formatTicket(dynamic ticketNumber) {
    final parsed = parseTicketNumber(ticketNumber, fallback: 0);
    return 'T-${parsed.toString().padLeft(3, '0')}';
  }

  /// Alias for formatTicket to gracefully handle different naming in the codebase.
  static String formatTicketString(dynamic ticketNumber) {
    return formatTicket(ticketNumber);
  }

  /// Gets the initials from a full name (e.g., "John Doe" -> "JD").
  static String getInitials(String name) {
    return name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
  }

  /// Formats a wait time in minutes into a human-readable string.
  static String formatWaitTime(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$hours hr${hours > 1 ? 's' : ''} $mins min';
  }
}
