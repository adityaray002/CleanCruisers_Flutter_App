import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/scheduling.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../models/booking.dart';
import '../../providers/app_providers.dart';
import '../../widgets/ui.dart';
import 'ops_board.dart';
import 'ops_capacity.dart';
import 'ops_roster.dart';

/// Everything the desk tabs need, loaded once from live streams.
class OpsData {
  final List<BookingRecord> bookings;
  final List<WorkerRecord> workers;
  final OpsSettings settings;
  final StaffAccess staff;
  final List<Map<String, dynamic>> incidents;
  const OpsData({
    required this.bookings,
    required this.workers,
    required this.settings,
    required this.staff,
    required this.incidents,
  });

  WorkerRecord? worker(String? id) =>
      workers.where((w) => w.id == id).firstOrNull;
}

class OpsDashboardScreen extends ConsumerStatefulWidget {
  const OpsDashboardScreen({super.key});
  @override
  ConsumerState<OpsDashboardScreen> createState() => _OpsDashboardScreenState();
}

class _OpsDashboardScreenState extends ConsumerState<OpsDashboardScreen> {
  bool _checking = true;
  StaffAccess? _staff;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccess());
  }

  Future<void> _checkAccess() async {
    final cloud = ref.read(bookingCloudProvider);
    if (!cloud.configured) {
      if (mounted) {
        setState(() {
          _checking = false;
          _accessError =
              'Firebase is not connected in this build, so the shared booking desk can\'t open. See docs/OPERATIONS_MVP_SETUP.md.';
        });
      }
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) context.go('/ops/login');
      return;
    }
    try {
      final staff = await cloud.staffAccess(user.uid);
      if (staff == null) {
        await cloud.signOutStaff();
        if (mounted) context.go('/ops/login');
        return;
      }
      if (mounted) {
        setState(() {
          _staff = staff;
          _checking = false;
        });
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _accessError = error.message ?? 'Could not check staff access.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final staff = _staff;
    if (staff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operations setup')),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 44, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_accessError ?? 'Staff access is required.',
                  style: AppText.body, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SecondaryButton(
                  label: 'Back to sign in',
                  onPressed: () => context.go('/ops/login')),
            ]),
          ),
        )),
      );
    }

    final cloud = ref.watch(bookingCloudProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Booking desk · ${staff.role.name}'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await cloud.signOutStaff();
                if (context.mounted) context.go('/ops/login');
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Today'),
            Tab(text: 'Queue'),
            Tab(text: 'Roster'),
            Tab(text: 'Capacity'),
          ]),
        ),
        body: _Streams(
          cloud: cloud,
          staff: staff,
          builder: (data) => TabBarView(children: [
            OpsBoard(data: data),
            OpsQueue(data: data),
            OpsRoster(data: data),
            OpsCapacity(data: data),
          ]),
        ),
      ),
    );
  }
}

class _Streams extends StatelessWidget {
  final BookingCloud cloud;
  final StaffAccess staff;
  final Widget Function(OpsData) builder;
  const _Streams(
      {required this.cloud, required this.staff, required this.builder});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OpsSettings>(
      stream: cloud.watchOpsSettings(),
      builder: (context, settings) => StreamBuilder<List<WorkerRecord>>(
        stream: cloud.watchWorkers(),
        builder: (context, workers) =>
            StreamBuilder<List<Map<String, dynamic>>>(
          stream: cloud.watchOpenIncidents(),
          builder: (context, incidents) => StreamBuilder<List<BookingRecord>>(
            stream: cloud.watchOperationsBookings(),
            builder: (context, bookings) {
              final error = bookings.error ?? workers.error;
              if (error != null) return opsErrorState(error.toString());
              if (!bookings.hasData || !workers.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return builder(OpsData(
                bookings: bookings.data!,
                workers: workers.data!,
                settings: settings.data ?? const OpsSettings(),
                staff: staff,
                incidents: incidents.data ?? const [],
              ));
            },
          ),
        ),
      ),
    );
  }
}

Widget opsErrorState(String error) => Center(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.error, size: 36),
        const SizedBox(height: 10),
        Text('Could not load the shared booking desk.',
            style: AppText.bodyStrong),
        Text(error, style: AppText.caption, textAlign: TextAlign.center),
      ]),
    ));
