// Time labels customers see. All times are minutes after midnight.
//
// The scheduling rules themselves (worker hours, lunch, travel, capacity)
// live on the server (ShineStaff); the test-build stand-in is
// lib/data/api/fake/fake_api.dart.

/// "9:30 – 10:30 AM", "11:30 AM – 12:30 PM": compact, for customers.
String timeRangeLabel(int start, int end) {
  String hm(int m) {
    final h = (m ~/ 60) % 12 == 0 ? 12 : (m ~/ 60) % 12;
    final mm = m % 60;
    return mm == 0 ? '$h' : '$h:${mm.toString().padLeft(2, '0')}';
  }

  String ap(int m) => m < 12 * 60 ? 'AM' : 'PM';
  return ap(start) == ap(end)
      ? '${hm(start)} – ${hm(end)} ${ap(end)}'
      : '${hm(start)} ${ap(start)} – ${hm(end)} ${ap(end)}';
}

/// "9:30 AM".
String clockLabel(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60;
  final minute = minuteOfDay % 60;
  final suffix = hour < 12 ? 'AM' : 'PM';
  final shown = hour % 12 == 0 ? 12 : hour % 12;
  return '$shown:${minute.toString().padLeft(2, '0')} $suffix';
}
