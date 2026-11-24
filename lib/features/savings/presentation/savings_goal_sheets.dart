import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

/// Modal sheet to create a new Savings Goal / Locked Vault
class CreateSavingsGoalSheet extends StatefulWidget {
  final String baseCurrency;

  const CreateSavingsGoalSheet({super.key, required this.baseCurrency});

  @override
  State<CreateSavingsGoalSheet> createState() => _CreateSavingsGoalSheetState();
}

class _CreateSavingsGoalSheetState extends State<CreateSavingsGoalSheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _initialDepositCtrl = TextEditingController();
  bool _isLocked = true;
  IconData _selectedIcon = Icons.savings_outlined;
  int _targetDays = 90;

  final List<IconData> _icons = [
    Icons.savings_outlined,
    Icons.shield_outlined,
    Icons.home_outlined,
    Icons.directions_car_outlined,
    Icons.flight_takeoff_outlined,
    Icons.school_outlined,
    Icons.military_tech_outlined,
    Icons.favorite_outline,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _initialDepositCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameCtrl.text.trim();
    final targetCents = CurrencyUtils.parseToCents(_targetCtrl.text.trim());
    final initialCents = CurrencyUtils.parseToCents(_initialDepositCtrl.text.trim());

    if (name.isEmpty || targetCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal name and valid target amount.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    VaultRepository.instance.addSavingsGoal(
      name: name,
      targetAmountCents: targetCents,
      targetDate: DateTime.now().add(Duration(days: _targetDays)),
      isLocked: _isLocked,
      icon: _selectedIcon,
      initialDepositCents: initialCents,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created goal vault "$name" successfully.', style: GoogleFonts.mukta(fontWeight: FontWeight.w600)),
        backgroundColor: context.tokens.statusIncome,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.only(
        left: tokens.space5,
        right: tokens.space5,
        top: tokens.space5,
        bottom: MediaQuery.of(context).viewInsets.bottom + tokens.space6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(tokens.space2),
                  decoration: BoxDecoration(
                    color: tokens.statusIncome.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.savings_outlined, color: tokens.statusIncome, size: 24),
                ),
                SizedBox(width: tokens.space3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CREATE SAVINGS GOAL VAULT',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Dedicated capital reserve with lock protection',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: tokens.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: tokens.space4),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Goal Title (e.g. Emergency Fund, Down Payment)',
                prefixIcon: Icon(Icons.label_outline, size: 20),
              ),
            ),
            SizedBox(height: tokens.space3),

            TextField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target Savings Amount',
                prefixText: '${widget.baseCurrency} ',
                prefixIcon: const Icon(Icons.track_changes, size: 20),
              ),
            ),
            SizedBox(height: tokens.space3),

            TextField(
              controller: _initialDepositCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Opening Deposit (Optional)',
                prefixText: '${widget.baseCurrency} ',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
              ),
            ),
            SizedBox(height: tokens.space3),

            // Target Horizon Chips
            Text('TARGET TIMEFRAME', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [30, 60, 90, 180, 365].map((days) {
                final isSel = _targetDays == days;
                final label = days < 365 ? '$days Days' : '1 Year';
                return ChoiceChip(
                  label: Text(label),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _targetDays = days);
                  },
                  selectedColor: tokens.statusIncome,
                  labelStyle: GoogleFonts.spaceGrotesk(
                    color: isSel ? tokens.bgPrimary : tokens.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space3),

            // Lock Switch
            Container(
              padding: EdgeInsets.symmetric(horizontal: tokens.space3, vertical: tokens.space2),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _isLocked ? Icons.lock_outline : Icons.lock_open_outlined,
                  color: _isLocked ? tokens.accentGold : tokens.textTertiary,
                ),
                title: Text(
                  'Lock Vault (Discipline Protection)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Prevents impulsive withdrawals without explicit unlock',
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                ),
                value: _isLocked,
                activeTrackColor: tokens.statusIncome,
                onChanged: (val) => setState(() => _isLocked = val),
              ),
            ),
            SizedBox(height: tokens.space4),

            // Icon Picker
            Text('VAULT ICON', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: _icons.map((icon) {
                final isSel = _selectedIcon == icon;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = icon),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSel ? tokens.statusIncome.withValues(alpha: 0.25) : tokens.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: isSel ? tokens.statusIncome : tokens.borderHairline),
                    ),
                    child: Icon(icon, color: isSel ? tokens.statusIncome : tokens.textSecondary, size: 20),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space5),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.statusIncome,
                  foregroundColor: tokens.bgPrimary,
                ),
                child: Text('CREATE VAULT', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deposit or Transfer Funds into a Goal Vault
class DepositToGoalSheet extends StatefulWidget {
  final SavingsGoalModel goal;
  final String baseCurrency;

  const DepositToGoalSheet({super.key, required this.goal, required this.baseCurrency});

  @override
  State<DepositToGoalSheet> createState() => _DepositToGoalSheetState();
}

class _DepositToGoalSheetState extends State<DepositToGoalSheet> {
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _handleDeposit() {
    final cents = CurrencyUtils.parseToCents(_amountCtrl.text.trim());
    if (cents <= 0) return;

    HapticFeedback.mediumImpact();
    VaultRepository.instance.depositToGoal(widget.goal.id, cents);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${CurrencyUtils.format(cents, currency: widget.baseCurrency)} to ${widget.goal.name}',
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

    return Padding(
      padding: EdgeInsets.only(
        left: tokens.space5,
        right: tokens.space5,
        top: tokens.space5,
        bottom: MediaQuery.of(context).viewInsets.bottom + tokens.space6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deposit into ${widget.goal.name}',
            style: GoogleFonts.spaceGrotesk(
              color: tokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${CurrencyUtils.format(widget.goal.targetAmountCents, currency: widget.baseCurrency)} • Current: ${CurrencyUtils.format(widget.goal.currentBalanceCents, currency: widget.baseCurrency)}',
            style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
          ),
          SizedBox(height: tokens.space4),

          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Deposit Amount',
              prefixText: '${widget.baseCurrency} ',
            ),
          ),
          SizedBox(height: tokens.space3),

          Wrap(
            spacing: 8,
            children: [50, 100, 250, 500].map((inc) {
              return ActionChip(
                label: Text('+$inc'),
                onPressed: () {
                  final cur = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                  _amountCtrl.text = (cur + inc).toStringAsFixed(0);
                },
              );
            }).toList(),
          ),
          SizedBox(height: tokens.space5),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _handleDeposit,
              style: FilledButton.styleFrom(
                backgroundColor: tokens.statusIncome,
                foregroundColor: tokens.bgPrimary,
              ),
              child: Text('CONFIRM DEPOSIT', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
