import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import 'create_vault_wizard.dart';

class VaultSwitcherSheet extends StatefulWidget {
  final VoidCallback? onAllVaultsDeleted;

  const VaultSwitcherSheet({super.key, this.onAllVaultsDeleted});

  /// Reusable PIN-verified permanent vault deletion dialog accessible from both
  /// VaultSwitcherSheet and Settings -> Danger Zone.
  static Future<VaultDeleteResult?> showDeleteVaultDialog(
    BuildContext context, {
    required String profileId,
    required String profileName,
    VoidCallback? onAllVaultsDeleted,
  }) {
    final tokens = context.tokens;
    final pinCtrl = TextEditingController();
    String? pinError;
    bool isDeleting = false;

    return showDialog<VaultDeleteResult>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: tokens.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: tokens.statusExpense.withValues(alpha: 0.45)),
              ),
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: tokens.statusExpense.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_forever_rounded, color: tokens.statusExpense, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delete "$profileName"?',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This permanently erases all accounts, transactions, budgets, and cryptographic keys for this vault. This action cannot be undone.',
                    style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ENTER 6-DIGIT VAULT PIN TO CONFIRM',
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('delete_vault_pin_field'),
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    autofocus: true,
                    style: GoogleFonts.jetBrainsMono(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      filled: true,
                      fillColor: tokens.bgCanvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.borderHairline),
                      ),
                      errorText: pinError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
                ),
                FilledButton(
                  key: const ValueKey('confirm_delete_vault_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.statusExpense,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final pin = pinCtrl.text.trim();
                          setDialogState(() {
                            isDeleting = true;
                            pinError = null;
                          });
                          final result = await VaultRepository.instance.deleteVault(profileId, pin: pin);
                          if (!ctx.mounted) return;
                          if (result.success) {
                            HapticFeedback.heavyImpact();
                            Navigator.pop(ctx, result);
                            if (!result.hasRemainingVaults) {
                              onAllVaultsDeleted?.call();
                            }
                          } else {
                            HapticFeedback.lightImpact();
                            setDialogState(() {
                              isDeleting = false;
                              pinError = result.message;
                            });
                          }
                        },
                  child: Text(
                    isDeleting ? 'DELETING...' : 'DELETE PERMANENTLY',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  State<VaultSwitcherSheet> createState() => _VaultSwitcherSheetState();
}

class _VaultSwitcherSheetState extends State<VaultSwitcherSheet> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await VaultRepository.instance.getAvailableProfiles();
    if (mounted) {
      setState(() {
        _profiles = list;
        _isLoading = false;
      });
    }
  }

  void _promptPinAndSwitch(BuildContext context, Map<String, dynamic> targetProfile) {
    final tokens = context.tokens;
    final pinCtrl = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: tokens.bgSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: tokens.borderHairline),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: tokens.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unlock ${targetProfile['name']}',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the 6-digit PIN for this cryptographic enclave.',
                    style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    autofocus: true,
                    style: GoogleFonts.jetBrainsMono(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      filled: true,
                      fillColor: tokens.bgCanvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.borderHairline),
                      ),
                      errorText: pinError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.accent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final pin = pinCtrl.text.trim();
                    final success = await VaultRepository.instance.switchVault(
                      targetProfile['id'] as String,
                      pin,
                    );
                    if (success) {
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Switched to vault: ${targetProfile['name']}',
                              style: GoogleFonts.mukta(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: tokens.statusIncome,
                          ),
                        );
                      }
                    } else {
                      setDialogState(() => pinError = 'Incorrect PIN. Verification failed.');
                    }
                  },
                  child: const Text('UNLOCK & SWITCH'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteVault(BuildContext context, Map<String, dynamic> profile) async {
    final tokens = context.tokens;
    final id = profile['id'] as String;
    final name = profile['name'] as String? ?? 'Encrypted Vault';

    final result = await VaultSwitcherSheet.showDeleteVaultDialog(
      context,
      profileId: id,
      profileName: name,
      onAllVaultsDeleted: () {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        widget.onAllVaultsDeleted?.call();
      },
    );

    if (result != null && result.success && context.mounted) {
      if (result.hasRemainingVaults) {
        await _loadProfiles();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.message,
                style: GoogleFonts.mukta(fontWeight: FontWeight.bold),
              ),
              backgroundColor: tokens.statusExpense,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;
    final activeId = repo.profileId;

    return Container(
      padding: EdgeInsets.all(tokens.space5),
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
            SizedBox(height: tokens.space4),

            // Title
            Row(
              children: [
                Icon(Icons.layers_outlined, color: tokens.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LOCAL CRYPTOGRAPHIC VAULTS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: tokens.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_profiles.length} Available',
                  style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Each vault is an air-gapped cryptographic enclave with an isolated database and PBKDF2 keys.',
              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
            ),
            SizedBox(height: tokens.space4),

            // Vaults List
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              ..._profiles.map((profile) {
                final id = profile['id'] as String;
                final name = profile['name'] as String? ?? 'Encrypted Vault';
                final curr = profile['currency'] as String? ?? 'USD';
                final isActive = id == activeId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isActive ? tokens.accent.withValues(alpha: 0.08) : tokens.bgCanvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? tokens.accent : tokens.borderHairline,
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isActive ? tokens.accent : tokens.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isActive ? Icons.lock_open_rounded : Icons.lock_outline,
                          color: isActive ? Colors.black : tokens.textSecondary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Currency: $curr • Profile ID: ${id.length > 12 ? id.substring(0, 12) : id}...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.accent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () => _promptPinAndSwitch(context, profile),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Switch →',
                                style: GoogleFonts.mukta(color: tokens.accent, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            key: ValueKey('delete_vault_$id'),
                            tooltip: 'Delete Vault',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: tokens.statusExpense.withValues(alpha: 0.85),
                            ),
                            onPressed: () => _handleDeleteVault(context, profile),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            SizedBox(height: tokens.space4),

            // Create New Vault Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.accent,
                  side: BorderSide(color: tokens.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  '+ CREATE NEW VAULT',
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                ),
                onPressed: () async {
                  final created = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => const CreateVaultWizard(),
                  );
                  if (created == true) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'New cryptographic vault initialized and activated!',
                            style: GoogleFonts.mukta(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: tokens.statusIncome,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
