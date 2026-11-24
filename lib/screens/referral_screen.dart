import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/api/models.dart';
import '../providers/api_providers.dart';
import '../widgets/ui.dart';

final referralProvider =
    FutureProvider.autoDispose<Referral>((ref) => ref.watch(apiProvider).referral());

/// Invite a friend (contract §9, owner rule J4): both get ₹100 CleanCredit
/// after the friend's first completed wash of ₹449 or more. A friend's code
/// can be added once, before the first booking.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _addFriendCode() async {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).updateMe(referralCode: code);
      ref.invalidate(meProvider);
      _code.clear();
      if (mounted) {
        showMessage(context, 'Code added. You both get ₹100 after your first wash.');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on Object {
      setState(() => _error = 'Couldn\'t add the code. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(referralProvider).valueOrNull;
    final me = ref.watch(meProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Invite a friend')),
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.page, AppSpace.sm, AppSpace.page, AppSpace.section),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('YOU BOTH GET ${rupees(r?.rewardEach ?? 100)}',
                    style: AppText.overline.copyWith(color: AppColors.brand)),
                const SizedBox(height: AppSpace.sm),
                Text('Share your code. When your friend\'s first wash is done, '
                    'you both get CleanCredit.',
                    style: AppText.body.copyWith(color: Colors.white)),
                const SizedBox(height: AppSpace.lg),
                Text('Your code',
                    style: AppText.caption.copyWith(color: const Color(0xFFB8C0C7))),
                Text(r?.code ?? '…',
                    style: AppText.display.copyWith(
                        color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: AppSpace.md),
                PrimaryButton(
                  label: 'Copy invite message',
                  icon: Icons.copy_rounded,
                  onPressed: r == null
                      ? null
                      : () {
                          Clipboard.setData(ClipboardData(text: r.shareText));
                          showMessage(context,
                              'Copied. Paste it in WhatsApp to your friend.');
                        },
                ),
              ]),
            ),
            if (r != null) ...[
              const SizedBox(height: AppSpace.md),
              AppCard(
                child: Row(children: [
                  Expanded(
                    child: Column(children: [
                      Text('${r.joined}', style: AppText.h2),
                      Text('Friends joined', style: AppText.caption),
                    ]),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text(rupees(r.rewarded * r.rewardEach), style: AppText.h2),
                      Text('You earned', style: AppText.caption),
                    ]),
                  ),
                ]),
              ),
            ],
            if (me != null && me.isFirstBooking) ...[
              const SizedBox(height: AppSpace.xxl),
              Text('Got a friend\'s code?', style: AppText.h3),
              const SizedBox(height: 2),
              Text('Add it before your first booking.', style: AppText.small),
              const SizedBox(height: AppSpace.md),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _addFriendCode(),
                    decoration: InputDecoration(
                      hintText: 'Friend\'s code',
                      errorText: _error,
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _addFriendCode,
                    child: const Text('Add'),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: AppSpace.xxl),
            const NoticeBox(
              icon: Icons.info_outline_rounded,
              text: 'The friend\'s first wash must be ₹449 or more and done '
                  '(not just booked). Credit lasts 60 days.',
            ),
          ],
        ),
      ),
    );
  }
}
