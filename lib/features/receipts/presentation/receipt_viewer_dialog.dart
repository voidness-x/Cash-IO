import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/media/receipt_vault_service.dart';

class ReceiptViewerDialog extends StatefulWidget {
  final String filename;
  final String profileId;
  final VoidCallback? onDelete;

  const ReceiptViewerDialog({
    super.key,
    required this.filename,
    required this.profileId,
    this.onDelete,
  });

  @override
  State<ReceiptViewerDialog> createState() => _ReceiptViewerDialogState();
}

class _ReceiptViewerDialogState extends State<ReceiptViewerDialog> {
  Uint8List? _decryptedBytes;
  bool _isLoading = true;
  String? _error;
  int _rotationQuarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    final bytes = await ReceiptVaultService.instance.decryptReceiptBytes(
      filename: widget.filename,
      profileId: widget.profileId,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (bytes != null) {
          _decryptedBytes = bytes;
        } else {
          _error = 'Failed to decrypt receipt with current vault key.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? CashIOTokens.darkTextHigh : CashIOTokens.lightTextHigh;
    final mutedColor = isDark ? CashIOTokens.darkTextMuted : CashIOTokens.lightTextMuted;

    return Dialog(
      backgroundColor: isDark ? CashIOTokens.darkSurface : CashIOTokens.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
        side: BorderSide(color: isDark ? CashIOTokens.darkBorder : CashIOTokens.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CashIOTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: CashIOTokens.income, size: 20),
                    const SizedBox(width: CashIOTokens.space2),
                    Text(
                      'Encrypted Receipt',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.rotate_right_rounded),
                      tooltip: 'Rotate 90°',
                      onPressed: () {
                        setState(() {
                          _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Decrypted in ephemeral memory • Never written plaintext to disk',
              style: TextStyle(color: mutedColor, fontSize: 11),
            ),
            const SizedBox(height: CashIOTokens.space4),

            // Image Container
            Container(
              height: 320,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? CashIOTokens.darkBg : CashIOTokens.lightBg,
                borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                border: Border.all(color: isDark ? CashIOTokens.darkBorder : CashIOTokens.lightBorder),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : _error != null
                      ? Text(_error!, style: const TextStyle(color: CashIOTokens.expense, fontSize: 13))
                      : InteractiveViewer(
                          panEnabled: true,
                          minScale: 1.0,
                          maxScale: 5.0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                            child: RotatedBox(
                              quarterTurns: _rotationQuarterTurns,
                              child: Image.memory(
                                _decryptedBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: CashIOTokens.space4),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onDelete != null)
                  TextButton.icon(
                    onPressed: () async {
                      await ReceiptVaultService.instance.deleteReceipt(widget.filename);
                      widget.onDelete?.call();
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline, color: CashIOTokens.expense, size: 18),
                    label: const Text('Delete', style: TextStyle(color: CashIOTokens.expense)),
                  )
                else
                  const SizedBox.shrink(),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
