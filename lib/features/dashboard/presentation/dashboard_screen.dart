import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../transactions/presentation/record_transaction_sheet.dart';
import '../../receipts/presentation/receipt_viewer_dialog.dart';
import '../../../core/widgets/cashio_logo.dart';
import '../../../core/widgets/animated_money_bar.dart';
import 'cash_action_sheets.dart';
import '../../analytics/presentation/category_spending_donut_card.dart';
import '../../subscriptions/presentation/recurring_bills_sheet.dart';
import '../../fx/presentation/fx_converter_sheet.dart';
import '../../advisory/presentation/financial_advisory_card.dart';
import '../../savings/presentation/savings_goals_deck.dart';
import '../../savings/presentation/savings_goal_sheets.dart';
import '../../profile_setup/presentation/quick_financial_setup_sheet.dart';
import '../../../core/services/ledger_search_service.dart';
import '../../../core/services/update_receiver_service.dart';
import '../../transactions/presentation/ledger_search_filter_bar.dart';
import '../../receipts/presentation/receipt_vault_gallery.dart';
import '../../settings/presentation/update_receiver_sheet.dart';
import '../../vaults/presentation/vault_switcher_sheet.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSwitchProfile;

  const DashboardScreen({super.key, this.onSwitchProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;

  LedgerFilterCriteria _ledgerCriteria = const LedgerFilterCriteria();
  bool _isSearchExpanded = false;
  bool _promptedUpdateDialogThisSession = false;
  bool _dismissedQuickSetupCard = false;

  // Clean segmented focus tab to avoid stacking 5 heavy analytics widgets at once:
  // 0: Insights & 30d Flow, 1: Savings Vaults, 2: Spending Breakdown
  int _selectedFocusTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptGitHubRelease();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndPromptGitHubRelease();
    }
  }

  Future<void> _checkAndPromptGitHubRelease() async {
    final update = await UpdateReceiverService.instance.checkForUpdatesOnStartupOrResume();
    if (!mounted || update == null || _promptedUpdateDialogThisSession) return;
    _promptedUpdateDialogThisSession = true;
    _openOtaUpdateSheet(context);
  }

  void _openOtaUpdateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const UpdateReceiverSheet(),
    );
  }

  void _openQuickFinancialSetup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const QuickFinancialSetupSheet(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final otaService = UpdateReceiverService.instance;
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: Listenable.merge([repo, otaService]),
      builder: (context, _) {
        final transactions = repo.transactions;
        final currency = repo.baseCurrency;
        final netWorth = repo.netWorthCents;
        final income30d = repo.last30DaysIncomeCents;
        final expense30d = repo.last30DaysExpenseCents;
        final showQuickSetupPrompt =
            !_dismissedQuickSetupCard && transactions.isEmpty && repo.totalAssetsCents == 0;

        return FrostedScaffold(
          appBar: AppBar(
            titleSpacing: tokens.space4,
            title: Row(
              children: [
                const CashIOLogo(
                  fontSize: 18,
                  animateO: true,
                  showSubtitle: false,
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: tokens.borderHairline),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => const VaultSwitcherSheet(),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              repo.profileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_down_rounded, color: tokens.textSecondary, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.system_update_alt_rounded,
                      size: 21,
                      color: otaService.availableUpdate != null ? tokens.accent : tokens.textSecondary,
                    ),
                    if (otaService.availableUpdate != null)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                tooltip: 'Updates & Rollback',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _openOtaUpdateSheet(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.layers_outlined, size: 21),
                tooltip: 'Switch Vault',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const VaultSwitcherSheet(),
                  );
                },
              ),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: ListView(
              padding: EdgeInsets.fromLTRB(tokens.space4, tokens.space2, tokens.space4, 124),
              children: [
                // 0A. LIVE GITHUB RELEASE UPDATE BANNER
                if (otaService.hasUnreadUpdateBanner && otaService.availableUpdate != null) ...[
                  Container(
                    padding: EdgeInsets.all(tokens.space3),
                    decoration: BoxDecoration(
                      color: tokens.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      border: Border.all(color: tokens.accent.withValues(alpha: 0.45)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.system_update_rounded, color: tokens.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'NEW UPDATE • v${otaService.availableUpdate!.version}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  color: tokens.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                otaService.availableUpdate!.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.mukta(
                                  color: tokens.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openOtaUpdateSheet(context),
                          child: Text(
                            'Update',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16, color: tokens.textTertiary),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Dismiss update banner',
                          onPressed: otaService.dismissUpdateBanner,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.space3),
                ],

                // 0B. GUIDED STARTING CASH CARD (For fresh or newly updated 0-balance vaults)
                if (showQuickSetupPrompt) ...[
                  Container(
                    padding: EdgeInsets.all(tokens.space4),
                    decoration: BoxDecoration(
                      color: tokens.bgSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_outlined, color: tokens.accent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Quick Start: Add Your Starting Cash',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  color: tokens.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 16, color: tokens.textTertiary),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Dismiss quick start',
                              onPressed: () => setState(() => _dismissedQuickSetupCard = true),
                            ),
                          ],
                        ),
                        Text(
                          'Set your current wallet cash, bank balance, and starter envelopes in one step.',
                          style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                        ),
                        SizedBox(height: tokens.space3),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _openQuickFinancialSetup(context),
                            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                            label: const Text('Set Starting Cash & Budgets'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.space4),
                ],

                // 1. HERO TOTAL MONEY CARD (Glowing, Breathable, Cashew-Clean)
                _buildCurrentCashDeck(
                  tokens: tokens,
                  currentCashCents: repo.totalAssetsCents,
                  netWorthCents: netWorth,
                  currency: currency,
                  totalLiabilitiesCents: repo.totalLiabilitiesCents,
                  onAddCash: () => _openAddCashSheet(context, currency),
                  onSpendCash: () => _openSpendCashSheet(context, currency),
                  onMoveCash: () => _openMoveMoneySheet(context, currency),
                  onOpenRecurring: () => _openRecurringBillsSheet(context, currency),
                  onOpenFx: () => _openFxConverterSheet(context, currency),
                ),
                SizedBox(height: tokens.space3),

                // 2. CASHEW-STYLE SIDE-BY-SIDE 30-DAY INCOME & SPENT CARDS
                _buildCashewFlowCards(
                  tokens: tokens,
                  incomeCents: income30d,
                  expenseCents: expense30d,
                  currency: currency,
                ),
                SizedBox(height: tokens.space4),

                // 3. GLANCEABLE HORIZONTAL MONTHLY BUDGETS STRIP
                _buildCashewBudgetsStrip(
                  tokens: tokens,
                  envelopes: repo.envelopes,
                  currency: currency,
                ),
                SizedBox(height: tokens.space4),

                // 4. FOCUS VIEW SWITCHER (Smooth Pop-Up Switching — Zero Clutter)
                _buildFocusTabSelector(tokens),
                SizedBox(height: tokens.space3),

                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    if (MediaQuery.disableAnimationsOf(context)) return child;
                    final scale = Tween<double>(begin: 0.97, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                    );
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: scale, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedFocusTab),
                    child: _selectedFocusTab == 0
                        ? Column(
                            children: [
                              _buildCashFlowHealthBar(
                                tokens: tokens,
                                incomeCents: income30d,
                                expenseCents: expense30d,
                                currency: currency,
                              ),
                              SizedBox(height: tokens.space3),
                              FinancialAdvisoryCard(
                                onOpenSavingsGoals: () => _openCreateGoalSheet(context, currency),
                              ),
                            ],
                          )
                        : _selectedFocusTab == 1
                            ? SavingsGoalsDeck(currency: currency)
                            : CategorySpendingDonutCard(currency: currency),
                  ),
                ),

                SizedBox(height: tokens.space5),

                // 5. COLOR-CODED RECENT ACTIVITY & SEARCH
                _buildRecentActivitySection(context, tokens, transactions, currency, repo.profileId),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCashewFlowCards({
    required CashIOThemeExtension tokens,
    required int incomeCents,
    required int expenseCents,
    required String currency,
  }) {
    final totalFlow = incomeCents + expenseCents;
    final incomeRatio = totalFlow > 0 ? (incomeCents / totalFlow).clamp(0.06, 1.0) : 0.0;
    final expenseRatio = totalFlow > 0 ? (expenseCents / totalFlow).clamp(0.06, 1.0) : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            key: const ValueKey('cashew_income_card'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: tokens.statusIncome.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.south_west_rounded, size: 14, color: tokens.statusIncome),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'INCOME',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Text(
                      '30d',
                      style: GoogleFonts.mukta(
                        color: tokens.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 22,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+${CurrencyUtils.format(incomeCents, currency: currency)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.statusIncome,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedMoneyBar(
                  value: incomeRatio,
                  height: 5,
                  fillColor: tokens.statusIncome,
                  glow: false,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: tokens.space3),
        Expanded(
          child: Container(
            key: const ValueKey('cashew_spent_card'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: tokens.statusExpense.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.north_east_rounded, size: 14, color: tokens.statusExpense),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SPENT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Text(
                      '30d',
                      style: GoogleFonts.mukta(
                        color: tokens.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 22,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '-${CurrencyUtils.format(expenseCents, currency: currency)}',
                      style: GoogleFonts.jetBrainsMono(
                        color: tokens.statusExpense,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedMoneyBar(
                  value: expenseRatio,
                  height: 5,
                  fillColor: tokens.statusExpense,
                  glow: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashewBudgetsStrip({
    required CashIOThemeExtension tokens,
    required List<EnvelopeModel> envelopes,
    required String currency,
  }) {
    return KeyedSubtree(
      key: const ValueKey('cashew_budgets_strip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MONTHLY BUDGETS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '${envelopes.length} active',
                style: GoogleFonts.mukta(
                  color: tokens.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (envelopes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.bgSurface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tokens.accentGold.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pie_chart_outline_rounded, size: 17, color: tokens.accentGold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No monthly budgets yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Open Budgets to set calm monthly spending caps.',
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
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: envelopes.map((env) {
                  final assigned = env.assignedCents;
                  final spent = env.spentCents;
                  final remaining = env.remainingCents;
                  final isOver = remaining < 0;
                  final ratio = assigned > 0 ? (spent / assigned).clamp(0.0, 1.0) : 0.0;
                  final barColor = isOver
                      ? tokens.statusExpense
                      : (ratio >= 0.8 ? tokens.accentChampagne : tokens.accentGold);

                  return Container(
                    width: 168,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: tokens.bgSurface,
                      borderRadius: BorderRadius.circular(tokens.radiusMd),
                      border: Border.all(
                        color: isOver
                            ? tokens.statusExpense.withValues(alpha: 0.45)
                            : tokens.borderHairline,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: barColor.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(env.icon, size: 14, color: barColor),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                env.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  color: tokens.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${CurrencyUtils.format(remaining.abs(), currency: currency)} ${isOver ? 'over' : 'left'}',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver ? tokens.statusExpense : tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedMoneyBar(
                          value: ratio,
                          height: 6,
                          fillColor: barColor,
                          glow: false,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${CurrencyUtils.format(spent, currency: currency)} / ${CurrencyUtils.format(assigned, currency: currency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.mukta(
                            color: tokens.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFocusTabSelector(CashIOThemeExtension tokens) {
    const tabs = [
      (Icons.auto_awesome_outlined, 'Insights'),
      (Icons.savings_outlined, 'Savings'),
      (Icons.pie_chart_outline_rounded, 'Breakdown'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedFocusTab == i;
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFocusTab = i);
              },
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: isSelected ? tokens.accent.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: isSelected ? Border.all(color: tokens.accent.withValues(alpha: 0.45)) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i].$1,
                      size: 15,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        tabs[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentCashDeck({
    required CashIOThemeExtension tokens,
    required int currentCashCents,
    required int netWorthCents,
    required String currency,
    required int totalLiabilitiesCents,
    required VoidCallback onAddCash,
    required VoidCallback onSpendCash,
    required VoidCallback onMoveCash,
    required VoidCallback onOpenRecurring,
    required VoidCallback onOpenFx,
  }) {
    final isNegative = currentCashCents < 0;
    final repo = VaultRepository.instance;

    return Container(
      decoration: tokens.heroGlowDecoration(
        glowColor: isNegative ? tokens.statusExpense : tokens.accentGold,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(tokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 15, color: tokens.accentGold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'TOTAL MONEY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onOpenFx,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.bgSurfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusPill),
                          border: Border.all(color: tokens.borderHairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.currency_exchange, size: 12, color: tokens.statusIncome),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                '≈ ${CurrencyUtils.format(repo.convertCents(currentCashCents, currency, repo.secondaryCurrency), currency: repo.secondaryCurrency)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  color: tokens.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Scale-safe Main Balance Display
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyUtils.format(currentCashCents, currency: currency),
                      style: GoogleFonts.jetBrainsMono(
                        color: isNegative ? tokens.statusExpense : tokens.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Net Worth: ${CurrencyUtils.format(netWorthCents, currency: currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.mukta(
                    color: tokens.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: tokens.space4),

                // Clear 3-Way Primary Money Actions (+ Add, - Spend, Move) + Bills Icon
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddCash,
                        icon: const Icon(Icons.add_rounded, size: 17),
                        label: const Text(
                          'Add',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.statusIncome,
                          foregroundColor: tokens.bgPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSpendCash,
                        icon: const Icon(Icons.remove_rounded, size: 17),
                        label: const Text(
                          'Spend',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: tokens.bgSurfaceElevated,
                          foregroundColor: tokens.textPrimary,
                          side: BorderSide(color: tokens.borderHairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('dashboard_move_button'),
                        onPressed: onMoveCash,
                        icon: Icon(Icons.swap_horiz_rounded, size: 17, color: tokens.accentGold),
                        label: const Text(
                          'Move',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: tokens.bgSurfaceElevated,
                          foregroundColor: tokens.textPrimary,
                          side: BorderSide(color: tokens.accentGold.withValues(alpha: 0.45)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.outlined(
                      onPressed: onOpenRecurring,
                      tooltip: 'Recurring Bills',
                      icon: Icon(Icons.repeat_rounded, size: 18, color: tokens.accentGold),
                      style: IconButton.styleFrom(
                        side: BorderSide(color: tokens.borderHairline),
                        backgroundColor: tokens.bgSurfaceElevated,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cash & Debts Split Footer with Animated Balance Ratio Bar (100% Overflow-Safe)
          Container(
            padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space3),
            decoration: BoxDecoration(
              color: tokens.bgSurfaceElevated.withValues(alpha: 0.72),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(tokens.radiusMd)),
              border: Border(top: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Column(
              children: [
                AnimatedSegmentedMoneyBar(
                  height: 4,
                  segments: [
                    MoneyBarSegment(
                      weight: (currentCashCents.abs() + totalLiabilitiesCents.abs()) > 0
                          ? (currentCashCents.clamp(0, 1 << 60) /
                                  (currentCashCents.abs() + totalLiabilitiesCents.abs()))
                              .clamp(0.06, 0.96)
                          : 0.94,
                      color: tokens.statusIncome,
                    ),
                    MoneyBarSegment(
                      weight: (currentCashCents.abs() + totalLiabilitiesCents.abs()) > 0
                          ? (totalLiabilitiesCents.abs() /
                                  (currentCashCents.abs() + totalLiabilitiesCents.abs()))
                              .clamp(0.04, 0.94)
                          : 0.06,
                      color: totalLiabilitiesCents > 0
                          ? tokens.statusExpense
                          : tokens.borderHairline,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CASH & BANK',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyUtils.format(currentCashCents, currency: currency),
                              style: GoogleFonts.jetBrainsMono(
                                color: tokens.statusIncome,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: tokens.borderSubtle),
                    SizedBox(width: tokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DEBTS',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              CurrencyUtils.format(totalLiabilitiesCents, currency: currency),
                              style: GoogleFonts.jetBrainsMono(
                                color: tokens.statusExpense,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowHealthBar({
    required CashIOThemeExtension tokens,
    required int incomeCents,
    required int expenseCents,
    required String currency,
  }) {
    final totalFlow = incomeCents + expenseCents;
    final incomeRatio = totalFlow > 0 ? (incomeCents / totalFlow) : 0.5;

    return Container(
      padding: EdgeInsets.all(tokens.space4),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '30-DAY CASHFLOW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                incomeCents >= expenseCents ? 'NET SURPLUS' : 'NET DEFICIT',
                style: GoogleFonts.mukta(
                  color: incomeCents >= expenseCents ? tokens.statusIncome : tokens.statusExpense,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSegmentedMoneyBar(
            height: 7,
            segments: [
              MoneyBarSegment(weight: incomeRatio.clamp(0.05, 0.95), color: tokens.statusIncome),
              MoneyBarSegment(weight: (1.0 - incomeRatio).clamp(0.05, 0.95), color: tokens.statusExpense),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'In: +${CurrencyUtils.format(incomeCents, currency: currency)}',
                    style: GoogleFonts.jetBrainsMono(
                      color: tokens.statusIncome,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Out: -${CurrencyUtils.format(expenseCents, currency: currency)}',
                    style: GoogleFonts.jetBrainsMono(
                      color: tokens.statusExpense,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    CashIOThemeExtension tokens,
    List<TransactionModel> transactions,
    String currency,
    String profileId,
  ) {
    final repo = VaultRepository.instance;
    final receiptsCount = transactions.where((t) => t.receiptPaths.isNotEmpty).length;
    final filtered = LedgerSearchService.instance.filterTransactions(transactions, _ledgerCriteria, repo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'RECENT ACTIVITY (${transactions.length})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const ReceiptVaultGallery()),
                );
              },
              icon: Icon(Icons.receipt_long_outlined, size: 15, color: tokens.accent),
              label: Text(
                'Receipts ($receiptsCount)',
                style: GoogleFonts.mukta(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              icon: Icon(Icons.post_add_rounded, size: 19, color: tokens.accentGold),
              visualDensity: VisualDensity.compact,
              tooltip: 'Custom Ledger Entry',
              onPressed: () => _openRecordTransactionSheet(context),
            ),
            IconButton(
              icon: Icon(
                _isSearchExpanded || _ledgerCriteria.hasActiveFilters ? Icons.filter_alt : Icons.search,
                size: 19,
                color: _isSearchExpanded || _ledgerCriteria.hasActiveFilters
                    ? tokens.accent
                    : tokens.textSecondary,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: 'Search & Filter Transactions',
              onPressed: () => setState(() => _isSearchExpanded = !_isSearchExpanded),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (_isSearchExpanded || _ledgerCriteria.hasActiveFilters) ...[
          LedgerSearchFilterBar(
            criteria: _ledgerCriteria,
            onCriteriaChanged: (newCriteria) => setState(() => _ledgerCriteria = newCriteria),
            totalCount: transactions.length,
            filteredCount: filtered.length,
          ),
          SizedBox(height: tokens.space3),
        ],

        if (transactions.isEmpty)
          Container(
            padding: EdgeInsets.all(tokens.space5),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Center(
              child: Text(
                'No transactions yet. Tap "Add Cash" or "New Entry" to log your first transaction.',
                textAlign: TextAlign.center,
                style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
              ),
            ),
          )
        else if (filtered.isEmpty)
          Container(
            padding: EdgeInsets.all(tokens.space5),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 32, color: tokens.textTertiary),
                  const SizedBox(height: 6),
                  Text(
                    'No transactions match your search filters.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _ledgerCriteria = const LedgerFilterCriteria()),
                    child: const Text('Reset Filters'),
                  ),
                ],
              ),
            ),
          )
        else
          ...filtered.take(20).map((tx) {
            final meta = _classifyTransaction(tx, repo, tokens);
            final formattedAmount = '${meta.prefix}${CurrencyUtils.format(tx.totalCents, currency: currency)}';
            final dateLabel = '${tx.timestamp.month}/${tx.timestamp.day}/${tx.timestamp.year}';

            return Container(
              key: ValueKey('tx_row_${tx.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: tokens.bgSurface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                onTap: tx.receiptPaths.isNotEmpty
                    ? () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ReceiptViewerDialog(
                            filename: tx.receiptPaths.first,
                            profileId: profileId,
                          ),
                        );
                      }
                    : null,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: meta.tint.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: meta.tint.withValues(alpha: 0.28)),
                  ),
                  child: Icon(
                    tx.receiptPaths.isNotEmpty ? Icons.receipt_long_rounded : meta.icon,
                    color: meta.tint,
                    size: 19,
                  ),
                ),
                title: Text(
                  tx.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.mukta(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${meta.categoryLabel} • $dateLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                      ),
                    ),
                    if (tx.receiptPaths.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.attach_file_rounded, size: 13, color: tokens.accent),
                    ],
                  ],
                ),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 138),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formattedAmount,
                      style: GoogleFonts.jetBrainsMono(
                        color: meta.amountColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  ({String prefix, Color tint, Color amountColor, IconData icon, String categoryLabel}) _classifyTransaction(
    TransactionModel tx,
    VaultRepository repo,
    CashIOThemeExtension tokens,
  ) {
    final accountById = <String, AccountModel>{
      for (final acc in repo.accounts) acc.id: acc,
    };

    AccountModel? expenseAcc;
    AccountModel? incomeAcc;
    for (final posting in tx.postings) {
      final acc = accountById[posting.accountId];
      if (acc == null) continue;
      if (acc.type == AccountType.expense) expenseAcc ??= acc;
      if (acc.type == AccountType.income) incomeAcc ??= acc;
    }

    if (expenseAcc != null) {
      return (
        prefix: '-',
        tint: tokens.statusExpense,
        amountColor: tokens.statusExpense,
        icon: expenseAcc.icon,
        categoryLabel: expenseAcc.name,
      );
    }
    if (incomeAcc != null) {
      return (
        prefix: '+',
        tint: tokens.statusIncome,
        amountColor: tokens.statusIncome,
        icon: incomeAcc.icon,
        categoryLabel: incomeAcc.name,
      );
    }
    return (
      prefix: '',
      tint: tokens.accentGold,
      amountColor: tokens.textPrimary,
      icon: Icons.swap_horiz_rounded,
      categoryLabel: 'Transfer',
    );
  }

  void _openRecordTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => const RecordTransactionSheet(),
    );
  }

  void _openAddCashSheet(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => AddCashSheet(baseCurrency: currency),
    );
  }

  void _openSpendCashSheet(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => SpendCashSheet(baseCurrency: currency),
    );
  }

  void _openMoveMoneySheet(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => MoveMoneySheet(baseCurrency: currency),
    );
  }

  void _openRecurringBillsSheet(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => RecurringBillsSheet(baseCurrency: currency),
    );
  }

  void _openFxConverterSheet(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => FxConverterSheet(baseCurrency: currency),
    );
  }

  void _openCreateGoalSheet(BuildContext context, String currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.bgPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.tokens.radiusLg)),
      ),
      builder: (ctx) => CreateSavingsGoalSheet(baseCurrency: currency),
    );
  }
}
