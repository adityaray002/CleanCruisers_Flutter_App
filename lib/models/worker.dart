import 'service.dart';

const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

String weekdayName(DateTime date) => weekdayNames[date.weekday - 1];

/// "2026-10-31" — used as a Firestore key for per-day records.
String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

enum DisruptionType { late, puncture, sick, absent, blockedAccess }

extension DisruptionTypeLabel on DisruptionType {
  String get label => switch (this) {
        DisruptionType.late => 'Running late',
        DisruptionType.puncture => 'Puncture / vehicle problem',
        DisruptionType.sick => 'Sick',
        DisruptionType.absent => 'Absent',
        DisruptionType.blockedAccess => 'Blocked access',
      };
}

/// A field worker on the roster. Home/base location is operations-only data:
/// it is never shown to customers.
class WorkerRecord {
  final String id;
  final String name;
  final bool isEmergency;
  final bool active;
  final String homeArea;
  final String weeklyOff;
  final List<String> unavailableDates; // approved leave, "yyyy-mm-dd"
  /// Service categories this worker is equipped for. Empty means all.
  final Set<ServiceCategory> skills;

  /// Reported disruptions by date. While a date has a disruption, no new work
  /// is assigned to this worker for that date.
  final Map<String, DisruptionType> disruptions;

  const WorkerRecord({
    required this.id,
    required this.name,
    required this.isEmergency,
    required this.active,
    required this.homeArea,
    required this.weeklyOff,
    this.unavailableDates = const [],
    this.skills = const {},
    this.disruptions = const {},
  });

  bool canDo(ServiceCategory category) =>
      skills.isEmpty || skills.contains(category);

  WorkerRecord copyWith({
    Map<String, DisruptionType>? disruptions,
    List<String>? unavailableDates,
  }) =>
      WorkerRecord(
        id: id,
        name: name,
        isEmergency: isEmergency,
        active: active,
        homeArea: homeArea,
        weeklyOff: weeklyOff,
        unavailableDates: unavailableDates ?? this.unavailableDates,
        skills: skills,
        disruptions: disruptions ?? this.disruptions,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'isEmergency': isEmergency,
        'active': active,
        'homeArea': homeArea,
        'weeklyOff': weeklyOff,
        'unavailableDates': unavailableDates,
        'skills': [for (final s in skills) s.name],
        'disruptions': {
          for (final e in disruptions.entries) e.key: e.value.name
        },
      };

  factory WorkerRecord.fromJson(String id, Map<String, dynamic> json) =>
      WorkerRecord(
        id: id,
        name: json['name'] as String? ?? 'Worker',
        isEmergency: json['isEmergency'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
        homeArea: json['homeArea'] as String? ?? '',
        weeklyOff: json['weeklyOff'] as String? ?? '',
        unavailableDates: [
          for (final date in (json['unavailableDates'] as List? ?? const []))
            date as String,
        ],
        skills: {
          for (final s in (json['skills'] as List? ?? const []))
            ...ServiceCategory.values.where((c) => c.name == s),
        },
        disruptions: {
          for (final e in ((json['disruptions'] as Map?) ?? const {}).entries)
            if (DisruptionType.values.any((t) => t.name == e.value))
              e.key as String: DisruptionType.values.byName(e.value as String),
        },
      );
}
