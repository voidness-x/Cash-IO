import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';

/// Multi-currency FX matrix and instant offline converter
class FxConverterSheet extends StatefulWidget {
  final String baseCurrency;

  const FxConverterSheet({super.key, required this.baseCurrency});

  @override
  State<FxConverterSheet> createState() => _FxConverterSheetState();
}

class _FxConverterSheetState extends State<FxConverterSheet> {
  final _amountCtrl = TextEditingController(text: '100');
  late String _selectedFromCurrency;
  final List<String> _supportedCurrencies = ['IQD', 'USD', 'EUR', 'GBP', 'SAR', 'AED'];

  @override
  void initState() {
    super.initState();
    _selectedFromCurrency = widget.baseCurrency;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final repo = VaultRepository.instance;
    final inputCents = CurrencyUtils.parseToCents(_amountCtrl.text.trim());

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
                    color: tokens.statusIncome.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: Icon(Icons.currency_exchange, color: tokens.statusIncome, size: 24),
                ),
                SizedBox(width: tokens.space3),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MULTI-CURRENCY FX MATRIX',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Air-gapped currency conversion & secondary display',
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

            // Base Amount Input & Currency Selector
            Container(
              padding: EdgeInsets.all(tokens.space4),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONVERT FROM',
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: tokens.space2),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: _selectedFromCurrency,
                        dropdownColor: tokens.bgSurfaceElevated,
                        underline: const SizedBox.shrink(),
                        icon: Icon(Icons.arrow_drop_down, color: tokens.statusIncome),
                        items: _supportedCurrencies.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.statusIncome,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedFromCurrency = val);
                          }
                        },
                      ),
                      SizedBox(width: tokens.space3),
                      Expanded(
                        child: TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.jetBrainsMono(
                            color: tokens.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.space4),

            // Secondary Currency Selector for Dashboard
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SECONDARY DISPLAY CURRENCY',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Active: ${repo.secondaryCurrency}',
                  style: GoogleFonts.mukta(color: tokens.accentGold, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: tokens.space2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _supportedCurrencies.map((curr) {
                  final isSel = repo.secondaryCurrency == curr;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(curr),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) {
                          HapticFeedback.selectionClick();
                          repo.setSecondaryCurrency(curr);
                        }
                      },
                      selectedColor: tokens.statusIncome,
                      labelStyle: GoogleFonts.spaceGrotesk(
                        color: isSel ? tokens.bgPrimary : tokens.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: tokens.space4),

            // Live Conversion Matrix
            Text(
              'EQUIVALENT VALUES ACROSS CURRENCIES',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: tokens.space2),

            ..._supportedCurrencies
                .where((c) => c != _selectedFromCurrency)
                .map((targetCurr) {
              final convertedCents = repo.convertCents(inputCents, _selectedFromCurrency, targetCurr);
              final isSecondary = repo.secondaryCurrency == targetCurr;

              return Container(
                margin: EdgeInsets.only(bottom: tokens.space2),
                padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space3),
                decoration: BoxDecoration(
                  color: isSecondary
                      ? tokens.statusIncome.withValues(alpha: 0.1)
                      : tokens.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  border: Border.all(
                    color: isSecondary
                        ? tokens.statusIncome.withValues(alpha: 0.4)
                        : tokens.borderHairline,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          targetCurr,
                          style: GoogleFonts.spaceGrotesk(
                            color: isSecondary ? tokens.statusIncome : tokens.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (isSecondary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: tokens.statusIncome,
                              borderRadius: BorderRadius.circular(tokens.radiusXs),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.bgPrimary,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      CurrencyUtils.format(convertedCents, currency: targetCurr),
                      style: GoogleFonts.jetBrainsMono(
                        color: isSecondary ? tokens.statusIncome : tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: tokens.space4),

            // Offline Guarantee Notice
            Container(
              padding: EdgeInsets.all(tokens.space3),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: tokens.accentGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All currency valuations are computed on local hardware with zero external price telemetry or network leaks.',
                      style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
