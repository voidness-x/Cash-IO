import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/finance_models.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/media/receipt_vault_service.dart';
import '../../../core/utils/currency_utils.dart';
import 'receipt_viewer_dialog.dart';

class ReceiptVaultGallery extends StatefulWidget {
  const ReceiptVaultGallery({super.key});

  @override
  State<ReceiptVaultGallery> createState() => _ReceiptVaultGalleryState();
}

class _ReceiptVaultGalleryState extends State<ReceiptVaultGallery> {
  String _searchFilter = '';

  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;
    final currency = repo.baseCurrency;

    final receiptTxs = repo.transactions.where((tx) => tx.receiptPaths.isNotEmpty).toList();
    final filteredTxs = _searchFilter.trim().isEmpty
        ? receiptTxs
        : receiptTxs.where((tx) {
            final q = _searchFilter.toLowerCase();
            return tx.description.toLowerCase().contains(q) ||
                (tx.note?.toLowerCase().contains(q) ?? false);
          }).toList();

    final totalReceiptsCount = receiptTxs.fold<int>(0, (sum, tx) => sum + tx.receiptPaths.length);

    return Scaffold(
      backgroundColor: tokens.bgCanvas,
      appBar: AppBar(
        backgroundColor: tokens.bgSurface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: tokens.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'RECEIPT VAULT GALLERY',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Text(
              '$totalReceiptsCount Encrypted Records • Zero Plaintext Disk Leaks',
              style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: EdgeInsets.all(tokens.space4),
            color: tokens.bgSurface,
            child: TextField(
              style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search receipts by merchant, notes...',
                hintStyle: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: tokens.textSecondary, size: 18),
                isDense: true,
                filled: true,
                fillColor: tokens.bgCanvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.borderHairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.borderHairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.accent),
                ),
              ),
              onChanged: (val) => setState(() => _searchFilter = val),
            ),
          ),

          Expanded(
            child: filteredTxs.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(tokens.space6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: tokens.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            receiptTxs.isEmpty
                                ? 'No Encrypted Receipts Stored'
                                : 'No receipts match your search filter',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            receiptTxs.isEmpty
                                ? 'Tap "Record Entry" on the dashboard and attach a photo to store receipts with AES-256 hardware encryption.'
                                : 'Try clearing your search term to see all captured receipts.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(tokens.space4),
                    itemCount: filteredTxs.length,
                    itemBuilder: (context, idx) {
                      final tx = filteredTxs[idx];
                      return _buildReceiptTransactionCard(context, tx, tokens, currency, repo.profileId);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTransactionCard(
    BuildContext context,
    TransactionModel tx,
    CashIOThemeExtension tokens,
    String currency,
    String profileId,
  ) {
    final amountCents = tx.postings.fold<int>(
      0,
      (maxVal, p) => p.amountCents.abs() > maxVal ? p.amountCents.abs() : maxVal,
    );

    return Container(
      margin: EdgeInsets.only(bottom: tokens.space4),
      padding: EdgeInsets.all(tokens.space4),
      decoration: BoxDecoration(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.timestamp.year}-${tx.timestamp.month.toString().padLeft(2, '0')}-${tx.timestamp.day.toString().padLeft(2, '0')} • ${tx.timestamp.hour.toString().padLeft(2, '0')}:${tx.timestamp.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtils.format(amountCents, currency: currency),
                style: GoogleFonts.jetBrainsMono(
                  color: tokens.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (tx.note != null && tx.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tx.note!,
              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          SizedBox(height: tokens.space3),

          // Receipts Grid / Thumbnails
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: tx.receiptPaths.map((filename) {
              return _buildReceiptThumbnail(context, filename, profileId, tokens);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptThumbnail(
    BuildContext context,
    String filename,
    String profileId,
    CashIOThemeExtension tokens,
  ) {
    return FutureBuilder(
      future: ReceiptVaultService.instance.decryptReceiptBytes(
        filename: filename,
        profileId: profileId,
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => ReceiptViewerDialog(
                filename: filename,
                profileId: profileId,
                onDelete: () => setState(() {}),
              ),
            );
          },
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: tokens.bgCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.borderHairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bytes != null)
                  Image.memory(bytes, fit: BoxFit.cover)
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: tokens.accent, size: 24),
                        const SizedBox(height: 4),
                        Text('ENCRYPTED', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
