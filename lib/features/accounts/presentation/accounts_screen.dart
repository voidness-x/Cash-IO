import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/animated_money_bar.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  AccountType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;
    final currency = repo.baseCurrency;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final allAccounts = repo.accounts;
        final assetAccounts = allAccounts.where((a) => a.type == AccountType.asset).toList();
        final liabilityAccounts = allAccounts.where((a) => a.type == AccountType.liability).toList();
        final incomeAccounts = allAccounts.where((a) => a.type == AccountType.income).toList();
        final expenseAccounts = allAccounts.where((a) => a.type == AccountType.expense).toList();

        final totalAssets = repo.totalAssetsCents;
        final totalLiabilities = repo.totalLiabilitiesCents;
        final netWorth = totalAssets - totalLiabilities;

        return FrostedScaffold(
          appBar: AppBar(
            title: Text(
              'WALLETS',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded),
                tooltip: 'Move Money',
                onPressed: assetAccounts.length >= 2
                    ? () {
                        HapticFeedback.lightImpact();
                        _showTransferSheet(context, assetAccounts, currency);
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Wallet',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddAccountSheet(context, currency);
                },
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(tokens.space4, tokens.space4, tokens.space4, 124),
            children: [
              // 1. Glowing Financial Position Summary Deck
              StaggeredEntrance(
                index: 0,
                child: Container(
                  padding: EdgeInsets.all(tokens.space5),
                  decoration: tokens.heroGlowDecoration(
                    glowColor: netWorth >= 0 ? tokens.accentGold : tokens.statusExpense,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryColumn(
                              'CASH & BANK',
                              CurrencyUtils.format(totalAssets, currency: currency),
                              tokens.statusIncome,
                              tokens.textSecondary,
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          Container(width: 1, height: 42, color: tokens.borderSubtle),
                          Expanded(
                            child: _buildSummaryColumn(
                              'DEBTS',
                              CurrencyUtils.format(totalLiabilities, currency: currency),
                              tokens.statusExpense,
                              tokens.textSecondary,
                              Icons.credit_card_outlined,
                            ),
                          ),
                          Container(width: 1, height: 42, color: tokens.borderSubtle),
                          Expanded(
                            child: _buildSummaryColumn(
                              'NET WORTH',
                              CurrencyUtils.format(netWorth, currency: currency),
                              netWorth >= 0 ? tokens.statusIncome : tokens.statusExpense,
                              tokens.textSecondary,
                              Icons.shield_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: tokens.space4),
                      Divider(color: tokens.borderSubtle, height: 1),
                      SizedBox(height: tokens.space3),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _showAddAccountSheet(context, currency),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Wallet', maxLines: 1, overflow: TextOverflow.ellipsis),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              ),
                            ),
                          ),
                          if (assetAccounts.length >= 2) ...[
                            SizedBox(width: tokens.space2),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showTransferSheet(context, assetAccounts, currency),
                                icon: Icon(Icons.sync_alt_rounded, size: 16, color: tokens.accentGold),
                                label: const Text('Move Money', maxLines: 1, overflow: TextOverflow.ellipsis),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: tokens.accentGold.withValues(alpha: 0.45)),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space4),

              // 2. Interactive Filter Bar (Clean Wallets first, Accounting Categories optional)
              StaggeredEntrance(
                index: 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('My Wallets (${assetAccounts.length + liabilityAccounts.length})', null, tokens),
                      _buildFilterChip('Cash & Bank (${assetAccounts.length})', AccountType.asset, tokens),
                      _buildFilterChip('Debts (${liabilityAccounts.length})', AccountType.liability, tokens),
                      _buildFilterChip('Income (${incomeAccounts.length})', AccountType.income, tokens),
                      _buildFilterChip('Expenses (${expenseAccounts.length})', AccountType.expense, tokens),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space4),

              // 3. Categorized / Grouped Wallets List (Default shows real Wallets + Debts cleanly)
              if (_selectedFilter == null) ...[
                if (assetAccounts.isNotEmpty)
                  _buildAccountSection(
                    title: 'CASH & BANK WALLETS',
                    subtitle: 'Money you own across cash, bank, and cards',
                    accounts: assetAccounts,
                    totalGroupCents: totalAssets,
                    tokens: tokens,
                    startIndex: 2,
                    showPercentage: true,
                    onTransferTap: (acc) => _showTransferSheet(context, assetAccounts, currency, sourceAccount: acc),
                  ),

                if (liabilityAccounts.isNotEmpty)
                  _buildAccountSection(
                    title: 'DEBTS & CREDIT',
                    subtitle: 'Credit cards, loans, and amounts you owe',
                    accounts: liabilityAccounts,
                    totalGroupCents: totalLiabilities,
                    tokens: tokens,
                    startIndex: 2 + assetAccounts.length,
                    showPercentage: false,
                  ),
              ] else ...[
                // Filtered List
                _buildFilteredList(
                  accounts: allAccounts.where((a) => a.type == _selectedFilter).toList(),
                  totalAssets: totalAssets,
                  tokens: tokens,
                  assetAccounts: assetAccounts,
                  currency: currency,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color valueColor, Color labelColor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Icon(icon, size: 16, color: labelColor),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, AccountType? type, CashIOThemeExtension tokens) {
    final isSelected = _selectedFilter == type;
    return Padding(
      padding: EdgeInsets.only(right: tokens.space2),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedFilter = type;
          });
        },
        selectedColor: tokens.statusIncome,
        backgroundColor: tokens.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          side: BorderSide(
            color: isSelected ? tokens.statusIncome : tokens.borderHairline,
          ),
        ),
        labelStyle: GoogleFonts.mukta(
          color: isSelected ? tokens.bgPrimary : tokens.textPrimary,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAccountSection({
    required String title,
    required String subtitle,
    required List<AccountModel> accounts,
    required int totalGroupCents,
    required CashIOThemeExtension tokens,
    required int startIndex,
    required bool showPercentage,
    Function(AccountModel)? onTransferTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.space2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${accounts.length} accounts',
                style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.space2),
        ...accounts.asMap().entries.map((entry) {
          final idx = entry.key;
          final acc = entry.value;
          final pct = (totalGroupCents > 0 && acc.balanceCents > 0)
              ? (acc.balanceCents / totalGroupCents).clamp(0.0, 1.0)
              : 0.0;

          return StaggeredEntrance(
            index: startIndex + idx,
            child: _buildAccountCard(
              account: acc,
              tokens: tokens,
              percentage: showPercentage ? pct : null,
              onTransfer: onTransferTap != null ? () => onTransferTap(acc) : null,
            ),
          );
        }),
        SizedBox(height: tokens.space3),
      ],
    );
  }

  Widget _buildFilteredList({
    required List<AccountModel> accounts,
    required int totalAssets,
    required CashIOThemeExtension tokens,
    required List<AccountModel> assetAccounts,
    required String currency,
  }) {
    if (accounts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(tokens.space8),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(color: tokens.borderHairline),
        ),
        child: Center(
          child: Text(
            'No accounts found in this category.',
            style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      children: accounts.asMap().entries.map((entry) {
        final idx = entry.key;
        final acc = entry.value;
        final pct = (totalAssets > 0 && acc.type == AccountType.asset && acc.balanceCents > 0)
            ? (acc.balanceCents / totalAssets).clamp(0.0, 1.0)
            : null;

        return StaggeredEntrance(
          index: 2 + idx,
          child: _buildAccountCard(
            account: acc,
            tokens: tokens,
            percentage: pct,
            onTransfer: acc.type == AccountType.asset && assetAccounts.length >= 2
                ? () => _showTransferSheet(context, assetAccounts, currency, sourceAccount: acc)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccountCard({
    required AccountModel account,
    required CashIOThemeExtension tokens,
    double? percentage,
    VoidCallback? onTransfer,
  }) {
    final color = _getAccountColor(account.type, tokens);

    return Container(
      margin: EdgeInsets.only(bottom: tokens.space2),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: 2),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(account.icon, color: color, size: 20),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.mukta(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (percentage != null && percentage > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: tokens.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusXs),
                    ),
                    child: Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              account.type.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 105),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyUtils.format(account.balanceCents, currency: account.currency),
                      style: GoogleFonts.jetBrainsMono(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (onTransfer != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.sync_alt_rounded, size: 18, color: tokens.accentGold),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Transfer',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onTransfer();
                    },
                  ),
                ],
              ],
            ),
          ),
          if (percentage != null && percentage > 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space4),
              child: AnimatedMoneyBar(
                value: percentage,
                height: 5,
                fillColor: tokens.statusIncome,
                glow: true,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Color _getAccountColor(AccountType type, CashIOThemeExtension tokens) {
    switch (type) {
      case AccountType.asset:
        return tokens.statusIncome;
      case AccountType.liability:
        return tokens.statusExpense;
      case AccountType.income:
        return tokens.statusIncome;
      case AccountType.expense:
        return tokens.statusExpense;
    }
  }

  // ---------------------------------------------------------------------------
  // Double-Entry Transfer Sheet
  // ---------------------------------------------------------------------------
  void _showTransferSheet(
    BuildContext context,
    List<AccountModel> assetAccounts,
    String baseCurrency, {
    AccountModel? sourceAccount,
  }) {
    if (assetAccounts.length < 2) return;

    final fromAcc = sourceAccount ?? assetAccounts.first;
    AccountModel toAcc = assetAccounts.firstWhere(
      (a) => a.id != fromAcc.id,
      orElse: () => assetAccounts.last,
    );

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        AccountModel currentFrom = fromAcc;
        AccountModel currentTo = toAcc;

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
                        Icon(Icons.swap_horiz_rounded, color: tokens.statusIncome, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'TRANSFER FUNDS',
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
                      'Move balance between air-gapped asset accounts',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: tokens.space4),

                    // From Account Selector
                    Text('FROM ACCOUNT', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<AccountModel>(
                      initialValue: currentFrom,
                      isExpanded: true,
                      dropdownColor: tokens.bgSurfaceElevated,
                      decoration: const InputDecoration(isDense: true),
                      items: assetAccounts.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text(
                            '${a.name} (${CurrencyUtils.format(a.balanceCents, currency: a.currency)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => currentFrom = val);
                        }
                      },
                    ),
                    SizedBox(height: tokens.space3),

                    // To Account Selector
                    Text('TO ACCOUNT', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<AccountModel>(
                      initialValue: currentTo,
                      isExpanded: true,
                      dropdownColor: tokens.bgSurfaceElevated,
                      decoration: const InputDecoration(isDense: true),
                      items: assetAccounts.where((a) => a.id != currentFrom.id).map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text(
                            '${a.name} (${CurrencyUtils.format(a.balanceCents, currency: a.currency)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        labelText: 'Transfer Amount',
                        prefixText: '$baseCurrency ',
                      ),
                    ),
                    SizedBox(height: tokens.space3),

                    // Note
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'e.g. ATM cash withdrawal',
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
                          final note = noteCtrl.text.trim();
                          final desc = note.isNotEmpty
                              ? note
                              : 'Transfer: ${currentFrom.name} -> ${currentTo.name}';

                          // Double-entry transfer:
                          // Debit recipient account (+cents)
                          // Credit source account (-cents)
                          // Sum = (+cents) + (-cents) = 0
                          final success = await VaultRepository.instance.recordTransaction(
                            description: desc,
                            postings: [
                              PostingModel(accountId: currentTo.id, amountCents: cents),
                              PostingModel(accountId: currentFrom.id, amountCents: -cents),
                            ],
                            note: 'Internal Account Transfer',
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Transferred ${CurrencyUtils.format(cents, currency: baseCurrency)} from ${currentFrom.name} to ${currentTo.name}',
                                  ),
                                  backgroundColor: tokens.statusIncome,
                                ),
                              );
                            }
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.statusIncome,
                          foregroundColor: tokens.bgPrimary,
                        ),
                        child: Text(
                          'CONFIRM TRANSFER',
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
  // Add Account Sheet
  // ---------------------------------------------------------------------------
  void _showAddAccountSheet(BuildContext context, String baseCurrency) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    AccountType selectedType = AccountType.asset;
    IconData selectedIcon = Icons.account_balance_wallet_outlined;
    final tokens = context.tokens;

    final icons = [
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_outlined,
      Icons.credit_card_outlined,
      Icons.savings_outlined,
      Icons.attach_money_rounded,
      Icons.shopping_bag_outlined,
      Icons.directions_car_outlined,
      Icons.home_outlined,
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
                      'CREATE NEW ACCOUNT',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add an asset, liability, income, or expense category to the ledger',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: tokens.space4),

                    // Type Segmented Switcher
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: AccountType.values.map((type) {
                          final isSelected = selectedType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(type.name.toUpperCase()),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setSheetState(() => selectedType = type);
                                }
                              },
                              selectedColor: tokens.statusIncome,
                              labelStyle: GoogleFonts.spaceGrotesk(
                                color: isSelected ? tokens.bgPrimary : tokens.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: tokens.space4),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account Name (e.g. Checking, Savings, Dining)',
                      ),
                    ),
                    SizedBox(height: tokens.space3),

                    // Initial Balance
                    if (selectedType == AccountType.asset || selectedType == AccountType.liability) ...[
                      TextField(
                        controller: balanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixText: '$baseCurrency ',
                          labelText: 'Opening Balance (Optional)',
                        ),
                      ),
                      SizedBox(height: tokens.space3),
                    ],

                    // Icon Picker
                    Text('CHOOSE ICON', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
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

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isNotEmpty) {
                            final cents = CurrencyUtils.parseToCents(balanceCtrl.text);
                            VaultRepository.instance.addAccount(
                              name: name,
                              type: selectedType,
                              currency: baseCurrency,
                              initialBalanceCents: cents,
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
                          'CREATE ACCOUNT',
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
