import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/services/ledger_search_service.dart';

class LedgerSearchFilterBar extends StatefulWidget {
  final LedgerFilterCriteria criteria;
  final ValueChanged<LedgerFilterCriteria> onCriteriaChanged;
  final int totalCount;
  final int filteredCount;

  const LedgerSearchFilterBar({
    super.key,
    required this.criteria,
    required this.onCriteriaChanged,
    required this.totalCount,
    required this.filteredCount,
  });

  @override
  State<LedgerSearchFilterBar> createState() => _LedgerSearchFilterBarState();
}

class _LedgerSearchFilterBarState extends State<LedgerSearchFilterBar> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.criteria.searchQuery);
  }

  @override
  void didUpdateWidget(covariant LedgerSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.criteria.searchQuery != _searchCtrl.text) {
      _searchCtrl.text = widget.criteria.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAdvancedFiltersSheet(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var tempCriteria = widget.criteria;
        final minCtrl = TextEditingController(
          text: tempCriteria.minAmountCents != null ? (tempCriteria.minAmountCents! / 100).toStringAsFixed(0) : '',
        );
        final maxCtrl = TextEditingController(
          text: tempCriteria.maxAmountCents != null ? (tempCriteria.maxAmountCents! / 100).toStringAsFixed(0) : '',
        );

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: tokens.space5,
                right: tokens.space5,
                top: tokens.space4,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + tokens.space5,
              ),
              decoration: BoxDecoration(
                color: tokens.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: tokens.borderHairline),
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
                    SizedBox(height: tokens.space3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FILTER & SORT LEDGER',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (tempCriteria.hasActiveFilters)
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempCriteria = const LedgerFilterCriteria();
                                minCtrl.clear();
                                maxCtrl.clear();
                              });
                            },
                            child: Text(
                              'Reset All',
                              style: GoogleFonts.mukta(color: tokens.accent, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Sort Order
                    Text(
                      'SORT ORDER',
                      style: GoogleFonts.spaceGrotesk(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: tokens.space2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip('Newest First', SortOption.newestFirst, tempCriteria.sortBy, (opt) {
                          setModalState(() => tempCriteria = tempCriteria.copyWith(sortBy: opt));
                        }, tokens),
                        _buildSortChip('Oldest First', SortOption.oldestFirst, tempCriteria.sortBy, (opt) {
                          setModalState(() => tempCriteria = tempCriteria.copyWith(sortBy: opt));
                        }, tokens),
                        _buildSortChip('Highest Amount', SortOption.highestAmount, tempCriteria.sortBy, (opt) {
                          setModalState(() => tempCriteria = tempCriteria.copyWith(sortBy: opt));
                        }, tokens),
                        _buildSortChip('Lowest Amount', SortOption.lowestAmount, tempCriteria.sortBy, (opt) {
                          setModalState(() => tempCriteria = tempCriteria.copyWith(sortBy: opt));
                        }, tokens),
                      ],
                    ),
                    SizedBox(height: tokens.space4),

                    // Filter by Account
                    Text(
                      'ACCOUNT FILTER',
                      style: GoogleFonts.spaceGrotesk(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: tokens.space2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: tokens.bgCanvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: tempCriteria.accountId,
                          isExpanded: true,
                          dropdownColor: tokens.bgSurface,
                          style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14),
                          hint: Text('All Accounts', style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 14)),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Accounts (No Filter)', style: GoogleFonts.mukta(color: tokens.textSecondary)),
                            ),
                            ...repo.accounts.map((a) {
                              return DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text('${a.name} (${a.currency})', style: GoogleFonts.mukta(color: tokens.textPrimary)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setModalState(() {
                              tempCriteria = tempCriteria.copyWith(
                                accountId: val,
                                clearAccountId: val == null,
                              );
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: tokens.space4),

                    // Amount Range
                    Text(
                      'AMOUNT RANGE (${repo.baseCurrency})',
                      style: GoogleFonts.spaceGrotesk(color: tokens.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: tokens.space2),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Min Amount',
                              prefixText: '\$ ',
                              prefixStyle: TextStyle(color: tokens.textTertiary),
                              filled: true,
                              fillColor: tokens.bgCanvas,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.accent)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Max Amount',
                              prefixText: '\$ ',
                              prefixStyle: TextStyle(color: tokens.textTertiary),
                              filled: true,
                              fillColor: tokens.bgCanvas,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.accent)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.space5),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final minVal = int.tryParse(minCtrl.text.trim());
                          final maxVal = int.tryParse(maxCtrl.text.trim());
                          final updated = tempCriteria.copyWith(
                            minAmountCents: minVal != null ? minVal * 100 : null,
                            maxAmountCents: maxVal != null ? maxVal * 100 : null,
                            clearMinMax: minVal == null && maxVal == null,
                          );
                          widget.onCriteriaChanged(updated);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'APPLY FILTERS',
                          style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8),
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

  Widget _buildSortChip(
    String label,
    SortOption option,
    SortOption current,
    ValueChanged<SortOption> onSelected,
    CashIOThemeExtension tokens,
  ) {
    final isSelected = option == current;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.mukta(
          color: isSelected ? Colors.black : tokens.textPrimary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: tokens.accent,
      backgroundColor: tokens.bgCanvas,
      side: BorderSide(color: isSelected ? tokens.accent : tokens.borderHairline),
      onSelected: (_) => onSelected(option),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final criteria = widget.criteria;

    return Container(
      padding: EdgeInsets.all(tokens.space3),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search text field with Clear & Filter buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: tokens.bgCanvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search descriptions, memos, accounts...',
                      hintStyle: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: tokens.textSecondary, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: tokens.textTertiary,
                              onPressed: () {
                                _searchCtrl.clear();
                                widget.onCriteriaChanged(criteria.copyWith(searchQuery: ''));
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      widget.onCriteriaChanged(criteria.copyWith(searchQuery: val));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter icon button with active dot
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: criteria.hasActiveFilters ? tokens.accent.withValues(alpha: 0.15) : tokens.bgCanvas,
                      foregroundColor: criteria.hasActiveFilters ? tokens.accent : tokens.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: criteria.hasActiveFilters ? tokens.accent : tokens.borderHairline),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    tooltip: 'Advanced Filters & Sorting',
                    onPressed: () => _showAdvancedFiltersSheet(context),
                  ),
                  if (criteria.hasActiveFilters)
                    Positioned(
                      top: 6,
                      right: 6,
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
            ],
          ),
          SizedBox(height: tokens.space2),

          // 2. Horizontal Date Scrubber & Receipts Toggle
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDatePill('All Time', DateFilterOption.all, criteria.dateFilter, tokens),
                const SizedBox(width: 6),
                _buildDatePill('Today', DateFilterOption.today, criteria.dateFilter, tokens),
                const SizedBox(width: 6),
                _buildDatePill('Last 7 Days', DateFilterOption.last7Days, criteria.dateFilter, tokens),
                const SizedBox(width: 6),
                _buildDatePill('Last 30 Days', DateFilterOption.last30Days, criteria.dateFilter, tokens),
                const SizedBox(width: 8),

                // Vertical Divider
                Container(
                  width: 1,
                  height: 20,
                  color: tokens.borderHairline,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                const SizedBox(width: 8),

                // Receipts Only Toggle Pill
                FilterChip(
                  avatar: Icon(
                    Icons.receipt_long_outlined,
                    size: 14,
                    color: criteria.hasReceiptsOnly ? Colors.black : tokens.textSecondary,
                  ),
                  label: Text(
                    'Receipts Only',
                    style: GoogleFonts.mukta(
                      color: criteria.hasReceiptsOnly ? Colors.black : tokens.textPrimary,
                      fontSize: 11,
                      fontWeight: criteria.hasReceiptsOnly ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: criteria.hasReceiptsOnly,
                  selectedColor: tokens.accent,
                  backgroundColor: tokens.bgCanvas,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: criteria.hasReceiptsOnly ? tokens.accent : tokens.borderHairline,
                  ),
                  onSelected: (selected) {
                    widget.onCriteriaChanged(criteria.copyWith(hasReceiptsOnly: selected));
                  },
                ),
              ],
            ),
          ),

          // 3. Status Readout
          if (criteria.hasActiveFilters) ...[
            SizedBox(height: tokens.space2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${widget.filteredCount} of ${widget.totalCount} entries',
                  style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                ),
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    widget.onCriteriaChanged(const LedgerFilterCriteria());
                  },
                  child: Text(
                    'Clear filters',
                    style: GoogleFonts.mukta(color: tokens.accent, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDatePill(
    String label,
    DateFilterOption option,
    DateFilterOption current,
    CashIOThemeExtension tokens,
  ) {
    final isSelected = option == current;
    return GestureDetector(
      onTap: () {
        widget.onCriteriaChanged(widget.criteria.copyWith(dateFilter: option));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accent : tokens.bgCanvas,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: isSelected ? Colors.black : tokens.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
