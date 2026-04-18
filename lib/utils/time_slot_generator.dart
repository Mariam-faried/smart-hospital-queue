import 'package:intl/intl.dart';

List<String> generateTimeSlots({
  required String workingHours,
  required int avgConsultationTime,
  required DateTime selectedDay,
  required List<String> bookedSlots,
}) {
  try {
    final parts = workingHours.split('-').map((s) => s.trim()).toList();
    if (parts.length != 2) return [];

    final startTime = _parseTime(parts[0]);
    final endTime = _parseTime(parts[1]);
    if (startTime == null || endTime == null) return [];

    final slots = <String>[];
    var current = startTime;
    while (current.isBefore(endTime)) {
      slots.add(DateFormat('hh:mm a').format(current));
      current = current.add(Duration(minutes: avgConsultationTime));
    }

    final now = DateTime.now();
    final isToday =
        selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;

    return slots.where((slot) {
      if (isToday) {
        final parts = slot.split(':');
        final slotHour = int.parse(parts[0]);
        final slotMin = int.parse(parts[1].split(' ')[0]);
        final isPM = slot.contains('PM');
        final hour24 = isPM && slotHour != 12
            ? slotHour + 12
            : (!isPM && slotHour == 12 ? 0 : slotHour);
        final slotTime = DateTime(
          now.year,
          now.month,
          now.day,
          hour24,
          slotMin,
        );
        if (slotTime.isBefore(now)) return false;
      }
      return true;
    }).toList();
  } catch (_) {
    return [];
  }
}

DateTime? _parseTime(String timeStr) {
  try {
    // Handle formats like "9:00 AM", "09:00 AM", "5:00 PM"
    final cleaned = timeStr.trim().toUpperCase();
    // Try multiple formats
    for (final fmt in ['h:mm a', 'hh:mm a', 'H:mm', 'HH:mm']) {
      try {
        return DateFormat(fmt).parse(cleaned);
      } catch (_) {}
    }
    return null;
  } catch (_) {
    return null;
  }
}
