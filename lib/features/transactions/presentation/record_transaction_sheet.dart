import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/media/receipt_vault_service.dart';
import '../../../core/utils/currency_utils.dart';

class RecordTransactionSheet extends StatefulWidget {
  const RecordTransactionSheet({super.key});

  @override
  State<RecordTransactionSheet> createState() => _RecordTransactionSheetState();
}

class _RecordTransactionSheetState extends State<RecordTransactionSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _sourceAccountId;
  String? _destinationAccountId;
  bool _isSplitTransaction = false;
  final List<String> _attachedReceipts = [];
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _splitItems = [
    {'account_id': null, 'amount': TextEditingController()},
    {'account_id': null, 'amount': TextEditingController()},
  ];

  @override
  void initState() {
    super.initState();
    final accounts = VaultRepository.instance.accounts;
    if (accounts.isNotEmpty) {
      final assets = accounts.where((a) => a.type == AccountType.asset).toList();
      final expenses = accounts.where((a) => a.type == AccountType.expense).toList();
      if (assets.isNotEmpty) _sourceAccountId = assets.first.id;
      if (expenses.isNotEmpty) _destinationAccountId = expenses.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    for (final s in _splitItems) {
      (s['amount'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _onSave() async {
    final currency = VaultRepository.instance.baseCurrency;
    final totalCents = CurrencyUtils.parseToCents(_amountController.text);
    final description = _descriptionController.text.trim();

    if (totalCents <= 0 || description.isEmpty || _sourceAccountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please provide a valid non-zero amount, description, and source account.',
            style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.tokens.statusExpense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final postings = <PostingModel>[];

    if (!_isSplitTransaction) {
      if (_destinationAccountId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a destination account or category.',
              style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: context.tokens.statusExpense,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Double-entry balancing invariant:
      // Credit Source Account: -totalCents
      // Debit Destination Account: +totalCents
      postings.add(PostingModel(accountId: _sourceAccountId!, amountCents: -totalCents));
      postings.add(PostingModel(accountId: _destinationAccountId!, amountCents: totalCents));
    } else {
      postings.add(PostingModel(accountId: _sourceAccountId!, amountCents: -totalCents));
      int sumSplit = 0;
      for (final split in _splitItems) {
        final splitAcc = split['account_id'] as String?;
        final splitAmtCtrl = split['amount'] as TextEditingController;
        final splitCents = CurrencyUtils.parseToCents(splitAmtCtrl.text);
        if (splitAcc != null && splitCents > 0) {
          sumSplit += splitCents;
          postings.add(PostingModel(accountId: splitAcc, amountCents: splitCents));
        }
      }

      if (sumSplit != totalCents) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Split postings sum (${CurrencyUtils.format(sumSplit, currency: currency)}) does not balance with total amount (${CurrencyUtils.format(totalCents, currency: currency)}).',
              style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: context.tokens.statusExpense,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final success = await VaultRepository.instance.recordTransaction(
      description: description,
      postings: postings,
      receiptPaths: _attachedReceipts,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction recorded to double-entry ledger.',
            style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.tokens.statusIncome,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accounts = VaultRepository.instance.accounts;
    final currency = VaultRepository.instance.baseCurrency;

    return Container(
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusMd)),
        border: Border.all(color: tokens.borderHairline),
      ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECORD ENTRY',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'ZERO-SUM DOUBLE-ENTRY LEDGER',
                      style: GoogleFonts.mukta(
                        color: tokens.accentGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: tokens.space2, vertical: 3),
                  decoration: BoxDecoration(
                    color: tokens.statusIncomeBg,
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                    border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline, size: 12, color: tokens.statusIncome),
                      const SizedBox(width: 4),
                      Text(
                        'BALANCED',
                        style: GoogleFonts.mukta(
                          color: tokens.statusIncome,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.space4),

            // Amount Prominent Card
            Container(
              padding: EdgeInsets.all(tokens.space4),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRANSACTION AMOUNT',
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: tokens.space2),
                  TextField(
                    controller: _amountController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.jetBrainsMono(
                      color: tokens.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      prefixText: '$currency ',
                      prefixStyle: GoogleFonts.jetBrainsMono(
                        color: tokens.accentGold,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0.00',
                      hintStyle: GoogleFonts.jetBrainsMono(
                        color: tokens.textTertiary,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.space4),

            // Description Input
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Description (e.g. Market, Fuel, Salary, Transfer)',
              ),
            ),
            SizedBox(height: tokens.space4),

            // Visual Posting Routing Diagram
            Container(
              padding: EdgeInsets.all(tokens.space3),
              decoration: BoxDecoration(
                color: tokens.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOURCE (CREDIT)', style: GoogleFonts.spaceGrotesk(color: tokens.statusExpense, fontSize: 9, fontWeight: FontWeight.w800)),
                        Text(
                          _sourceAccountId != null
                              ? accounts.firstWhere((a) => a.id == _sourceAccountId, orElse: () => accounts.first).name
                              : 'Select',
                          style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: tokens.accentGold, size: 18),
                  SizedBox(width: tokens.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DESTINATION (DEBIT)', style: GoogleFonts.spaceGrotesk(color: tokens.statusIncome, fontSize: 9, fontWeight: FontWeight.w800)),
                        Text(
                          _destinationAccountId != null
                              ? accounts.firstWhere((a) => a.id == _destinationAccountId, orElse: () => accounts.last).name
                              : 'Select',
                          style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.space4),

            // Source Account Selector (Paid From)
            DropdownButtonFormField<String>(
              initialValue: _sourceAccountId,
              decoration: const InputDecoration(
                labelText: 'Paid From (Source Asset / Account)',
              ),
              items: accounts.map((acc) {
                return DropdownMenuItem(
                  value: acc.id,
                  child: Text(
                    '${acc.name} (${CurrencyUtils.format(acc.balanceCents, currency: acc.currency)})',
                    style: GoogleFonts.mukta(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _sourceAccountId = val),
            ),
            SizedBox(height: tokens.space3),

            // Split Toggle
            Row(
              children: [
                Checkbox(
                  value: _isSplitTransaction,
                  activeColor: tokens.accentGold,
                  onChanged: (val) => setState(() => _isSplitTransaction = val ?? false),
                ),
                Text(
                  'Itemize Split Multi-Leg Postings',
                  style: GoogleFonts.mukta(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            if (!_isSplitTransaction) ...[
              DropdownButtonFormField<String>(
                initialValue: _destinationAccountId,
                decoration: const InputDecoration(
                  labelText: 'Assigned To (Category / Destination Account)',
                ),
                items: accounts.map((acc) {
                  return DropdownMenuItem(
                    value: acc.id,
                    child: Text(
                      '${acc.name} [${acc.type.name.toUpperCase()}]',
                      style: GoogleFonts.mukta(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _destinationAccountId = val),
              ),
            ] else ...[
              ...List.generate(_splitItems.length, (idx) {
                return Padding(
                  padding: EdgeInsets.only(bottom: tokens.space2),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _splitItems[idx]['account_id'] as String?,
                          decoration: InputDecoration(
                            labelText: 'Split Leg ${idx + 1}',
                          ),
                          items: accounts.map((acc) {
                            return DropdownMenuItem(value: acc.id, child: Text(acc.name, style: GoogleFonts.mukta(fontSize: 12)));
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _splitItems[idx]['account_id'] = val);
                          },
                        ),
                      ),
                      SizedBox(width: tokens.space2),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _splitItems[idx]['amount'] as TextEditingController?,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.jetBrainsMono(fontSize: 13),
                          decoration: InputDecoration(
                            prefixText: '$currency ',
                            labelText: 'Amount',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            SizedBox(height: tokens.space4),

            // Receipt Attachments Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECEIPT VAULT (${_attachedReceipts.length}/5)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                TextButton.icon(
                  onPressed: _attachedReceipts.length >= 5 ? null : () => _showMediaSourceSheet(context),
                  icon: Icon(Icons.add_a_photo_outlined, size: 16, color: tokens.accentGold),
                  label: Text('Attach Receipt', style: GoogleFonts.mukta(color: tokens.accentGold, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (_attachedReceipts.isNotEmpty) ...[
              Wrap(
                spacing: tokens.space2,
                runSpacing: tokens.space2,
                children: _attachedReceipts.map((filename) {
                  return Chip(
                    avatar: Icon(Icons.receipt_long, size: 16, color: tokens.accentChampagne),
                    label: Text(
                      filename.length > 16 ? '${filename.substring(0, 14)}...' : filename,
                      style: GoogleFonts.mukta(fontSize: 11),
                    ),
                    onDeleted: () {
                      setState(() => _attachedReceipts.remove(filename));
                      ReceiptVaultService.instance.deleteReceipt(filename);
                    },
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: tokens.space6),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _onSave,
                child: _isSubmitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: tokens.bgPrimary, strokeWidth: 2),
                      )
                    : Text(
                        'COMMIT TO LEDGER',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaSourceSheet(BuildContext context) {
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(tokens.space4),
                child: Text(
                  'ENCRYPTED RECEIPT VAULT',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: tokens.accentGold),
                title: const Text('Capture with Camera'),
                subtitle: const Text('Auto-compressed to WebP & encrypted with AES-256-GCM'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await ReceiptVaultService.instance.captureAndEncryptReceipt(
                    source: ImageSource.camera,
                    profileId: VaultRepository.instance.profileId,
                  );
                  if (file != null && mounted) {
                    setState(() => _attachedReceipts.add(file));
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: tokens.accentChampagne),
                title: const Text('Select from Photo Library'),
                subtitle: const Text('Local sandbox air-gapped encryption'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await ReceiptVaultService.instance.captureAndEncryptReceipt(
                    source: ImageSource.gallery,
                    profileId: VaultRepository.instance.profileId,
                  );
                  if (file != null && mounted) {
                    setState(() => _attachedReceipts.add(file));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
