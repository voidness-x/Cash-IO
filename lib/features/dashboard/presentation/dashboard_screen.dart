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
import 'cash_action_sheets.dart';
import '../../analytics/presentation/category_spending_donut_card.dart';
import '../../subscriptions/presentation/recurring_bills_sheet.dart';
import '../../fx/presentation/fx_converter_sheet.dart';
import '../../advisory/presentation/financial_advisory_card.dart';
import '../../savings/presentation/savings_goals_deck.dart';
import '../../savings/presentation/savings_goal_sheets.dart';
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
  late final Animation<Offset> _slideAnimation;

  LedgerFilterCriteria _ledgerCriteria = const LedgerFilterCriteria();
  bool _isSearchExpanded = false;
  bool _promptedUpdateDialogThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();

    // Automatically check GitHub Releases for new APK / OTA updates on app launch
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
        final accounts = repo.accounts;
        final transactions = repo.transactions;
        final currency = repo.baseCurrency;
        final netWorth = repo.netWorthCents;
        final income30d = repo.last30DaysIncomeCents;
        final expense30d = repo.last30DaysExpenseCents;

        return FrostedScaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const CashIOLogo(
                  fontSize: 20,
                  animateO: true,
                  showSubtitle: false,
                ),
                SizedBox(width: tokens.space3),
                Container(
                  width: 1,
                  height: 18,
                  color: tokens.borderHairline,
                ),
                SizedBox(width: tokens.space3),
                InkWell(
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              repo.profileName.toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, color: tokens.textSecondary, size: 16),
                          ],
                        ),
                        Text(
                          'AIR-GAPPED VAULT',
                          style: GoogleFonts.mukta(
                            color: tokens.accentGold,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.sync_outlined),
                tooltip: 'E2EE Google Drive Sync',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await repo.triggerGoogleDriveSync();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'E2EE Sync: Changes securely committed to Google Drive.',
                          style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: tokens.statusIncome,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.system_update_alt_rounded,
                      color: otaService.availableUpdate != null ? tokens.accent : null,
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
                tooltip: 'OTA Updates & Rollback',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _openOtaUpdateSheet(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Profiles & Vaults',
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
            child: SlideTransition(
              position: _slideAnimation,
              child: ListView(
                padding: EdgeInsets.all(tokens.space4),
                children: [
                  // 0. LIVE GITHUB RELEASE UPDATE BANNER (Auto-triggered when new release ships)
                  if (otaService.hasUnreadUpdateBanner && otaService.availableUpdate != null) ...[
                    Container(
                      padding: EdgeInsets.all(tokens.space4),
                      decoration: BoxDecoration(
                        color: tokens.accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        border: Border.all(color: tokens.accent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.system_update_rounded, color: tokens.accent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'UPDATE AVAILABLE • v${otaService.availableUpdate!.version}',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: tokens.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  otaService.availableUpdate!.title,
                                  style: GoogleFonts.mukta(
                                    color: tokens.textPrimary,
                                    fontSize: 13,
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
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _openOtaUpdateSheet(context),
                            child: Text(
                              'Update',
                              style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 16, color: tokens.textTertiary),
                            visualDensity: VisualDensity.compact,
                            onPressed: otaService.dismissUpdateBanner,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.space4),
                  ],

                  // 1. HERO CURRENT CASH TERMINAL DECK
                  StaggeredEntrance(
                    index: 0,
                    child: _buildCurrentCashDeck(
                      tokens: tokens,
                      currentCashCents: repo.totalAssetsCents,
                      netWorthCents: netWorth,
                      currency: currency,
                      totalLiabilitiesCents: repo.totalLiabilitiesCents,
                      onAddCash: () => _openAddCashSheet(context, currency),
                      onSpendCash: () => _openSpendCashSheet(context, currency),
                    ),
                  ),
                  SizedBox(height: tokens.space4),

                  // 2. RAPID ACTION STRIP
                  StaggeredEntrance(
                    index: 1,
                    child: _buildQuickActionStrip(context, tokens, currency),
                  ),
                  SizedBox(height: tokens.space5),

                  // 3. ON-DEVICE FINANCIAL ADVISORY & INTELLIGENCE CARD (Phase 6A)
                  StaggeredEntrance(
                    index: 2,
                    child: FinancialAdvisoryCard(
                      onOpenSavingsGoals: () => _openCreateGoalSheet(context, currency),
                    ),
                  ),
                  SizedBox(height: tokens.space5),

                  // 4. CASH FLOW VELOCITY & HEALTH GAUGE
                  StaggeredEntrance(
                    index: 3,
                    child: _buildCashFlowHealthBar(
                      tokens: tokens,
                      incomeCents: income30d,
                      expenseCents: expense30d,
                      currency: currency,
                    ),
                  ),
                  SizedBox(height: tokens.space5),

                  // 5. CATEGORY SPENDING DONUT ANALYTICS
                  StaggeredEntrance(
                    index: 4,
                    child: CategorySpendingDonutCard(currency: currency),
                  ),
                  SizedBox(height: tokens.space5),

                  // 6. SAVINGS GOALS & LOCKED VAULTS DECK (Phase 6A)
                  StaggeredEntrance(
                    index: 5,
                    child: SavingsGoalsDeck(currency: currency),
                  ),
                  SizedBox(height: tokens.space5),

                  // 7. CHART OF ACCOUNTS MINI STRIP
                  StaggeredEntrance(
                    index: 6,
                    child: _buildAccountsStrip(context, tokens, accounts, currency),
                  ),
                  SizedBox(height: tokens.space5),

                  // 8. RECENT DOUBLE-ENTRY ACTIVITY FEED
                  _buildRecentActivitySection(context, tokens, transactions, currency, repo.profileId),
                  SizedBox(height: tokens.space10),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openRecordTransactionSheet(context),
            backgroundColor: tokens.accentGold,
            foregroundColor: tokens.bgPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            label: Text(
              'RECORD ENTRY',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Current Cash Terminal Deck with Quick Actions & Spline Chart
  // ---------------------------------------------------------------------------
  Widget _buildCurrentCashDeck({
    required CashIOThemeExtension tokens,
    required int currentCashCents,
    required int netWorthCents,
    required String currency,
    required int totalLiabilitiesCents,
    required VoidCallback onAddCash,
    required VoidCallback onSpendCash,
  }) {
    final isNegative = currentCashCents < 0;

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(tokens.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 14,
                          color: tokens.accentGold,
                        ),
                        SizedBox(width: tokens.space2),
                        Text(
                          'CURRENT CASH',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: tokens.space2, vertical: 3),
                      decoration: BoxDecoration(
                        color: tokens.statusIncomeBg,
                        borderRadius: BorderRadius.circular(tokens.radiusXs),
                        border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'AVAILABLE NOW',
                        style: GoogleFonts.mukta(
                          color: tokens.statusIncome,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space2),
                Text(
                  CurrencyUtils.format(currentCashCents, currency: currency),
                  style: GoogleFonts.jetBrainsMono(
                    color: isNegative ? tokens.statusExpense : tokens.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: tokens.space1),
                Text(
                  'Net Worth: ${CurrencyUtils.format(netWorthCents, currency: currency)}  •  Liabilities: ${CurrencyUtils.format(totalLiabilitiesCents, currency: currency)}',
                  style: GoogleFonts.mukta(
                    color: tokens.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: tokens.space2),
                InkWell(
                  onTap: () => _openFxConverterSheet(context, currency),
                  borderRadius: BorderRadius.circular(tokens.radiusXs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tokens.statusIncome.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(tokens.radiusXs),
                      border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_exchange, size: 12, color: tokens.statusIncome),
                        const SizedBox(width: 4),
                        Text(
                          '≈ ${CurrencyUtils.format(VaultRepository.instance.convertCents(currentCashCents, currency, VaultRepository.instance.secondaryCurrency), currency: VaultRepository.instance.secondaryCurrency)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: tokens.statusIncome,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${VaultRepository.instance.secondaryCurrency} FX)',
                          style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: tokens.space4),

                // User-friendly Add Cash & Spend Cash Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAddCash,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          'Add Cash',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.statusIncome,
                          foregroundColor: tokens.bgPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.space3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSpendCash,
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        label: Text(
                          'Spend Cash',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: tokens.bgSurfaceElevated,
                          foregroundColor: tokens.textPrimary,
                          side: BorderSide(color: tokens.borderHairline),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Canvas Sparkline Chart
          SizedBox(
            height: 48,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklineSplinePainter(
                strokeColor: tokens.accentGold,
                fillGradientColor: tokens.accentGold.withValues(alpha: 0.12),
              ),
            ),
          ),

          // Assets & Liabilities Split Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: tokens.space5, vertical: tokens.space3),
            decoration: BoxDecoration(
              color: tokens.bgSurfaceElevated,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(tokens.radiusMd)),
              border: Border(top: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.statusIncome,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: tokens.space2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ASSETS', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
                          Text(
                            CurrencyUtils.format(currentCashCents, currency: currency),
                            style: GoogleFonts.jetBrainsMono(color: tokens.statusIncome, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: tokens.borderSubtle),
                SizedBox(width: tokens.space4),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.statusExpense,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: tokens.space2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LIABILITIES', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
                          Text(
                            CurrencyUtils.format(totalLiabilitiesCents, currency: currency),
                            style: GoogleFonts.jetBrainsMono(color: tokens.statusExpense, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rapid Action Strip
  // ---------------------------------------------------------------------------
  Widget _buildQuickActionStrip(BuildContext context, CashIOThemeExtension tokens, String currency) {
    return Row(
      children: [
        _buildActionTile(
          icon: Icons.add_circle_outline,
          label: '+ Add',
          tokens: tokens,
          onTap: () => _openAddCashSheet(context, currency),
        ),
        SizedBox(width: tokens.space2),
        _buildActionTile(
          icon: Icons.remove_circle_outline,
          label: '- Spend',
          tokens: tokens,
          onTap: () => _openSpendCashSheet(context, currency),
        ),
        SizedBox(width: tokens.space2),
        _buildActionTile(
          icon: Icons.repeat_rounded,
          label: 'Recurring',
          tokens: tokens,
          onTap: () => _openRecurringBillsSheet(context, currency),
        ),
        SizedBox(width: tokens.space2),
        _buildActionTile(
          icon: Icons.currency_exchange,
          label: 'FX Matrix',
          tokens: tokens,
          onTap: () => _openFxConverterSheet(context, currency),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required CashIOThemeExtension tokens,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: tokens.space3),
            decoration: BoxDecoration(
              color: tokens.bgSurface,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Column(
              children: [
                Icon(icon, color: tokens.accentGold, size: 20),
                SizedBox(height: tokens.space1),
                Text(
                  label,
                  style: GoogleFonts.mukta(
                    color: tokens.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cash Flow Velocity & Health Bar
  // ---------------------------------------------------------------------------
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '30-DAY CASHFLOW VELOCITY',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                incomeCents >= expenseCents ? 'SURPLUS' : 'DEFICIT',
                style: GoogleFonts.mukta(
                  color: incomeCents >= expenseCents ? tokens.statusIncome : tokens.statusExpense,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.space3),

          // Two-Tone Segmented Health Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusPill),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: (incomeRatio * 100).toInt().clamp(1, 99),
                    child: Container(color: tokens.statusIncome),
                  ),
                  Expanded(
                    flex: ((1.0 - incomeRatio) * 100).toInt().clamp(1, 99),
                    child: Container(color: tokens.statusExpense),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.space3),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+${CurrencyUtils.format(incomeCents, currency: currency)}',
                style: GoogleFonts.jetBrainsMono(
                  color: tokens.statusIncome,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '-${CurrencyUtils.format(expenseCents, currency: currency)}',
                style: GoogleFonts.jetBrainsMono(
                  color: tokens.statusExpense,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chart of Accounts Mini Strip
  // ---------------------------------------------------------------------------
  Widget _buildAccountsStrip(
    BuildContext context,
    CashIOThemeExtension tokens,
    List<AccountModel> accounts,
    String currency,
  ) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNTS OVERVIEW',
          style: GoogleFonts.spaceGrotesk(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(height: tokens.space2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: accounts.map((acc) {
              final isAsset = acc.type == AccountType.asset;
              return Container(
                margin: EdgeInsets.only(right: tokens.space2),
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.space3,
                  vertical: tokens.space2,
                ),
                decoration: BoxDecoration(
                  color: tokens.bgSurface,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Row(
                  children: [
                    Icon(acc.icon, size: 16, color: isAsset ? tokens.accentChampagne : tokens.textSecondary),
                    SizedBox(width: tokens.space2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc.name,
                          style: GoogleFonts.mukta(
                            color: tokens.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyUtils.format(acc.balanceCents, currency: acc.currency),
                          style: GoogleFonts.jetBrainsMono(
                            color: isAsset ? tokens.statusIncome : tokens.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Recent Activity Section
  // ---------------------------------------------------------------------------
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
        StaggeredEntrance(
          index: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${transactions.length} records',
                    style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  // Receipt Vault Gallery Button
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
                    icon: Icon(Icons.shield_outlined, size: 14, color: tokens.accent),
                    label: Text(
                      'Receipts ($receiptsCount)',
                      style: GoogleFonts.mukta(color: tokens.accent, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Search Scrubber Toggle Button
                  IconButton(
                    icon: Icon(
                      _isSearchExpanded || _ledgerCriteria.hasActiveFilters ? Icons.filter_alt : Icons.search,
                      size: 18,
                      color: _isSearchExpanded || _ledgerCriteria.hasActiveFilters ? tokens.accent : tokens.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Search & Date Scrubber',
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = !_isSearchExpanded;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.space2),

        // Search & Date Scrubber Bar
        if (_isSearchExpanded || _ledgerCriteria.hasActiveFilters) ...[
          LedgerSearchFilterBar(
            criteria: _ledgerCriteria,
            onCriteriaChanged: (newCriteria) {
              setState(() => _ledgerCriteria = newCriteria);
            },
            totalCount: transactions.length,
            filteredCount: filtered.length,
          ),
          SizedBox(height: tokens.space3),
        ],

        if (transactions.isEmpty) ...[
          StaggeredEntrance(
            index: 5,
            child: Container(
              padding: EdgeInsets.all(tokens.space6),
              decoration: BoxDecoration(
                color: tokens.bgSurface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Center(
                child: Text(
                  'No transactions recorded. Tap "Record Entry" to post your first entry.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ),
        ] else if (filtered.isEmpty) ...[
          StaggeredEntrance(
            index: 5,
            child: Container(
              padding: EdgeInsets.all(tokens.space6),
              decoration: BoxDecoration(
                color: tokens.bgSurface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded, size: 36, color: tokens.textTertiary),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions match your search filters.',
                      style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() => _ledgerCriteria = const LedgerFilterCriteria()),
                      child: Text(
                        'Reset Filters',
                        style: GoogleFonts.mukta(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          ...filtered.take(20).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final tx = entry.value;
            return StaggeredEntrance(
              index: 5 + idx,
              child: Container(
                margin: EdgeInsets.only(bottom: tokens.space2),
                decoration: BoxDecoration(
                  color: tokens.bgSurface,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: ListTile(
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Center(
                      child: Icon(
                        tx.receiptPaths.isNotEmpty ? Icons.receipt_long : Icons.swap_horiz,
                        color: tokens.accentGold,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    tx.description,
                    style: GoogleFonts.mukta(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${tx.timestamp.month}/${tx.timestamp.day} • ${tx.postings.length} legs ${tx.receiptPaths.isNotEmpty ? "• 📎" : ""}',
                    style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                  ),
                  trailing: Text(
                    CurrencyUtils.format(tx.totalCents, currency: currency),
                    style: GoogleFonts.jetBrainsMono(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
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

/// Dynamic Bezier Spline Sparkline Painter
class _SparklineSplinePainter extends CustomPainter {
  final Color strokeColor;
  final Color fillGradientColor;

  const _SparklineSplinePainter({
    required this.strokeColor,
    required this.fillGradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillGradientColor, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Smooth simulated financial balance curve
    final path = Path();
    final fillPath = Path();

    final points = [
      Offset(0, size.height * 0.75),
      Offset(size.width * 0.20, size.height * 0.65),
      Offset(size.width * 0.45, size.height * 0.70),
      Offset(size.width * 0.70, size.height * 0.40),
      Offset(size.width * 0.85, size.height * 0.48),
      Offset(size.width, size.height * 0.25),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
