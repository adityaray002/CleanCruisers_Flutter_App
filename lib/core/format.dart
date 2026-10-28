const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// ₹1,499 — Indian digit grouping (₹1,49,999).
String rupees(int amount) {
  final s = amount.abs().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '${amount < 0 ? '-' : ''}₹$out';
}

String weekdayShort(DateTime d) => _days[d.weekday - 1];
String monthShort(DateTime d) => _months[d.month - 1];

/// "Tue, 30 Sep"
String shortDate(DateTime d) => '${weekdayShort(d)}, ${d.day} ${monthShort(d)}';

/// "Today", "Tomorrow" or "Tue, 30 Sep"
String friendlyDate(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = dateOnly(d).difference(today).inDays;
  if (diff == 0) return 'Today, ${d.day} ${monthShort(d)}';
  if (diff == 1) return 'Tomorrow, ${d.day} ${monthShort(d)}';
  return shortDate(d);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String hourLabel(int h) {
  final hr = h % 12 == 0 ? 12 : h % 12;
  return '$hr ${h < 12 ? 'AM' : 'PM'}';
}
