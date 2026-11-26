import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

/// User-friendly bottom sheet to quickly add cash / income into the vault
class AddCashSheet extends StatefulWidget {
  final String baseCurrency;

  const AddCashSheet({super.key, required this.baseCurrency});

  @override
  State<AddCashSheet> createState() => _AddCashSheetState();
}

class _AddCashSheetState extends State<AddCashSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedSource = 'Salary';
  String? _selectedAssetAccountId;

  final List<String> _sources = [
    'Salary',
    'Side Gig',
    'Business',
    'Gift',
    'Investment',
    'Transfer',
    'Other',
  ];

  List<int> get _quickIncrements =>
      widget.baseCurrency == 'IQD' ? const [5000, 10000, 25000, 50000, 100000] : const [10, 50, 100, 500, 1000];

  String _formatChip(int inc) => inc >= 1000 ? '+${(inc / 1000).toStringAsFixed(0)}K' : '+$inc';

  @override
  void initState() {
    super.initState();
    final repo = VaultRepository.instance;
    final assetAccounts = repo.accounts.where((a) => a.type == AccountType.asset).toList();
    if (assetAccounts.isNotEmpty) {
      _selectedAssetAccountId = assetAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int amount) {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_amountController.text.trim()) ?? 0;
    final updated = current + amount;
    _amountController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
  }

  Future<void> _handleDeposit() async {
    try {
      final rawText = _amountController.text.trim();
      final cents = CurrencyUtils.parseToCents(rawText);
      if (cents <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid cash amount greater than zero.')),
        );
        return;
      }

      HapticFeedback.mediumImpact();
      final repo = VaultRepository.instance;

      // Ensure we have an asset account target
      AccountModel? targetAsset;
      final assetAccounts = repo.accounts.where((a) => a.type == AccountType.asset).toList();
      if (_selectedAssetAccountId != null) {
        targetAsset = assetAccounts.where((a) => a.id == _selectedAssetAccountId).firstOrNull;
      }
      if (targetAsset == null) {
        if (assetAccounts.isNotEmpty) {
          targetAsset = assetAccounts.first;
        } else {
          // Auto-create default Cash Wallet
          await repo.addAccount(
            name: 'Cash Wallet',
            type: AccountType.asset,
            currency: widget.baseCurrency,
            initialBalanceCents: 0,
            icon: Icons.wallet_outlined,
          );
          targetAsset = repo.accounts.where((a) => a.type == AccountType.asset).first;
        }
      }

      // Ensure we have a corresponding Income account
      final incomeCategoryName = 'Income: $_selectedSource';
      AccountModel? incomeAcc = repo.accounts.where((a) => a.type == AccountType.income && a.name == incomeCategoryName).firstOrNull;
      if (incomeAcc == null) {
        await repo.addAccount(
          name: incomeCategoryName,
          type: AccountType.income,
          currency: widget.baseCurrency,
          icon: Icons.attach_money_rounded,
        );
        incomeAcc = repo.accounts.where((a) => a.type == AccountType.income && a.name == incomeCategoryName).first;
      }

      // Double-entry postings:
      // Debit Asset account (+cents)
      // Credit Income account (-cents)
      // Sum = (+cents) + (-cents) = 0
      final note = _noteController.text.trim();
      final description = note.isNotEmpty ? note : 'Deposit: $_selectedSource';

      final success = await repo.recordTransaction(
        description: description,
        postings: [
          PostingModel(accountId: targetAsset.id, amountCents: cents),
          PostingModel(accountId: incomeAcc.id, amountCents: -cents),
        ],
        note: 'Source: $_selectedSource',
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully added +${CurrencyUtils.format(cents, currency: widget.baseCurrency)} to ${targetAsset.name}',
                style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
              ),
              backgroundColor: context.tokens.statusIncome,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to record transaction. Please verify accounts.')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _handleDeposit: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding cash: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final assetAccounts = repo.accounts.where((a) => a.type == AccountType.asset).toList();

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
            // Header bar
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(tokens.space2),
                  decoration: BoxDecoration(
                    color: tokens.statusIncome.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.add_rounded, color: tokens.statusIncome, size: 24),
                ),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADD CASH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Deposit funds into your air-gapped vault',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.mukta(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: tokens.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: tokens.space4),

            // Amount Input
            Container(
              padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space2),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    widget.baseCurrency,
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.statusIncome,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: tokens.space3),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.jetBrainsMono(
                          color: tokens.textTertiary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.space3),

            // Quick Amount Buttons
            Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: _quickIncrements.map((inc) {
                return InkWell(
                  onTap: () => _addQuickAmount(inc),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: tokens.space3, vertical: tokens.space1),
                    decoration: BoxDecoration(
                      color: tokens.bgSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Text(
                      _formatChip(inc),
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.accentGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space4),

            // Deposit To Account (if multiple asset accounts)
            if (assetAccounts.length > 1) ...[
              Text(
                'DEPOSIT TO ACCOUNT',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: tokens.space2),
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: assetAccounts.map((acc) {
                  final isSelected = acc.id == _selectedAssetAccountId;
                  return ChoiceChip(
                    label: Text(acc.name),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedAssetAccountId = acc.id);
                      }
                    },
                    selectedColor: tokens.statusIncome.withValues(alpha: 0.2),
                    backgroundColor: tokens.bgSurface,
                    labelStyle: GoogleFonts.mukta(
                      color: isSelected ? tokens.statusIncome : tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected ? tokens.statusIncome : tokens.borderHairline,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: tokens.space4),
            ],

            // Income Source Chips
            Text(
              'INCOME SOURCE',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: tokens.space2),
            Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: _sources.map((src) {
                final isSelected = src == _selectedSource;
                return ChoiceChip(
                  label: Text(src),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedSource = src);
                    }
                  },
                  selectedColor: tokens.statusIncome.withValues(alpha: 0.25),
                  backgroundColor: tokens.bgSurface,
                  labelStyle: GoogleFonts.mukta(
                    color: isSelected ? tokens.statusIncome : tokens.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? tokens.statusIncome : tokens.borderHairline,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space4),

            // Note Field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note / Memo (Optional)',
                hintText: 'e.g. November paycheck, project milestone',
                prefixIcon: const Icon(Icons.edit_note, size: 20),
                fillColor: tokens.bgSurface,
              ),
            ),
            SizedBox(height: tokens.space5),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _handleDeposit,
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                label: Text(
                  'CONFIRM DEPOSIT',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.statusIncome,
                  foregroundColor: tokens.bgPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User-friendly bottom sheet to quickly spend / remove cash from the vault
class SpendCashSheet extends StatefulWidget {
  final String baseCurrency;

  const SpendCashSheet({super.key, required this.baseCurrency});

  @override
  State<SpendCashSheet> createState() => _SpendCashSheetState();
}

class _SpendCashSheetState extends State<SpendCashSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'Food & Dining';
  String? _selectedAssetAccountId;
  String? _selectedBudgetId;

  final List<String> _categories = [
    'Food & Dining',
    'Groceries',
    'Transport',
    'Shopping',
    'Bills & Utilities',
    'Entertainment',
    'Health',
    'Personal Care',
    'General Expenses',
  ];

  List<int> get _quickIncrements =>
      widget.baseCurrency == 'IQD' ? const [2000, 5000, 10000, 25000, 50000] : const [5, 10, 20, 50, 100];

  String _formatSpendChip(int inc) => inc >= 1000 ? '+${(inc / 1000).toStringAsFixed(0)}K' : '+$inc';

  @override
  void initState() {
    super.initState();
    final repo = VaultRepository.instance;
    final assetAccounts = repo.accounts.where((a) => a.type == AccountType.asset).toList();
    if (assetAccounts.isNotEmpty) {
      _selectedAssetAccountId = assetAccounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int amount) {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_amountController.text.trim()) ?? 0;
    final updated = current + amount;
    _amountController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
    _amountController.selection = TextSelection.fromPosition(
      TextPosition(offset: _amountController.text.length),
    );
  }

  Future<void> _handleExpense() async {
    try {
      final rawText = _amountController.text.trim();
      final cents = CurrencyUtils.parseToCents(rawText);
      if (cents <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid expense amount greater than zero.')),
        );
        return;
      }

      HapticFeedback.mediumImpact();
      final repo = VaultRepository.instance;

      // Ensure we have an asset account to pay from
      AccountModel? sourceAsset;
      final assetAccounts = repo.accounts.where((a) => a.type == AccountType.asset).toList();
      if (_selectedAssetAccountId != null) {
        sourceAsset = assetAccounts.where((a) => a.id == _selectedAssetAccountId).firstOrNull;
      }
      if (sourceAsset == null) {
        if (assetAccounts.isNotEmpty) {
          sourceAsset = assetAccounts.first;
        } else {
          await repo.addAccount(
            name: 'Cash Wallet',
            type: AccountType.asset,
            currency: widget.baseCurrency,
            initialBalanceCents: 0,
            icon: Icons.wallet_outlined,
          );
          sourceAsset = repo.accounts.where((a) => a.type == AccountType.asset).first;
        }
      }

      // Ensure we have a corresponding Expense account
      final expenseCategoryName = 'Expenses: $_selectedCategory';
      AccountModel? expenseAcc = repo.accounts.where((a) => a.type == AccountType.expense && a.name == expenseCategoryName).firstOrNull;
      if (expenseAcc == null) {
        await repo.addAccount(
          name: expenseCategoryName,
          type: AccountType.expense,
          currency: widget.baseCurrency,
          icon: Icons.shopping_bag_outlined,
        );
        expenseAcc = repo.accounts.where((a) => a.type == AccountType.expense && a.name == expenseCategoryName).first;
      }

      // Double-entry postings:
      // Debit Expense account (+cents)
      // Credit Asset account (-cents)
      // Sum = (+cents) + (-cents) = 0
      final note = _noteController.text.trim();
      final description = note.isNotEmpty ? note : 'Spent: $_selectedCategory';

      final success = await repo.recordTransaction(
        description: description,
        postings: [
          PostingModel(accountId: expenseAcc.id, amountCents: cents),
          PostingModel(accountId: sourceAsset.id, amountCents: -cents),
        ],
        note: 'Category: $_selectedCategory',
      );

      if (success && _selectedBudgetId != null) {
        await repo.recordEnvelopeSpend(_selectedBudgetId!, cents);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Recorded -${CurrencyUtils.format(cents, currency: widget.baseCurrency)} from ${sourceAsset.name}',
                style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
              ),
              backgroundColor: context.tokens.statusExpense,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to record expense. Please verify accounts.')),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _handleExpense: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final assetAccounts = repo.accounts.where((a) => a.type == AccountType.asset).toList();

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
            // Header bar
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(tokens.space2),
                  decoration: BoxDecoration(
                    color: tokens.statusExpense.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.remove_rounded, color: tokens.statusExpense, size: 24),
                ),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SPEND CASH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Record an expense or payment from your vault',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.mukta(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: tokens.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: tokens.space4),

            // Amount Input
            Container(
              padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space2),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.statusExpense.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    widget.baseCurrency,
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.statusExpense,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: tokens.space3),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: GoogleFonts.jetBrainsMono(
                          color: tokens.textTertiary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.space3),

            // Quick Amount Buttons
            Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: _quickIncrements.map((inc) {
                return InkWell(
                  onTap: () => _addQuickAmount(inc),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: tokens.space3, vertical: tokens.space1),
                    decoration: BoxDecoration(
                      color: tokens.bgSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Text(
                      _formatSpendChip(inc),
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.statusExpense,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space4),

            // Pay From Wallet Selector
            Text(
              'PAY FROM WALLET',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: tokens.space2),
            Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: assetAccounts.map((acc) {
                final isSelected = acc.id == _selectedAssetAccountId;
                return ChoiceChip(
                  label: Text('${acc.name} (${CurrencyUtils.format(acc.balanceCents, currency: acc.currency)})'),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedAssetAccountId = acc.id);
                    }
                  },
                  selectedColor: tokens.statusExpense.withValues(alpha: 0.2),
                  backgroundColor: tokens.bgSurface,
                  labelStyle: GoogleFonts.mukta(
                    color: isSelected ? tokens.statusExpense : tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected ? tokens.statusExpense : tokens.borderHairline,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space4),

            // Expense Category Chips
            Text(
              'EXPENSE CATEGORY',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: tokens.space2),
            Wrap(
              spacing: tokens.space2,
              runSpacing: tokens.space2,
              children: _categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                  selectedColor: tokens.statusExpense.withValues(alpha: 0.25),
                  backgroundColor: tokens.bgSurface,
                  labelStyle: GoogleFonts.mukta(
                    color: isSelected ? tokens.statusExpense : tokens.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? tokens.statusExpense : tokens.borderHairline,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: tokens.space4),

            // Optional Monthly Budget Link (Updates Budget progress bars automatically)
            if (repo.envelopes.isNotEmpty) ...[
              Text(
                'COUNT TOWARD MONTHLY BUDGET (OPTIONAL)',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: tokens.space2),
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: [
                  ChoiceChip(
                    label: const Text('None'),
                    selected: _selectedBudgetId == null,
                    onSelected: (_) => setState(() => _selectedBudgetId = null),
                    selectedColor: tokens.accentGoldBg,
                    backgroundColor: tokens.bgSurface,
                    labelStyle: GoogleFonts.mukta(
                      color: _selectedBudgetId == null ? tokens.accentGold : tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: _selectedBudgetId == null ? tokens.accentGold : tokens.borderHairline,
                    ),
                  ),
                  ...repo.envelopes.map((env) {
                    final isSelected = _selectedBudgetId == env.id;
                    return ChoiceChip(
                      label: Text(env.name),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedBudgetId = val ? env.id : null),
                      selectedColor: tokens.accentGoldBg,
                      backgroundColor: tokens.bgSurface,
                      labelStyle: GoogleFonts.mukta(
                        color: isSelected ? tokens.accentGold : tokens.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected ? tokens.accentGold : tokens.borderHairline,
                      ),
                    );
                  }),
                ],
              ),
              SizedBox(height: tokens.space4),
            ],

            // Note Field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note / What did you buy?',
                hintText: 'e.g. Lunch with team, monthly electricity',
                prefixIcon: const Icon(Icons.edit_note, size: 20),
                fillColor: tokens.bgSurface,
              ),
            ),
            SizedBox(height: tokens.space5),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _handleExpense,
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                label: Text(
                  'CONFIRM SPEND',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: tokens.statusExpense,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Intuitive 1-screen sheet to move money between wallets (e.g. Bank -> Cash Wallet).
class MoveMoneySheet extends StatefulWidget {
  final String baseCurrency;
  final String? initialFromId;

  const MoveMoneySheet({
    super.key,
    required this.baseCurrency,
    this.initialFromId,
  });

  @override
  State<MoveMoneySheet> createState() => _MoveMoneySheetState();
}

class _MoveMoneySheetState extends State<MoveMoneySheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _fromWalletId;
  String? _toWalletId;

  List<int> get _quickIncrements =>
      widget.baseCurrency == 'IQD' ? const [10000, 25000, 50000, 100000] : const [20, 50, 100, 500];

  @override
  void initState() {
    super.initState();
    final wallets = VaultRepository.instance.accounts
        .where((a) => a.type == AccountType.asset)
        .toList();
    if (wallets.isNotEmpty) {
      _fromWalletId = widget.initialFromId ?? wallets.first.id;
      final other = wallets.where((w) => w.id != _fromWalletId).firstOrNull;
      _toWalletId = other?.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(int amount) {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_amountController.text.trim()) ?? 0;
    final updated = current + amount;
    _amountController.text = updated % 1 == 0 ? updated.toInt().toString() : updated.toStringAsFixed(2);
  }

  Future<void> _handleMove() async {
    final cents = CurrencyUtils.parseToCents(_amountController.text.trim());
    if (cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }

    final repo = VaultRepository.instance;
    final wallets = repo.accounts.where((a) => a.type == AccountType.asset).toList();
    final fromWallet = wallets.where((w) => w.id == _fromWalletId).firstOrNull;
    final toWallet = wallets.where((w) => w.id == _toWalletId).firstOrNull;

    if (fromWallet == null || toWallet == null || fromWallet.id == toWallet.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick two different wallets to move money between.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final note = _noteController.text.trim();
    final desc = note.isNotEmpty ? note : 'Moved: ${fromWallet.name} -> ${toWallet.name}';

    final success = await repo.recordTransaction(
      description: desc,
      postings: [
        PostingModel(accountId: toWallet.id, amountCents: cents),
        PostingModel(accountId: fromWallet.id, amountCents: -cents),
      ],
      note: 'Wallet Transfer',
    );

    if (mounted && success) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Moved ${CurrencyUtils.format(cents, currency: widget.baseCurrency)} from ${fromWallet.name} to ${toWallet.name}',
            style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.tokens.statusIncome,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final wallets = VaultRepository.instance.accounts
        .where((a) => a.type == AccountType.asset)
        .toList();

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
                    color: tokens.accentGoldBg,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.swap_horiz_rounded, color: tokens.accentGold, size: 22),
                ),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MOVE MONEY',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        'Transfer cash cleanly between your wallets',
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: tokens.textSecondary, size: 20),
                  onPressed: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                ),
              ],
            ),
            SizedBox(height: tokens.space4),

            if (wallets.length < 2) ...[
              Container(
                padding: EdgeInsets.all(tokens.space4),
                decoration: BoxDecoration(
                  color: tokens.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Text(
                  'Add a second wallet (like Bank Account or Savings) in the Wallets tab to move money between them.',
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                ),
              ),
            ] else ...[
              // Amount Box
              Container(
                padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space2),
                decoration: BoxDecoration(
                  color: tokens.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  border: Border.all(color: tokens.accentGold.withValues(alpha: 0.45), width: 1.5),
                ),
                child: Row(
                  children: [
                    Text(
                      widget.baseCurrency,
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.accentGold,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: tokens.space3),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.jetBrainsMono(
                          color: tokens.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: GoogleFonts.jetBrainsMono(
                            color: tokens.textTertiary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space3),
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: _quickIncrements.map((inc) {
                  final label = inc >= 1000 ? '+${(inc / 1000).toStringAsFixed(0)}K' : '+$inc';
                  return InkWell(
                    onTap: () => _addQuickAmount(inc),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: tokens.space3, vertical: tokens.space1),
                      decoration: BoxDecoration(
                        color: tokens.bgSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          color: tokens.accentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: tokens.space4),

              Text(
                'FROM WALLET',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: tokens.space2),
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: wallets.map((w) {
                  final isSelected = w.id == _fromWalletId;
                  return ChoiceChip(
                    label: Text('${w.name} (${CurrencyUtils.format(w.balanceCents, currency: w.currency)})'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _fromWalletId = w.id;
                          if (_toWalletId == w.id) {
                            _toWalletId = wallets.firstWhere((other) => other.id != w.id).id;
                          }
                        });
                      }
                    },
                    selectedColor: tokens.accentGoldBg,
                    backgroundColor: tokens.bgSurface,
                    labelStyle: GoogleFonts.mukta(
                      color: isSelected ? tokens.accentGold : tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: isSelected ? tokens.accentGold : tokens.borderHairline),
                  );
                }).toList(),
              ),
              SizedBox(height: tokens.space4),

              Text(
                'TO WALLET',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: tokens.space2),
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: wallets.where((w) => w.id != _fromWalletId).map((w) {
                  final isSelected = w.id == _toWalletId;
                  return ChoiceChip(
                    label: Text('${w.name} (${CurrencyUtils.format(w.balanceCents, currency: w.currency)})'),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _toWalletId = w.id);
                    },
                    selectedColor: tokens.statusIncomeBg,
                    backgroundColor: tokens.bgSurface,
                    labelStyle: GoogleFonts.mukta(
                      color: isSelected ? tokens.statusIncome : tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: isSelected ? tokens.statusIncome : tokens.borderHairline),
                  );
                }).toList(),
              ),
              SizedBox(height: tokens.space4),

              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'e.g. ATM withdrawal, moving to savings',
                  prefixIcon: const Icon(Icons.edit_note, size: 20),
                  fillColor: tokens.bgSurface,
                ),
              ),
              SizedBox(height: tokens.space5),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _handleMove,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  label: Text(
                    'CONFIRM MOVE',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
