import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/format.dart';
import '../core/scheduling.dart';
import '../models/booking.dart';
import '../models/service.dart';
import '../models/worker.dart';

export '../models/worker.dart';

class BookingCloudException implements Exception {
  final String message;

  /// The chosen slot can no longer be requested (taken, closed or too late).
  /// The booking page offers other open windows instead of a dead end.
  final bool slotTaken;
  const BookingCloudException(this.message, {this.slotTaken = false});
  @override
  String toString() => message;
}

/// Thrown when a proposed worker route breaks a hard rule.
class RouteValidationException extends BookingCloudException {
  final List<RouteIssue> issues;
  RouteValidationException(this.issues)
      : super(issues.map((i) => '• ${i.message}').join('\n'));
}

enum StaffRole { owner, manager, dispatcher }

class StaffAccess {
  final String uid;
  final StaffRole role;
  const StaffAccess(this.uid, this.role);
  bool get isManager => role == StaffRole.owner || role == StaffRole.manager;
}

/// Shared booking store used by the customer app and the booking desk.
///
/// Firestore layout:
///   bookings/{ref}          one record per request, the source of truth
///   capacity/{yyyy-mm-dd}   admin caps/closures + per-window held counts
///   workerDays/{worker_day} refs assigned to a worker on a day (route lock)
///   workers/{id}, staff/{uid}
///   settings/public         service areas (readable by customers)
///   settings/operations     staff-only operating settings
///   incidents/{id}, audit/{id}
class BookingCloud {
  // In-memory mock state for seamless preview / demo without live Firebase
  String? _mockVerifiedPhone;
  String? _mockCustomerName;
  bool _mockSignedIn = false;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  bool get configured => Firebase.apps.isNotEmpty;
  User? get currentUser => configured ? _auth.currentUser : null;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');
  DocumentReference<Map<String, dynamic>> _capacity(DateTime date) =>
      _db.collection('capacity').doc(dateKey(date));
  DocumentReference<Map<String, dynamic>> _workerDay(
          String workerId, DateTime date) =>
      _db.collection('workerDays').doc('${workerId}_${dateKey(date)}');

  // ── Customer login (phone OTP) ──────────────────────────────────────────────

  /// Signed in with a verified phone number (staff email logins don't count).
  bool get customerSignedIn =>
      (configured && (_auth.currentUser?.phoneNumber?.isNotEmpty ?? false)) ||
      _mockSignedIn;

  /// Verified number without "+91", e.g. "9876543210".
  String? get verifiedPhone {
    if (_mockVerifiedPhone != null) return _mockVerifiedPhone;
    final p = currentUser?.phoneNumber;
    if (p == null || p.isEmpty) return null;
    return p.startsWith('+91') ? p.substring(3) : p;
  }

  String? get customerName {
    if (_mockCustomerName != null) return _mockCustomerName;
    final n = currentUser?.displayName?.trim();
    return n == null || n.isEmpty ? null : n;
  }

  /// Fires on sign-in, sign-out and profile (name) changes.
  Stream<User?> userChanges() =>
      configured ? _auth.userChanges() : Stream.value(null);

  /// Sends an OTP to +91 [phone]. On Android the code may be read
  /// automatically, in which case the session comes back already verified.
  Future<OtpSession> sendOtp(String phone, {OtpSession? resend}) async {
    if (!configured) {
      // In preview/standalone mode: provide instant mock OTP session
      return OtpSession(
          phone: phone, verificationId: 'mock-verification-$phone');
    }
    final number = '+91$phone';
    try {
      if (kIsWeb) {
        final result = await _auth.signInWithPhoneNumber(number);
        return OtpSession(phone: phone, web: result);
      }
      final done = Completer<OtpSession>();
      await _auth.verifyPhoneNumber(
        phoneNumber: number,
        forceResendingToken: resend?.resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            await _signInWith(credential);
            if (!done.isCompleted) {
              done.complete(OtpSession(phone: phone, autoVerified: true));
            }
          } on Object catch (e) {
            if (!done.isCompleted) done.completeError(_otpError(e));
          }
        },
        verificationFailed: (e) {
          if (!done.isCompleted) done.completeError(_otpError(e));
        },
        codeSent: (id, token) {
          if (!done.isCompleted) {
            done.complete(OtpSession(
                phone: phone, verificationId: id, resendToken: token));
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return await done.future;
    } on BookingCloudException {
      rethrow;
    } on Object catch (e) {
      throw _otpError(e);
    }
  }

  Future<void> verifyOtp(OtpSession session, String code) async {
    try {
      if (!configured ||
          (session.verificationId?.startsWith('mock-') ?? false)) {
        _mockVerifiedPhone = session.phone;
        _mockSignedIn = true;
        return;
      }
      if (session.web != null) {
        await session.web!.confirm(code);
      } else if (session.verificationId != null) {
        await _signInWith(PhoneAuthProvider.credential(
            verificationId: session.verificationId!, smsCode: code));
      }
    } on Object catch (e) {
      throw _otpError(e);
    }
  }

  Future<void> _signInWith(PhoneAuthCredential credential) async {
    await _auth.signInWithCredential(credential);
  }

  Future<void> saveCustomerName(String name) async {
    _mockCustomerName = name.trim();
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await user.reload();
  }

  Future<void> signOutCustomer() => _auth.signOut();

  BookingCloudException _otpError(Object e) {
    final code = e is FirebaseAuthException ? e.code : '';
    return BookingCloudException(switch (code) {
      'invalid-phone-number' => "That mobile number doesn't look right.",
      'invalid-verification-code' =>
        'That OTP is incorrect. Please check and try again.',
      'session-expired' ||
      'code-expired' =>
        'This OTP has expired. Tap "Resend OTP" for a new one.',
      'too-many-requests' ||
      'quota-exceeded' =>
        'Too many attempts. Please wait a few minutes and try again.',
      'operation-not-allowed' =>
        "Phone login isn't switched on yet. Please call us to book.",
      'network-request-failed' =>
        'No internet connection. Please check and try again.',
      _ => "We couldn't verify your number. Please try again.",
    });
  }

  void _requireCustomer() {
    if (!configured) {
      throw const BookingCloudException(
        'Online booking is not connected yet. Please call us while we finish setup.',
      );
    }
    if (!customerSignedIn) {
      throw const BookingCloudException(
          'Please log in with your mobile number to send a booking.');
    }
  }

  // ── Customer ────────────────────────────────────────────────────────────────

  /// Admin-configured service areas. Empty when none are set up, in which
  /// case coverage is always "unverified".
  Future<List<ServiceArea>> serviceAreas() async {
    if (!configured) return const [];
    final doc = await _db.collection('settings').doc('public').get();
    return [
      for (final a in (doc.data()?['serviceAreas'] as List? ?? const []))
        ServiceArea.fromJson(a),
    ].whereType<ServiceArea>().toList();
  }

  Stream<CapacityDay> watchCapacity(DateTime date) => configured
      ? _capacity(date).snapshots().map((s) => CapacityDay.fromJson(s.data()))
      : Stream.value(CapacityDay.open);

  /// Saves the request and counts it against the window's capacity in one
  /// transaction. Retrying with the same reference is safe: if the first
  /// attempt landed, the retry returns without writing anything.
  Future<void> submit(BookingRecord booking) async {
    try {
      _requireCustomer();
      final uid = _auth.currentUser!.uid;
      final doc = _bookings.doc(booking.ref);
      final capRef = _capacity(booking.date);
      await _db.runTransaction((tx) async {
        final existing = await tx.get(doc);
        if (existing.exists) {
          if (existing.data()?['customerUid'] == uid) return;
          throw const BookingCloudException(
              'Please go back one step and send the request again.');
        }
        final capSnap = await tx.get(capRef);
        final state = customerWindowState(
          windowStart: slotById(booking.slotId)!.startMinute,
          windowId: booking.slotId,
          date: booking.date,
          serviceMinutes: booking.serviceDurationMinutes,
          capacity: CapacityDay.fromJson(capSnap.data()),
        );
        switch (state) {
          case WindowState.preference:
            break;
          case WindowState.full:
          case WindowState.closedByTeam:
            throw const BookingCloudException(
                'Sorry, that slot just got booked. Please pick another time.',
                slotTaken: true);
          case WindowState.passed:
          case WindowState.tooLate:
            throw const BookingCloudException(
                'That slot is no longer available for this service. Please pick another time.',
                slotTaken: true);
        }
        tx.set(doc, {
          ...booking.toCustomerJson(),
          'customerUid': uid,
          'status': BookingStatus.requested.name,
          'source': 'customer_app',
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final held = '${CapacityDay.heldPrefix}${booking.slotId}';
        if (capSnap.exists) {
          tx.update(
              capRef, {held: FieldValue.increment(1), 'lastRef': booking.ref});
        } else {
          tx.set(capRef, {held: 1, 'lastRef': booking.ref});
        }
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const BookingCloudException(
          'We could not save this request securely. Please contact support.',
        );
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        throw const BookingCloudException(
          'No connection, so your request was not sent. Your details are still here. Please try again.',
        );
      }
      rethrow;
    }
  }

  Stream<List<BookingRecord>> watchCustomerBookings(String uid) => _bookings
      .where('customerUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs) BookingRecord.fromJson(doc.data()),
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  Stream<List<BookingRecord>> watchSignedInBookings() =>
      _auth.authStateChanges().asyncExpand((user) => user == null
          ? Stream.value(const <BookingRecord>[])
          : watchCustomerBookings(user.uid));

  Future<void> requestCustomerChange(
      BookingRecord booking, String request) async {
    if (_auth.currentUser == null) {
      throw const BookingCloudException(
          'Please reopen this booking and try again.');
    }
    await _bookings.doc(booking.ref).update({
      'customerChangeRequest': request,
      'customerChangeRequestedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Staff access ────────────────────────────────────────────────────────────

  Future<StaffAccess?> staffAccess(String uid) async {
    final doc = await _db.collection('staff').doc(uid).get();
    final data = doc.data();
    if (data == null || data['active'] != true) return null;
    final role =
        StaffRole.values.where((r) => r.name == data['role']).firstOrNull ??
            StaffRole.dispatcher;
    return StaffAccess(uid, role);
  }

  Future<bool> isStaff(String uid) async => await staffAccess(uid) != null;

  Future<void> signInStaff(String email, String password) async {
    if (!configured) {
      throw const BookingCloudException(
        'Operations login is not connected. Finish Firebase setup first.',
      );
    }
    final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    if (!await isStaff(credential.user!.uid)) {
      await _auth.signOut();
      throw const BookingCloudException(
        'This account does not have staff access. Ask the business owner to add it.',
      );
    }
  }

  Future<void> signOutStaff() => _auth.signOut();

  // ── Desk data ───────────────────────────────────────────────────────────────

  /// Bookings from [daysBack] days ago onwards, soonest first.
  Stream<List<BookingRecord>> watchOperationsBookings({int daysBack = 30}) {
    final from = DateTime.now().subtract(Duration(days: daysBack));
    return _bookings
        .where('date',
            isGreaterThanOrEqualTo:
                DateTime(from.year, from.month, from.day).toIso8601String())
        .orderBy('date')
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                BookingRecord.fromJson(doc.data()),
            ]);
  }

  Stream<List<WorkerRecord>> watchWorkers() =>
      _db.collection('workers').orderBy('name').snapshots().map((snapshot) => [
            for (final doc in snapshot.docs)
              WorkerRecord.fromJson(doc.id, doc.data()),
          ]);

  Future<void> saveWorker(WorkerRecord worker, {String? reason}) async {
    final batch = _db.batch();
    batch.set(_db.collection('workers').doc(worker.id), worker.toJson());
    _audit(batch.set, 'worker.saved',
        workerId: worker.id, reason: reason, details: worker.toJson());
    await batch.commit();
  }

  Stream<OpsSettings> watchOpsSettings() => _db
      .collection('settings')
      .doc('operations')
      .snapshots()
      .map((s) => OpsSettings.fromJson(s.data()));

  Future<void> saveOpsSettings(OpsSettings settings) async {
    final batch = _db.batch();
    batch.set(_db.collection('settings').doc('operations'), {
      ...settings.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
    _audit(batch.set, 'settings.operations', details: settings.toJson());
    await batch.commit();
  }

  Future<void> saveServiceAreas(List<ServiceArea> areas) async {
    final batch = _db.batch();
    batch.set(_db.collection('settings').doc('public'), {
      'serviceAreas': [for (final a in areas) a.toJson()],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
    _audit(batch.set, 'settings.serviceAreas',
        details: {'areas': areas.map((a) => a.name).toList()});
    await batch.commit();
  }

  /// Opens/closes a date or windows and sets per-window caps. Caps only
  /// limit requests; they never create worker time.
  Future<void> saveCapacity(
    DateTime date, {
    required bool closed,
    required Set<String> closedWindows,
    required Map<String, int> caps,
    required String reason,
  }) async {
    if (reason.trim().length < 3) {
      throw const BookingCloudException('Add a short reason for this change.');
    }
    final batch = _db.batch();
    final update = {
      'closed': closed,
      'closedWindows': closedWindows.toList()..sort(),
      'caps': caps,
      'note': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    };
    batch.set(_capacity(date), update, SetOptions(merge: true));
    _audit(batch.set, 'capacity.changed',
        reason: reason,
        details: {...update, 'date': dateKey(date)}..remove('updatedAt'));
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> watchOpenIncidents() => _db
      .collection('incidents')
      .where('open', isEqualTo: true)
      .snapshots()
      .map((s) => [
            for (final d in s.docs) {...d.data(), 'id': d.id}
          ]);

  // ── Status changes ──────────────────────────────────────────────────────────

  /// Moves a booking to [status], appends to its history, releases capacity
  /// and the worker's route slot when the booking stops needing them, and
  /// writes an audit record — all in one transaction.
  Future<void> setStatus(
    BookingRecord booking,
    BookingStatus status, {
    required String action,
    String? customerNote,
    String? operationsNote,
    String? reason,
    Map<String, dynamic> extra = const {},
    Map<String, dynamic>? incident,
  }) async {
    final doc = _bookings.doc(booking.ref);
    await _db.runTransaction((tx) async {
      final current = await _read(tx, booking.ref);
      if (current.status != booking.status) {
        throw BookingCloudException(
            'This booking changed to "${current.status.label}" meanwhile. Check it again.');
      }
      final detach = current.workerId != null &&
          (status.isFinal && status != BookingStatus.completed ||
              status == BookingStatus.rescheduleNeeded);
      final day = detach
          ? await _loadWorkerDay(tx, current.workerId!, current.date)
          : null;

      final updates = <String, dynamic>{
        'status': status.name,
        'history': FieldValue.arrayUnion([
          StatusEvent(status, DateTime.now(), customerNote).toJson(),
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
        if (customerNote != null) 'customerNote': customerNote,
        if (operationsNote != null) 'operationsNote': operationsNote,
        ...extra,
      };
      if (current.capacityHeld && !status.holdsCapacity) {
        updates['capacityHeld'] = false;
        tx.update(_capacity(current.date), {
          '${CapacityDay.heldPrefix}${current.slotId}':
              FieldValue.increment(-1),
        });
      }
      if (day != null) {
        _detach(tx, day, current);
        updates.addAll(_unassignedFields);
      }
      tx.update(doc, updates);
      if (incident != null) {
        tx.set(_db.collection('incidents').doc(), {
          ...incident,
          'bookingRefs': [booking.ref],
          'date': dateKey(current.date),
          'open': true,
          'reportedAt': FieldValue.serverTimestamp(),
          'reportedBy': _auth.currentUser?.uid,
        });
      }
      _audit(tx.set, action,
          ref: booking.ref,
          reason: reason,
          details: {'from': current.status.name, 'to': status.name});
    });
  }

  Future<void> askForDetails(BookingRecord b, String question) => setStatus(
        b,
        BookingStatus.teamReview,
        action: 'booking.askDetails',
        customerNote: question,
      );

  Future<void> reject(BookingRecord b, String reason) => setStatus(
        b,
        BookingStatus.unableToServe,
        action: 'booking.rejected',
        customerNote: reason,
        reason: reason,
      );

  Future<void> cancel(BookingRecord b, String reason) => setStatus(
        b,
        BookingStatus.cancelled,
        action: 'booking.cancelled',
        customerNote: reason,
        reason: reason,
        extra: {'customerChangeRequest': FieldValue.delete()},
      );

  Future<void> offerAlternative(
          BookingRecord b, DateTime date, TimeSlot slot, String why) =>
      setStatus(
        b,
        BookingStatus.rescheduleNeeded,
        action: 'booking.alternativeOffered',
        reason: why,
        customerNote:
            '$why We can offer ${shortDate(date)}, ${slot.label}. Accept it below or ask for another time.',
        extra: {
          'offeredDate':
              DateTime(date.year, date.month, date.day).toIso8601String(),
          'offeredSlotId': slot.id,
          'customerChangeRequest': FieldValue.delete(),
        },
      );

  /// Rain or site access makes the visit impossible. Package credits are kept.
  Future<void> reportSiteIncident(BookingRecord b, String kind, String note) =>
      setStatus(
        b,
        BookingStatus.rescheduleNeeded,
        action: 'incident.$kind',
        reason: note,
        customerNote: kind == 'weather'
            ? 'Rain means we can\'t do a good job at the planned time. We\'ll offer you a new date or time.'
            : 'We couldn\'t access the car at the planned time. We\'ll offer you a new date or time.',
        extra: {
          'creditPreserved': b.category == ServiceCategory.monthly,
          'riskFlag': FieldValue.delete(),
        },
        incident: {'type': kind, 'note': note, 'workerId': b.workerId},
      );

  Future<void> markOnTheWay(BookingRecord b) =>
      setStatus(b, BookingStatus.onTheWay, action: 'booking.onTheWay');

  Future<void> markInService(BookingRecord b) =>
      setStatus(b, BookingStatus.inService, action: 'booking.inService');

  /// Records completion and what was collected. No online payment is taken.
  Future<void> complete(BookingRecord b,
          {required int amount,
          required PaymentMethod method,
          double? actualKm,
          int? actualMinutes}) =>
      setStatus(
        b,
        BookingStatus.completed,
        action: 'booking.completed',
        extra: {
          'amountCollected': amount,
          'paymentMethod': method.name,
          'collectedAt': DateTime.now().toIso8601String(),
          'actualKm': actualKm,
          'actualMinutes': actualMinutes,
          'riskFlag': FieldValue.delete(),
        },
      );

  /// Moves a booking to a new date/window agreed with the customer. The new
  /// window's capacity cap is respected; the old window is released.
  Future<void> applyNewTime(
      BookingRecord booking, DateTime date, TimeSlot slot) async {
    final day0 = DateTime(date.year, date.month, date.day);
    await _db.runTransaction((tx) async {
      final current = await _read(tx, booking.ref);
      if (current.status.isFinal) {
        throw const BookingCloudException('This booking is already closed.');
      }
      final newCapRef = _capacity(day0);
      final cap = CapacityDay.fromJson((await tx.get(newCapRef)).data());
      final state = customerWindowState(
        windowStart: slot.startMinute,
        windowId: slot.id,
        date: day0,
        serviceMinutes: current.serviceDurationMinutes,
        capacity: cap,
      );
      if (state != WindowState.preference) {
        throw BookingCloudException(switch (state) {
          WindowState.full =>
            'That window is at its cap. Raise the cap on the Capacity tab first if the team can really take it.',
          WindowState.closedByTeam => 'That date or window is closed.',
          _ => 'This service cannot fit in that window before 6 PM.',
        });
      }
      final day = current.workerId == null
          ? null
          : await _loadWorkerDay(tx, current.workerId!, current.date);

      if (current.capacityHeld) {
        tx.update(_capacity(current.date), {
          '${CapacityDay.heldPrefix}${current.slotId}':
              FieldValue.increment(-1),
        });
      }
      tx.set(
          newCapRef,
          {'${CapacityDay.heldPrefix}${slot.id}': FieldValue.increment(1)},
          SetOptions(merge: true));
      if (day != null) _detach(tx, day, current);
      final note =
          'New time agreed: ${shortDate(day0)}, ${slot.label}. We\'ll confirm once a worker is assigned.';
      tx.update(_bookings.doc(booking.ref), {
        ..._unassignedFields,
        'date': day0.toIso8601String(),
        'dateKey': dateKey(day0),
        'slotId': slot.id,
        'slotLabel': slot.label,
        'status': BookingStatus.teamReview.name,
        'capacityHeld': true,
        'offeredDate': FieldValue.delete(),
        'offeredSlotId': FieldValue.delete(),
        'customerChangeRequest': FieldValue.delete(),
        'customerNote': note,
        'history': FieldValue.arrayUnion([
          StatusEvent(BookingStatus.teamReview, DateTime.now(), note).toJson()
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _audit(tx.set, 'booking.rescheduled', ref: booking.ref, details: {
        'from': '${dateKey(current.date)} ${current.slotId}',
        'to': '${dateKey(day0)} ${slot.id}',
      });
    });
  }

  // ── Assignment ──────────────────────────────────────────────────────────────

  /// Assigns [worker] and confirms the booking, but only if the worker's
  /// whole day still validates: leave/weekly off, skills, every road leg
  /// (≤25 km for regular staff), windows, lunch, the 6 PM finish and the
  /// emergency worker's 11 AM standby return.
  ///
  /// [legIn] is previous stop (or home/standby) → this site. [legOut] is this
  /// site → the next stop, or → home/standby if this becomes the last job.
  /// The day is re-read and re-planned inside the transaction, so two
  /// dispatchers can't overbook the same worker.
  Future<DayPlan> assignWorker({
    required BookingRecord booking,
    required WorkerRecord worker,
    required RouteLeg legIn,
    required RouteLeg legOut,
    required ScheduleRules rules,
    required StaffAccess staff,
    bool addressVerified = false,
    String? emergencyDispatchReason,
  }) async {
    final longLegsOk = worker.isEmergency &&
        staff.isManager &&
        (emergencyDispatchReason?.trim().length ?? 0) >= 8;
    late DayPlan plan;
    await _db.runTransaction((tx) async {
      final current = await _read(tx, booking.ref);
      if (!{
        BookingStatus.requested,
        BookingStatus.teamReview,
        BookingStatus.confirmed,
      }.contains(current.status)) {
        throw BookingCloudException(
            'A booking that is "${current.status.label}" can\'t be assigned.');
      }
      if (dateOnly(current.date).isBefore(dateOnly(DateTime.now()))) {
        throw const BookingCloudException(
            'This date has passed. Agree a new time first.');
      }
      if (current.coverage != Coverage.covered && !addressVerified) {
        throw const BookingCloudException(
            'The address hasn\'t been verified as inside the service area. Check it, then tick "Address verified".');
      }
      final day = await _loadWorkerDay(tx, worker.id, current.date,
          exclude: current.ref);
      final oldDay = current.workerId != null && current.workerId != worker.id
          ? await _loadWorkerDay(tx, current.workerId!, current.date)
          : null;

      final others = day.bookings;
      final all = [...others, current]..sort((a, b) => slotById(a.slotId)!
          .startMinute
          .compareTo(slotById(b.slotId)!.startMinute));
      final i = all.indexOf(current);
      final next = i + 1 < all.length ? all[i + 1] : null;
      final previousLast = others.isEmpty ? null : others.last;

      final jobs = [
        for (final b in all)
          PlannedJob(
            ref: b.ref,
            windowStart: slotById(b.slotId)!.startMinute,
            windowEnd: slotById(b.slotId)!.endMinute,
            serviceMinutes: b.serviceDurationMinutes,
            category: b.category,
            legIn: identical(b, current)
                ? legIn
                : identical(b, next)
                    ? legOut
                    : b.legIn,
          ),
      ];
      final returnLeg = next == null ? legOut : previousLast?.returnLeg;
      plan = planWorkerDay(
        worker: worker,
        date: current.date,
        jobs: jobs,
        returnLeg: returnLeg,
        rules: rules,
        allowEmergencyLongLegs: longLegsOk,
      );
      if (!plan.feasible) throw RouteValidationException(plan.issues);

      // Writes.
      if (oldDay != null) _detach(tx, oldDay, current);
      final me = plan.stopFor(current.ref)!;
      final note = 'Expert booked. Arriving around ${clockLabel(me.arriveAt)}.';
      tx.update(_bookings.doc(current.ref), {
        'workerId': worker.id,
        'legIn': legIn.toJson(),
        'returnLeg': next == null ? legOut.toJson() : null,
        'plannedArrivalMinute': me.arriveAt,
        'plannedFinishMinute': me.workEnd,
        'status': BookingStatus.confirmed.name,
        'customerNote': note,
        'riskFlag': FieldValue.delete(),
        if (longLegsOk)
          'operationsNote':
              'Emergency dispatch beyond ${rules.maxLegKm.toStringAsFixed(0)} km: ${emergencyDispatchReason!.trim()}',
        if (current.status != BookingStatus.confirmed)
          'history': FieldValue.arrayUnion([
            StatusEvent(BookingStatus.confirmed, DateTime.now(), note).toJson()
          ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final b in others) {
        final stop = plan.stopFor(b.ref)!;
        tx.update(_bookings.doc(b.ref), {
          'plannedArrivalMinute': stop.arriveAt,
          'plannedFinishMinute': stop.workEnd,
          if (identical(b, next)) 'legIn': legOut.toJson(),
          if (identical(b, next)) 'riskFlag': FieldValue.delete(),
          if (next == null && identical(b, previousLast)) 'returnLeg': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(_workerDay(worker.id, current.date), {
        'refs': [...others.map((b) => b.ref), current.ref],
        'workerId': worker.id,
        'date': dateKey(current.date),
      });
      if (longLegsOk) {
        tx.set(_db.collection('incidents').doc(), {
          'type': 'emergencyDispatch',
          'note': emergencyDispatchReason!.trim(),
          'workerId': worker.id,
          'bookingRefs': [current.ref],
          'date': dateKey(current.date),
          'open': false,
          'reportedAt': FieldValue.serverTimestamp(),
          'reportedBy': _auth.currentUser?.uid,
        });
      }
      _audit(tx.set, 'booking.assigned',
          ref: current.ref,
          workerId: worker.id,
          reason: longLegsOk ? emergencyDispatchReason : null,
          details: {
            'legIn': legIn.toJson(),
            'legOut': legOut.toJson(),
            'arrival': me.arriveAt,
          });
    });
    return plan;
  }

  // ── Worker disruptions ──────────────────────────────────────────────────────

  /// A worker reports a problem for [date]. Their unstarted jobs that day are
  /// flagged at risk and no new work can be assigned to them that day.
  Future<void> reportDisruption(WorkerRecord worker, DateTime date,
      DisruptionType type, String note) async {
    final key = dateKey(date);
    final affected = await _bookings
        .where('workerId', isEqualTo: worker.id)
        .where('dateKey', isEqualTo: key)
        .get();
    final batch = _db.batch();
    final leave = type == DisruptionType.absent || type == DisruptionType.sick;
    batch.update(_db.collection('workers').doc(worker.id), {
      'disruptions.$key': type.name,
      if (leave) 'unavailableDates': FieldValue.arrayUnion([key]),
    });
    final refs = <String>[];
    for (final doc in affected.docs) {
      final status = parseStatus(doc.data()['status']);
      if (status == BookingStatus.confirmed ||
          status == BookingStatus.onTheWay) {
        refs.add(doc.id);
        batch.update(doc.reference, {
          'riskFlag': type.label,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    batch.set(_db.collection('incidents').doc(), {
      'type': type.name,
      'note': note,
      'workerId': worker.id,
      'bookingRefs': refs,
      'date': key,
      'open': true,
      'reportedAt': FieldValue.serverTimestamp(),
      'reportedBy': _auth.currentUser?.uid,
    });
    _audit(batch.set, 'worker.disruption',
        workerId: worker.id, reason: note, details: {'type': type.name});
    await batch.commit();
  }

  Future<void> resolveDisruption(WorkerRecord worker, DateTime date) async {
    final key = dateKey(date);
    final incidents = await _db
        .collection('incidents')
        .where('workerId', isEqualTo: worker.id)
        .where('date', isEqualTo: key)
        .where('open', isEqualTo: true)
        .get();
    final batch = _db.batch();
    batch.update(_db.collection('workers').doc(worker.id),
        {'disruptions.$key': FieldValue.delete()});
    for (final i in incidents.docs) {
      batch.update(i.reference,
          {'open': false, 'closedAt': FieldValue.serverTimestamp()});
    }
    _audit(batch.set, 'worker.disruptionResolved',
        workerId: worker.id, details: {'date': key});
    await batch.commit();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  Future<BookingRecord> _read(Transaction tx, String ref) async {
    final snap = await tx.get(_bookings.doc(ref));
    final data = snap.data();
    if (data == null) {
      throw const BookingCloudException('This booking no longer exists.');
    }
    return BookingRecord.fromJson(data);
  }

  Future<_WorkerDay> _loadWorkerDay(
      Transaction tx, String workerId, DateTime date,
      {String? exclude}) async {
    final lock = await tx.get(_workerDay(workerId, date));
    final refs = [
      for (final r in (lock.data()?['refs'] as List? ?? const []))
        if (r != exclude) r as String,
    ];
    final bookings = <BookingRecord>[];
    for (final r in refs) {
      final snap = await tx.get(_bookings.doc(r));
      final data = snap.data();
      if (data == null) continue;
      final b = BookingRecord.fromJson(data);
      // Only work still on this worker's route that day counts.
      if (b.workerId == workerId &&
          dateKey(b.date) == dateKey(date) &&
          b.status.holdsCapacity) {
        bookings.add(b);
      }
    }
    bookings.sort((a, b) => slotById(a.slotId)!
        .startMinute
        .compareTo(slotById(b.slotId)!.startMinute));
    return _WorkerDay(workerId, date, bookings);
  }

  /// Takes [booking] off its worker's route. The neighbouring leg no longer
  /// matches the real route, so it's cleared and flagged for the dispatcher.
  void _detach(Transaction tx, _WorkerDay day, BookingRecord booking) {
    final list = day.bookings;
    final i = list.indexWhere((b) => b.ref == booking.ref);
    final remaining = [...list]..removeWhere((b) => b.ref == booking.ref);
    tx.set(_workerDay(day.workerId, day.date), {
      'refs': remaining.map((b) => b.ref).toList(),
      'workerId': day.workerId,
      'date': dateKey(day.date),
    });
    if (i < 0) return;
    const flag = 'Route changed: re-enter the drive from the previous stop';
    if (i + 1 < list.length) {
      tx.update(_bookings.doc(list[i + 1].ref), {
        'legIn': null,
        'riskFlag': flag,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (i > 0) {
      tx.update(_bookings.doc(list[i - 1].ref), {
        'returnLeg': null,
        'riskFlag': 'Route changed: re-enter the drive home',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static const _unassignedFields = <String, dynamic>{
    'workerId': null,
    'legIn': null,
    'returnLeg': null,
    'plannedArrivalMinute': null,
    'plannedFinishMinute': null,
  };

  void _audit(
    void Function(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)
        set,
    String action, {
    String? ref,
    String? workerId,
    String? reason,
    Map<String, dynamic>? details,
  }) {
    set(_db.collection('audit').doc(), {
      'action': action,
      'actor': _auth.currentUser?.uid,
      'at': FieldValue.serverTimestamp(),
      if (ref != null) 'bookingRef': ref,
      if (workerId != null) 'workerId': workerId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (details != null) 'details': details,
    });
  }
}

/// An OTP in progress. Mobile uses [verificationId]; web uses [web].
class OtpSession {
  final String phone; // 10 digits
  final String? verificationId;
  final int? resendToken;
  final ConfirmationResult? web;
  final bool autoVerified;
  const OtpSession({
    required this.phone,
    this.verificationId,
    this.resendToken,
    this.web,
    this.autoVerified = false,
  });
}

class _WorkerDay {
  final String workerId;
  final DateTime date;
  final List<BookingRecord> bookings; // by window
  const _WorkerDay(this.workerId, this.date, this.bookings);
}
