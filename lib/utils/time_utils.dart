class TimeUtils {
  static DateTime? parseTimeSlot(String timeSlot, {DateTime? baseDate}) {
    baseDate ??= DateTime.now();
    try {
      final timePartStr = timeSlot.split('-').first.trim();
      final timeFormat = RegExp(r'(\d+):(\d+)\s*(AM|PM|am|pm)?');
      final match = timeFormat.firstMatch(timePartStr);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        final int minute = int.parse(match.group(2)!);
        final String? amPm = match.group(3)?.toUpperCase();

        if (amPm == 'PM' && hour != 12) hour += 12;
        if (amPm == 'AM' && hour == 12) hour = 0;

        return DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          hour,
          minute,
        );
      }
    } catch (_) {}
    return null;
  }
}
