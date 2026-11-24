import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

/// Modal sheet for managing recurring bills, subscriptions, and scheduled double-entry postings
class RecurringBillsSheet extends StatefulWidget {
  final String baseCurrency;

  const RecurringBillsSheet({super.key, required this.baseCurrency});

  @override
  State<RecurringBillsSheet> createState() => _RecurringBillsSheetState();
}

class _RecurringBillsSheetState extends State<RecurringBillsSheet> {
  bool _isCreatingNew = false;
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  RecurringInterval _selectedInterval = RecurringInterval.monthly;
  String? _selectedSourceId;
  String? _selectedDestId;

  @override
  void initState() {
    super.initState();
    final repo = VaultRepository.instance;
    final assets = repo.accounts.where((a) => a.type == AccountType.asset).toList();
    final expenses = repo.accounts.where((a) => a.type == AccountType.expense).toList();
    if (assets.isNotEmpty) _selectedSourceId = assets.first.id;
    if (expenses.isNotEmpty) _selectedDestId = expenses.first.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePostDue(RecurringTransactionModel item) async {
    HapticFeedback.mediumImpact();
    final success = await VaultRepository.instance.postDueRecurringTransaction(item.id);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Posted "${item.title}" (${CurrencyUtils.format(item.amountCents, currency: widget.baseCurrency)}) to double-entry ledger.',
            style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.tokens.statusIncome,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleCreate() async {
    final title = _titleCtrl.text.trim();
    final cents = CurrencyUtils.parseToCents(_amountCtrl.text.trim());
    if (title.isEmpty || cents <= 0 || _selectedSourceId == null || _selectedDestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields with a valid amount.')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    await VaultRepository.instance.addRecurringTransaction(
      title: title,
      amountCents: cents,
      sourceAccountId: _selectedSourceId!,
      destinationAccountId: _selectedDestId!,
      interval: _selectedInterval,
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
      isExpense: true,
      icon: Icons.receipt_long,
    );

    setState(() {
      _isCreatingNew = false;
      _titleCtrl.clear();
      _amountCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final recurringList = repo.recurringTransactions;
    final assets = repo.accounts.where((a) => a.type == AccountType.asset).toList();
    final expenses = repo.accounts.where((a) => a.type == AccountType.expense).toList();

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
            // Header Bar
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(tokens.space2),
                  decoration: BoxDecoration(
                    color: tokens.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.repeat_rounded, color: tokens.accentGold, size: 24),
                ),
                SizedBox(width: tokens.space3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECURRING BILLS & SUBSCRIPTIONS',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Automated & scheduled double-entry postings',
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

            if (!_isCreatingNew) ...[
              if (recurringList.isEmpty) ...[
                Container(
                  padding: EdgeInsets.all(tokens.space6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.bgSurfaceElevated,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 36, color: tokens.textTertiary),
                      const SizedBox(height: 8),
                      Text(
                        'No recurring schedules configured',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track recurring memberships, bills, rent, or salaries with automatic double-entry logging.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...recurringList.map((item) {
                  final isDue = item.isDue;
                  return Container(
                    margin: EdgeInsets.only(bottom: tokens.space3),
                    padding: EdgeInsets.all(tokens.space4),
                    decoration: BoxDecoration(
                      color: tokens.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      border: Border.all(
                        color: isDue ? tokens.accentGold.withValues(alpha: 0.6) : tokens.borderHairline,
                        width: isDue ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.bgSurface,
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                            border: Border.all(color: tokens.borderHairline),
                          ),
                          child: Icon(item.icon, size: 20, color: tokens.accentGold),
                        ),
                        SizedBox(width: tokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.title,
                                    style: GoogleFonts.mukta(
                                      color: tokens.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isDue
                                          ? tokens.statusIncome.withValues(alpha: 0.15)
                                          : tokens.bgSurface,
                                      borderRadius: BorderRadius.circular(tokens.radiusXs),
                                      border: Border.all(
                                        color: isDue ? tokens.statusIncome.withValues(alpha: 0.4) : tokens.borderHairline,
                                      ),
                                    ),
                                    child: Text(
                                      item.interval.name.toUpperCase(),
                                      style: GoogleFonts.spaceGrotesk(
                                        color: isDue ? tokens.statusIncome : tokens.textTertiary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Due: ${item.nextDueDate.month}/${item.nextDueDate.day}/${item.nextDueDate.year}',
                                style: GoogleFonts.mukta(
                                  color: isDue ? tokens.accentChampagne : tokens.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyUtils.format(item.amountCents, currency: widget.baseCurrency),
                              style: GoogleFonts.jetBrainsMono(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _handlePostDue(item),
                                  borderRadius: BorderRadius.circular(tokens.radiusPill),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tokens.statusIncome.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                                      border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.bolt, size: 12, color: tokens.statusIncome),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Post Now',
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
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 16, color: tokens.textTertiary),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    repo.removeRecurringTransaction(item.id);
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              SizedBox(height: tokens.space4),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isCreatingNew = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    '+ NEW RECURRING BILL',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.accentGold,
                    side: BorderSide(color: tokens.accentGold.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusMd)),
                  ),
                ),
              ),
            ] else ...[
              // Create New Form
              Text(
                'NEW RECURRING SCHEDULE',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.accentGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: tokens.space3),

              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subscription / Bill Title',
                  hintText: 'e.g. Netflix, Gym, Internet, Rent',
                  prefixIcon: Icon(Icons.label_outline, size: 20),
                ),
              ),
              SizedBox(height: tokens.space3),

              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Recurring Amount',
                  prefixText: '${widget.baseCurrency} ',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                ),
              ),
              SizedBox(height: tokens.space3),

              // Frequency
              Text('FREQUENCY', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: RecurringInterval.values.map((interval) {
                    final isSel = _selectedInterval == interval;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(interval.name.toUpperCase()),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) setState(() => _selectedInterval = interval);
                        },
                        selectedColor: tokens.accentGold,
                        labelStyle: GoogleFonts.spaceGrotesk(
                          color: isSel ? tokens.bgPrimary : tokens.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: tokens.space3),

              // Source Asset Account
              if (assets.isNotEmpty) ...[
                Text('PAY FROM ACCOUNT', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceId,
                  dropdownColor: tokens.bgSurfaceElevated,
                  decoration: const InputDecoration(isDense: true),
                  items: assets.map((a) {
                    return DropdownMenuItem(value: a.id, child: Text(a.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSourceId = val),
                ),
                SizedBox(height: tokens.space3),
              ],

              // Destination Expense Category
              if (expenses.isNotEmpty) ...[
                Text('EXPENSE CATEGORY', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDestId,
                  dropdownColor: tokens.bgSurfaceElevated,
                  decoration: const InputDecoration(isDense: true),
                  items: expenses.map((e) {
                    return DropdownMenuItem(value: e.id, child: Text(e.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDestId = val),
                ),
                SizedBox(height: tokens.space4),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isCreatingNew = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: tokens.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: _handleCreate,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.statusIncome,
                        foregroundColor: tokens.bgPrimary,
                      ),
                      child: const Text('Save Schedule'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
