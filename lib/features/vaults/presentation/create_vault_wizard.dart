import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/security/bip39_wordlist.dart';

class CreateVaultWizard extends StatefulWidget {
  const CreateVaultWizard({super.key});

  @override
  State<CreateVaultWizard> createState() => _CreateVaultWizardState();
}

class _CreateVaultWizardState extends State<CreateVaultWizard> {
  int _currentStep = 0;
  final _nameCtrl = TextEditingController(text: 'Secondary Vault');
  String _selectedCurrency = 'USD';
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  late final List<String> _mnemonicWords;
  bool _seedConfirmed = false;
  bool _isCreating = false;
  String? _error;

  final List<String> _purposeSuggestions = [
    'Business Operations',
    'Emergency Reserves',
    'Travel Fund',
    'Decoy Vault',
    'Secret Savings',
  ];

  final List<String> _currencies = ['USD', 'IQD', 'EUR', 'GBP', 'SAR', 'AED'];

  @override
  void initState() {
    super.initState();
    _mnemonicWords = Bip39Helper.generateMnemonic();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitVault() async {
    if (!_seedConfirmed) {
      setState(() => _error = 'Please confirm you have backed up your recovery seed phrase.');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      await VaultRepository.instance.createSecondaryVault(
        name: _nameCtrl.text.trim().isEmpty ? 'Secondary Vault' : _nameCtrl.text.trim(),
        currency: _selectedCurrency,
        pin: _pinCtrl.text.trim(),
        mnemonic: _mnemonicWords.join(' '),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _error = 'Failed to initialize vault: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Dialog(
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: tokens.borderHairline),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: EdgeInsets.all(tokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, color: tokens.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'NEW CRYPTOGRAPHIC VAULT',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Step indicator
              Row(
                children: List.generate(4, (idx) {
                  final isActive = idx <= _currentStep;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(right: idx < 3 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: isActive ? tokens.accent : tokens.borderHairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: tokens.statusExpense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.statusExpense.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.mukta(color: tokens.statusExpense, fontSize: 12),
                  ),
                ),
              ],

              // Content based on _currentStep
              Expanded(
                child: SingleChildScrollView(
                  child: _buildStepContent(tokens),
                ),
              ),

              // Navigation Buttons
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: Text('Back', style: TextStyle(color: tokens.textSecondary)),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isCreating ? null : _handleNext,
                    child: _isCreating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : Text(
                            _currentStep == 3 ? 'INITIALIZE VAULT' : 'NEXT →',
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNext() {
    setState(() => _error = null);
    if (_currentStep == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Please enter a vault name.');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      final pin = _pinCtrl.text.trim();
      final confirm = _confirmPinCtrl.text.trim();
      if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
        setState(() => _error = 'PIN must be exactly 6 numeric digits.');
        return;
      }
      if (pin != confirm) {
        setState(() => _error = 'PINs do not match. Please re-enter.');
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      _submitVault();
    }
  }

  Widget _buildStepContent(CashIOThemeExtension tokens) {
    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 1: Vault Name & Purpose', style: GoogleFonts.spaceGrotesk(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Give this cryptographic enclave a distinct identifier.', style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Vault Title',
                labelStyle: TextStyle(color: tokens.textTertiary),
                filled: true,
                fillColor: tokens.bgCanvas,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
              ),
            ),
            const SizedBox(height: 16),
            Text('QUICK SUGGESTIONS', style: GoogleFonts.spaceGrotesk(color: tokens.textTertiary, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _purposeSuggestions.map((p) {
                return ActionChip(
                  label: Text(p, style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 12)),
                  backgroundColor: tokens.bgCanvas,
                  side: BorderSide(color: tokens.borderHairline),
                  onPressed: () => setState(() => _nameCtrl.text = p),
                );
              }).toList(),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 2: Base Accounting Currency', style: GoogleFonts.spaceGrotesk(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Choose the primary operational currency for this ledger.', style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _currencies.map((curr) {
                final isSelected = curr == _selectedCurrency;
                return ChoiceChip(
                  label: Text(
                    curr,
                    style: GoogleFonts.spaceGrotesk(
                      color: isSelected ? Colors.black : tokens.textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: tokens.accent,
                  backgroundColor: tokens.bgCanvas,
                  side: BorderSide(color: isSelected ? tokens.accent : tokens.borderHairline),
                  onSelected: (_) => setState(() => _selectedCurrency = curr),
                );
              }).toList(),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 3: Isolated 6-Digit PIN', style: GoogleFonts.spaceGrotesk(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('This PIN derives a unique PBKDF2 hardware enclave key separate from other vaults.', style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 18, letterSpacing: 6),
              decoration: InputDecoration(
                labelText: 'Create 6-Digit PIN',
                filled: true,
                fillColor: tokens.bgCanvas,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 18, letterSpacing: 6),
              decoration: InputDecoration(
                labelText: 'Confirm 6-Digit PIN',
                filled: true,
                fillColor: tokens.bgCanvas,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tokens.borderHairline)),
              ),
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 4: Cryptographic Recovery Seed', style: GoogleFonts.spaceGrotesk(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Write down these 12 words in order. Never share them with anyone.', style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.bgCanvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mnemonicWords.asMap().entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.bgSurface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.borderHairline),
                    ),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _mnemonicWords.join(' ')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Seed phrase copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy Seed'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _seedConfirmed,
              activeColor: tokens.accent,
              title: Text(
                'I have securely recorded these 12 recovery words.',
                style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 12),
              ),
              onChanged: (val) => setState(() => _seedConfirmed = val ?? false),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
