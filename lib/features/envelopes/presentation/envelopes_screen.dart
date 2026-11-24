import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

class EnvelopesScreen extends StatefulWidget {
  const EnvelopesScreen({super.key});

  @override
  State<EnvelopesScreen> createState() => _EnvelopesScreenState();
}

class _EnvelopesScreenState extends State<EnvelopesScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;
    final currency = repo.baseCurrency;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final envelopes = repo.envelopes;
        final availableCents = repo.availableToAssignCents;
        final totalAssigned = envelopes.fold<int>(0, (sum, e) => sum + e.assignedCents);
        final totalSpent = envelopes.fold<int>(0, (sum, e) => sum + e.spentCents);

        return FrostedScaffold(
          appBar: AppBar(
            title: Text(
              'ENVELOPE BUDGETING STUDIO',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              if (envelopes.length >= 2) ...[
                IconButton(
                  icon: const Icon(Icons.sync_alt_rounded),
                  tooltip: 'Move Budget Between Envelopes',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showQuickMoveSheet(context, envelopes, currency);
                  },
                ),
              ],
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'New Envelope',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddEnvelopeSheet(context, currency);
                },
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.all(tokens.space4),
            children: [
              // 1. Available to Assign Command Hero
              StaggeredEntrance(
                index: 0,
                child: Container(
                  padding: EdgeInsets.all(tokens.space5),
                  decoration: BoxDecoration(
                    color: availableCents < 0
                        ? tokens.statusExpense.withValues(alpha: 0.12)
                        : tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(
                      color: availableCents < 0
                          ? tokens.statusExpense
                          : (availableCents > 0
                              ? tokens.statusIncome.withValues(alpha: 0.5)
                              : tokens.borderHairline),
                      width: availableCents > 0 || availableCents < 0 ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: availableCents > 0
                            ? tokens.statusIncome.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: (availableCents < 0
                                      ? tokens.statusExpense
                                      : tokens.statusIncome)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                              border: Border.all(
                                color: (availableCents < 0
                                        ? tokens.statusExpense
                                        : tokens.statusIncome)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(
                              availableCents < 0
                                  ? Icons.warning_amber_rounded
                                  : (availableCents == 0 ? Icons.task_alt : Icons.savings_outlined),
                              color: availableCents < 0 ? tokens.statusExpense : tokens.statusIncome,
                              size: 26,
                            ),
                          ),
                          SizedBox(width: tokens.space4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'AVAILABLE TO ASSIGN',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: tokens.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: availableCents < 0
                                            ? tokens.statusExpense.withValues(alpha: 0.2)
                                            : tokens.statusIncome.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(tokens.radiusXs),
                                      ),
                                      child: Text(
                                        availableCents == 0
                                            ? 'BALANCED'
                                            : (availableCents > 0 ? 'READY' : 'DEFICIT'),
                                        style: GoogleFonts.spaceGrotesk(
                                          color: availableCents < 0 ? tokens.statusExpense : tokens.statusIncome,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyUtils.format(availableCents, currency: currency),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: availableCents < 0 ? tokens.statusExpense : tokens.textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  availableCents == 0
                                      ? 'Zero-based allocation achieved • Every unit has a job'
                                      : (availableCents > 0
                                          ? 'Surplus funds ready to be assigned to envelopes'
                                          : 'Overallocated! Rebalance envelopes to cover deficit'),
                                  style: GoogleFonts.mukta(
                                    color: availableCents < 0 ? tokens.statusExpense : tokens.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space4),

                      // Quick Stats Strip
                      Divider(color: tokens.borderSubtle, height: 1),
                      SizedBox(height: tokens.space3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('TOTAL ASSIGNED', CurrencyUtils.format(totalAssigned, currency: currency), tokens),
                          Container(width: 1, height: 24, color: tokens.borderSubtle),
                          _buildMiniStat('TOTAL SPENT', CurrencyUtils.format(totalSpent, currency: currency), tokens),
                          Container(width: 1, height: 24, color: tokens.borderSubtle),
                          _buildMiniStat('ACTIVE ENVELOPES', '${envelopes.length}', tokens),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space4),

              // 2. Action Strip
              if (envelopes.isNotEmpty) ...[
                StaggeredEntrance(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddEnvelopeSheet(context, currency),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('New Envelope', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.statusIncome,
                            side: BorderSide(color: tokens.statusIncome.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSm)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (envelopes.length >= 2) ...[
                        SizedBox(width: tokens.space3),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showQuickMoveSheet(context, envelopes, currency),
                            icon: const Icon(Icons.sync_alt_rounded, size: 16),
                            label: Text('Move Budget', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.textPrimary,
                              backgroundColor: tokens.bgSurface,
                              side: BorderSide(color: tokens.borderHairline),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSm)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: tokens.space4),
              ],

              // 3. Envelope Cards List
              if (envelopes.isEmpty) ...[
                StaggeredEntrance(
                  index: 1,
                  child: Container(
                    padding: EdgeInsets.all(tokens.space8),
                    decoration: BoxDecoration(
                      color: tokens.bgSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open_outlined, size: 48, color: tokens.textTertiary),
                        SizedBox(height: tokens.space3),
                        Text(
                          'No Budget Envelopes Created',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: tokens.space2),
                        Text(
                          'Create budgeting envelopes like Groceries, Rent, Utilities, or Fuel to allocate your cash intentionally.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                        ),
                        SizedBox(height: tokens.space5),
                        FilledButton.icon(
                          onPressed: () => _showAddEnvelopeSheet(context, currency),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            'Create First Envelope',
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.statusIncome,
                            foregroundColor: tokens.bgPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSm)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...envelopes.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final env = entry.value;
                  return StaggeredEntrance(
                    index: 2 + idx,
                    child: _buildEnvelopeCard(
                      env: env,
                      currency: currency,
                      tokens: tokens,
                      envelopes: envelopes,
                    ),
                  );
                }),
              ],
              SizedBox(height: tokens.space10),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEnvelopeSheet(context, currency),
            backgroundColor: tokens.statusIncome,
            foregroundColor: tokens.bgPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'NEW ENVELOPE',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, CashIOThemeExtension tokens) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: tokens.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: tokens.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEnvelopeCard({
    required EnvelopeModel env,
    required String currency,
    required CashIOThemeExtension tokens,
    required List<EnvelopeModel> envelopes,
  }) {
    final assigned = env.assignedCents;
    final spent = env.spentCents;
    final remaining = env.remainingCents;
    final isOverspent = remaining < 0;
    final progress = assigned > 0 ? (spent / assigned).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: tokens.space3),
      padding: EdgeInsets.all(tokens.space4),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(
          color: isOverspent ? tokens.statusExpense : tokens.borderHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isOverspent ? tokens.statusExpense : tokens.statusIncome)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: (isOverspent ? tokens.statusExpense : tokens.statusIncome)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  env.icon,
                  size: 18,
                  color: isOverspent ? tokens.statusExpense : tokens.statusIncome,
                ),
              ),
              SizedBox(width: tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      env.name,
                      style: GoogleFonts.mukta(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (env.targetCents > 0)
                      Text(
                        'Target: ${CurrencyUtils.format(env.targetCents, currency: currency)} / mo',
                        style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.format(remaining, currency: currency),
                    style: GoogleFonts.jetBrainsMono(
                      color: isOverspent ? tokens.statusExpense : tokens.statusIncome,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isOverspent ? 'OVER BUDGET' : 'LEFT TO SPEND',
                    style: GoogleFonts.spaceGrotesk(
                      color: isOverspent ? tokens.statusExpense : tokens.textTertiary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: tokens.space3),

          // Two-Tone Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: tokens.bgSurfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverspent ? tokens.statusExpense : tokens.statusIncome,
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.space3),

          // Footer Breakdown & Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${CurrencyUtils.format(spent, currency: currency)}  •  Assigned: ${CurrencyUtils.format(assigned, currency: currency)}',
                style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
              ),
              Row(
                children: [
                  if (envelopes.length >= 2 && remaining > 0) ...[
                    InkWell(
                      onTap: () => _showQuickMoveSheet(context, envelopes, currency, fromEnvelope: env),
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.bgSurfaceElevated,
                          border: Border.all(color: tokens.borderHairline),
                          borderRadius: BorderRadius.circular(tokens.radiusPill),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sync_alt_rounded, size: 11, color: tokens.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Move',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  InkWell(
                    onTap: () => _showAssignFundsSheet(context, env, currency),
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: tokens.statusIncome.withValues(alpha: 0.15),
                        border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(tokens.radiusPill),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 12, color: tokens.statusIncome),
                          const SizedBox(width: 4),
                          Text(
                            'Assign',
                            style: GoogleFonts.mukta(
                              color: tokens.statusIncome,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick Move / Reallocate Sheet
  // ---------------------------------------------------------------------------
  void _showQuickMoveSheet(
    BuildContext context,
    List<EnvelopeModel> envelopes,
    String baseCurrency, {
    EnvelopeModel? fromEnvelope,
  }) {
    if (envelopes.length < 2) return;

    final fromEnv = fromEnvelope ?? envelopes.first;
    EnvelopeModel toEnv = envelopes.firstWhere(
      (e) => e.id != fromEnv.id,
      orElse: () => envelopes.last,
    );

    final amountCtrl = TextEditingController();
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        EnvelopeModel currentFrom = fromEnv;
        EnvelopeModel currentTo = toEnv;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: tokens.space5,
                right: tokens.space5,
                top: tokens.space5,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + tokens.space6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sync_alt_rounded, color: tokens.statusIncome, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'MOVE BUDGET ALLOCATION',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reallocate surplus budget from one envelope to another',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: tokens.space4),

                    // From Envelope
                    Text('MOVE FROM', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<EnvelopeModel>(
                      initialValue: currentFrom,
                      dropdownColor: tokens.bgSurfaceElevated,
                      decoration: const InputDecoration(isDense: true),
                      items: envelopes.map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text('${e.name} (${CurrencyUtils.format(e.remainingCents, currency: baseCurrency)} left)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => currentFrom = val);
                        }
                      },
                    ),
                    SizedBox(height: tokens.space3),

                    // To Envelope
                    Text('MOVE TO', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<EnvelopeModel>(
                      initialValue: currentTo,
                      dropdownColor: tokens.bgSurfaceElevated,
                      decoration: const InputDecoration(isDense: true),
                      items: envelopes.where((e) => e.id != currentFrom.id).map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text('${e.name} (${CurrencyUtils.format(e.remainingCents, currency: baseCurrency)} left)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => currentTo = val);
                        }
                      },
                    ),
                    SizedBox(height: tokens.space3),

                    // Amount
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount to Reallocate',
                        prefixText: '$baseCurrency ',
                      ),
                    ),
                    SizedBox(height: tokens.space5),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () async {
                          final cents = CurrencyUtils.parseToCents(amountCtrl.text.trim());
                          if (cents <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an amount greater than zero.')),
                            );
                            return;
                          }

                          HapticFeedback.mediumImpact();
                          await VaultRepository.instance.reallocateBudget(
                            fromEnvelopeId: currentFrom.id,
                            toEnvelopeId: currentTo.id,
                            cents: cents,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Moved ${CurrencyUtils.format(cents, currency: baseCurrency)} from ${currentFrom.name} to ${currentTo.name}',
                                ),
                                backgroundColor: tokens.statusIncome,
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.statusIncome,
                          foregroundColor: tokens.bgPrimary,
                        ),
                        child: Text(
                          'CONFIRM MOVE',
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Assign Funds Sheet
  // ---------------------------------------------------------------------------
  void _showAssignFundsSheet(BuildContext context, EnvelopeModel env, String baseCurrency) {
    final amountCtrl = TextEditingController();
    final tokens = context.tokens;
    final available = VaultRepository.instance.availableToAssignCents;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: tokens.space5,
            right: tokens.space5,
            top: tokens.space5,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + tokens.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Funds to ${env.name}',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Available to assign: ${CurrencyUtils.format(available, currency: baseCurrency)}',
                style: GoogleFonts.mukta(color: tokens.statusIncome, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: tokens.space4),

              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  prefixText: '$baseCurrency ',
                  labelText: 'Amount to Assign',
                ),
              ),
              SizedBox(height: tokens.space3),

              // Quick Chips
              Wrap(
                spacing: 8,
                children: [
                  if (available > 0)
                    ActionChip(
                      label: Text('All Available (${CurrencyUtils.format(available, currency: baseCurrency)})'),
                      onPressed: () {
                        amountCtrl.text = (available / 100.0).toStringAsFixed(2);
                      },
                    ),
                  ActionChip(
                    label: const Text('+50'),
                    onPressed: () => amountCtrl.text = '50',
                  ),
                  ActionChip(
                    label: const Text('+100'),
                    onPressed: () => amountCtrl.text = '100',
                  ),
                  ActionChip(
                    label: const Text('+250'),
                    onPressed: () => amountCtrl.text = '250',
                  ),
                ],
              ),
              SizedBox(height: tokens.space5),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    final cents = CurrencyUtils.parseToCents(amountCtrl.text);
                    if (cents != 0) {
                      HapticFeedback.lightImpact();
                      VaultRepository.instance.assignToEnvelope(env.id, cents);
                      Navigator.pop(ctx);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.statusIncome,
                    foregroundColor: tokens.bgPrimary,
                  ),
                  child: Text('CONFIRM ASSIGNMENT', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Add Envelope Sheet
  // ---------------------------------------------------------------------------
  void _showAddEnvelopeSheet(BuildContext context, String baseCurrency) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    IconData selectedIcon = Icons.folder_outlined;
    final tokens = context.tokens;

    final icons = [
      Icons.folder_outlined,
      Icons.shopping_bag_outlined,
      Icons.restaurant_outlined,
      Icons.home_outlined,
      Icons.directions_car_outlined,
      Icons.local_hospital_outlined,
      Icons.flight_outlined,
      Icons.sports_esports_outlined,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: tokens.space5,
                right: tokens.space5,
                top: tokens.space5,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + tokens.space6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CREATE NEW BUDGET ENVELOPE',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Give your cash a clear target for spending or saving',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: tokens.space4),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Envelope Name (e.g. Groceries, Rent, Vacation)',
                      ),
                    ),
                    SizedBox(height: tokens.space3),

                    TextField(
                      controller: targetCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '$baseCurrency ',
                        labelText: 'Monthly Target (Optional)',
                      ),
                    ),
                    SizedBox(height: tokens.space3),

                    Text('CHOOSE ICON', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: icons.map((icon) {
                        final isSel = selectedIcon == icon;
                        return InkWell(
                          onTap: () => setSheetState(() => selectedIcon = icon),
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.all(10),
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
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final target = CurrencyUtils.parseToCents(targetCtrl.text);
                          if (name.isNotEmpty) {
                            VaultRepository.instance.addEnvelope(
                              name: name,
                              targetCents: target,
                              icon: selectedIcon,
                            );
                            Navigator.pop(ctx);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.statusIncome,
                          foregroundColor: tokens.bgPrimary,
                        ),
                        child: Text(
                          'CREATE ENVELOPE',
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
