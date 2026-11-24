import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'ui.dart';

/// Opens WhatsApp to the booking number, optionally with a pre-filled message.
/// Returns true if WhatsApp (or wa.me in the browser) opened.
Future<bool> openWhatsApp(BuildContext context, {String? message}) async {
  final url = Uri.parse(message == null
      ? kWhatsAppUrl
      : 'https://wa.me/$kBookingWhatsApp?text=${Uri.encodeComponent(message)}');
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {}
  // No phone calls in the app: email is the fallback.
  if (context.mounted) {
    showMessage(
      context,
      'Couldn\'t open WhatsApp. You can email us at $kEmail.',
      action: SnackBarAction(
          label: 'Email', onPressed: () => openLink(context, 'mailto:$kEmail')),
    );
  }
  return false;
}

Future<void> openLink(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  if (context.mounted) showMessage(context, 'Couldn\'t open the link.');
}
