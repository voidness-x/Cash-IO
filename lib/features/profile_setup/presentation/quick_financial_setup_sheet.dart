import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

/// Friendly modal sheet allowing both newly onboarded and existing upgraded users
/// to set their starting Cash Wallet balance, Bank balance, and starter 50/30/20 budgets.
class QuickFinancialSetupSheet extends StatefulWidget {
  const QuickFinancialSetupSheet({super.key});

  @override
  State<QuickFinancialSetupSheet> createState() => _QuickFinancialSetupSheetState();
}

class _QuickFinancialSetupSheetState extends State<QuickFinancialSetupSheet> {
  final _cashCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _goalTargetCtrl = TextEditingController();
  bool _createStarterEnvelopes = true;
  bool _isSaving = false;

  List<int> _quickChipsForCurrency(String currency) {
    if (currency == 'IQD') {
      return const [25000, 100000, 250000, 1000000];
    }
    return const [50, 100, 500, 1000];
  }

  String _formatQuickChip(int amount, String currency) {
    if (amount >= 1000000) return '+1M';
    if (amount >= 1000) return '+${(amount / 1000).toStringAsFixed(0)}K';
    return '+$amount';
  }

  void _addToController(TextEditingController ctrl, int increment) {
    HapticFeedback.selectionClick();
    final raw = ctrl.text.replaceAll(',', '').trim();
    final current = double.tryParse(raw) ?? 0;
    final next = current + increment;
    ctrl.text = next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
    setState(() {});
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _bankCtrl.dispose();
    _goalTargetCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSetup() async {
    setState(() => _isSaving = true);
    final repo = VaultRepository.instance;
    final cashCents = CurrencyUtils.parseToCents(_cashCtrl.text.trim());
    final bankCents = CurrencyUtils.parseToCents(_bankCtrl.text.trim());
    final goalCents = CurrencyUtils.parseToCents(_goalTargetCtrl.text.trim());

    await repo.setupInitialFinancialData(
      startingCashCents: cashCents,
      startingBankCents: bankCents,
      createStarterEnvelopes: _createStarterEnvelopes,
      emergencyGoalTargetCents: goalCents,
    );

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Vault balances and starter budgets configured!',
          style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
        ),
        backgroundColor: context.tokens.statusIncome,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final currency = VaultRepository.instance.baseCurrency;
    final quickAmounts = _quickChipsForCurrency(currency);

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.borderHairline),
      ),
      padding: EdgeInsets.only(
        left: tokens.space5,
        right: tokens.space5,
        top: tokens.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + tokens.space5,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: tokens.space4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.account_balance_wallet_outlined, color: tokens.accent, size: 22),
                ),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INITIALIZE CASH & BUDGETS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'Enter your current cash & bank balances to start cleanly',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: tokens.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: tokens.space4),

            // 1. Cash in Wallet
            Text(
              'CASH ON HAND (WALLET)',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _cashCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '$currency ',
                hintText: '0',
                prefixIcon: const Icon(Icons.wallet_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickAmounts.map((amt) {
                return ActionChip(
                  label: Text(
                    _formatQuickChip(amt, currency),
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.accent),
                  ),
                  backgroundColor: tokens.bgSurfaceElevated,
                  side: BorderSide(color: tokens.borderHairline),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addToController(_cashCtrl, amt),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space4),

            // 2. Bank / Card Balance
            Text(
              'BANK OR CARD BALANCE (OPTIONAL)',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bankCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '$currency ',
                hintText: '0',
                prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
              ),
            ),
            SizedBox(height: tokens.space4),

            // 3. Emergency Savings Target (Optional)
            Text(
              'EMERGENCY SAVINGS GOAL TARGET (OPTIONAL)',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _goalTargetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '$currency ',
                hintText: currency == 'IQD' ? 'e.g. 1500000' : 'e.g. 1500',
                prefixIcon: const Icon(Icons.shield_outlined, size: 20),
              ),
            ),
            SizedBox(height: tokens.space3),

            // 4. Auto-Create Starter Budget Envelopes
            Container(
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  title: Text(
                    'Create Starter 50/30/20 Envelopes',
                    style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Sets up Essentials, Bills & Transport, and Personal envelopes',
                    style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                  ),
                  value: _createStarterEnvelopes,
                  activeTrackColor: tokens.accent,
                  onChanged: (val) => setState(() => _createStarterEnvelopes = val),
                ),
              ),
            ),
            SizedBox(height: tokens.space5),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveSetup,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _isSaving ? 'APPLYING BALANCES...' : 'SAVE & START TRACKING',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
