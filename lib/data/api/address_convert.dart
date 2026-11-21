// The app keeps a saved address as one line ("flat, building, area, near
// landmark · Parking: …") plus an optional "lat,lng" pin. The server keeps
// the parts (contract `Address`). These convert between the two.

import '../../models/booking.dart' show parkingOf, withParking;
import 'models.dart';

/// Parts of a one-line address, for the server.
ApiAddress? apiAddressFromLine(String line, String? pin,
    {String label = 'home', bool isDefault = false, String? id}) {
  final full = line.trim();
  if (full.isEmpty) return null;
  final parking = parkingOf(full);
  final base = withParking(full, null);
  final parts =
      base.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  var landmark = '';
  if (parts.length > 1 && parts.last.toLowerCase().startsWith('near ')) {
    landmark = parts.removeLast().substring(5).trim();
  }
  final flat = parts.isEmpty ? base : parts.first;
  final area = parts.length > 1 ? parts.last : base;
  final building =
      parts.length > 2 ? parts.sublist(1, parts.length - 1).join(', ') : '';
  final pincode = RegExp(r'\b\d{6}\b').firstMatch(base)?.group(0) ?? '';
  ApiPin? apiPin;
  final ll = pin?.split(',');
  if (ll != null && ll.length == 2) {
    final lat = double.tryParse(ll[0]), lng = double.tryParse(ll[1]);
    if (lat != null && lng != null) apiPin = ApiPin(lat, lng, PinSource.pasted);
  }
  return ApiAddress(
    id: id,
    label: label,
    flat: flat,
    building: building,
    area: area.length < 3 ? base : area,
    landmark: landmark,
    pincode: pincode,
    parking: parking,
    pin: apiPin,
    isDefault: isDefault,
  );
}

/// The app's one line for a server address (with its parking note).
String lineOfApiAddress(ApiAddress a) {
  final parts = [a.flat, if (a.building.trim().isNotEmpty) a.building, a.area]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');
  final lm = a.landmark.trim();
  return withParking(lm.isEmpty ? parts : '$parts, near $lm', a.parking);
}

/// "lat,lng" for a server pin.
String? pinOfApiAddress(ApiAddress a) =>
    a.pin == null ? null : '${a.pin!.lat},${a.pin!.lng}';

/// Same place, ignoring case, spaces and punctuation (and the parking note).
bool sameAddressLine(String a, String b) {
  String n(String s) =>
      withParking(s, null).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return n(a).isNotEmpty && n(a) == n(b);
}
