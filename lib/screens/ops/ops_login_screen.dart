import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../data/booking_cloud.dart';
import '../../providers/app_providers.dart';
import '../../widgets/ui.dart';

class OpsLoginScreen extends ConsumerStatefulWidget {
  const OpsLoginScreen({super.key});

  @override
  ConsumerState<OpsLoginScreen> createState() => _OpsLoginScreenState();
}

class _OpsLoginScreenState extends ConsumerState<OpsLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(bookingCloudProvider)
          .signInStaff(_email.text, _password.text);
      if (mounted) {
        context.go('/ops');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error is BookingCloudException
            ? error.message
            : 'Sign in failed. Check your email and password.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = ref.watch(bookingCloudProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Team sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Icon(Icons.admin_panel_settings_outlined,
                  size: 54, color: AppColors.primary),
              const SizedBox(height: 18),
              Text('CleanCruisers operations',
                  style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                  'Sign in with an approved staff account to manage bookings and workers.',
                  style: AppText.body,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (!cloud.configured)
                const NoticeBox(
                  icon: Icons.cloud_off_outlined,
                  warning: true,
                  text:
                      'The shared booking system is not connected yet. Complete the Firebase setup before staff can sign in.',
                ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Work email'),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter a valid work email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => value == null || value.length < 6
                        ? 'Enter your password'
                        : null,
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: AppText.small.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Sign in',
                loading: _busy,
                onPressed: cloud.configured ? _signIn : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
