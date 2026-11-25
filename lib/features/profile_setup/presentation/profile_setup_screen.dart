import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/security/bip39_wordlist.dart';
import '../../../core/security/hardware_vault_service.dart';
import '../../../core/widgets/cashio_logo.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onProfileCreated;

  const ProfileSetupScreen({super.key, required this.onProfileCreated});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  // Stages:
  // 0: Intro Splash (Cipher Logo + Tap/Swipe to Start)
  // 1: Vault Name & Base Currency
  // 2: Starting Cash, Bank Balance & Starter Budgets (Ease-In Step)
  // 3: 6-Digit PIN + Fingerprint Biometric Sign-In Toggle
  // 4: 12-Word Recovery Phrase (2-Column Clean Grid)
  // 5: Review Summary & Launch Vault
  int _currentStage = 0;
  bool _isEditingFromSummary = false;

  late final AnimationController _logoEntranceController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  static const String _targetLogoText = 'CASH-IO';
  String _currentDecryptedPrefix = '';
  String _currentFlickerSuffix = '';
  Timer? _cipherTimer;
  bool _isCipherFinished = false;

  late final AnimationController _oSpinController;
  bool _showSwipePrompt = false;
  late final AnimationController _swipePromptPulseController;

  // Step 1: Identity & Currency
  final TextEditingController _nameController = TextEditingController(text: 'Personal Vault');
  String _selectedCurrency = 'IQD';
  final bool _autoSyncFx = false;

  // Step 2: Initial Cash & Financial Setup
  final TextEditingController _startingCashCtrl = TextEditingController();
  final TextEditingController _startingBankCtrl = TextEditingController();
  final TextEditingController _emergencyGoalCtrl = TextEditingController();
  bool _createStarterEnvelopes = true;

  // Step 3: Security & Biometrics
  String _enteredPin = '';
  String _confirmedPin = '';
  bool _isConfirmingPin = false;
  bool _enableBiometrics = true;
  String? _pinError;

  // Step 4: Recovery Phrase
  late List<String> _recoveryWords;
  bool _backedUpPhrase = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _recoveryWords = Bip39Helper.generateMnemonic();

    _logoEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _logoEntranceController, curve: Curves.easeOutCubic),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoEntranceController, curve: const Interval(0.0, 0.8, curve: Curves.easeIn)),
    );

    _oSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _swipePromptPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _logoEntranceController.forward().then((_) {
      _startCipherAnimation();
    });
  }

  void _startCipherAnimation() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789#%&*@!';
    final rand = Random();
    int resolvedChars = 0;
    int tickCount = 0;

    _cipherTimer?.cancel();
    _cipherTimer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      tickCount++;
      if (tickCount % 5 == 0 && resolvedChars < _targetLogoText.length) {
        resolvedChars++;
      }

      final prefix = _targetLogoText.substring(0, resolvedChars);
      final remainingCount = _targetLogoText.length - resolvedChars;
      final suffixBuffer = StringBuffer();
      for (int i = 0; i < remainingCount; i++) {
        suffixBuffer.write(chars[rand.nextInt(chars.length)]);
      }

      setState(() {
        _currentDecryptedPrefix = prefix;
        _currentFlickerSuffix = suffixBuffer.toString();
      });

      if (resolvedChars >= _targetLogoText.length) {
        timer.cancel();
        setState(() {
          _isCipherFinished = true;
          _showSwipePrompt = true;
        });
        _oSpinController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _logoEntranceController.dispose();
    _oSpinController.dispose();
    _swipePromptPulseController.dispose();
    _cipherTimer?.cancel();
    _nameController.dispose();
    _startingCashCtrl.dispose();
    _startingBankCtrl.dispose();
    _emergencyGoalCtrl.dispose();
    super.dispose();
  }

  void _transitionToStage(int targetStage) {
    HapticFeedback.lightImpact();
    setState(() {
      _currentStage = targetStage;
    });
  }

  void _onSwipeUpTriggered() {
    if (_currentStage == 0) {
      HapticFeedback.mediumImpact();
      _transitionToStage(1);
    }
  }

  List<int> _quickChipsForCurrency(String currency) {
    if (currency == 'IQD') {
      return const [25000, 100000, 250000, 1000000];
    }
    return const [50, 100, 500, 1000];
  }

  String _formatQuickChip(int amount) {
    if (amount >= 1000000) return '+1M';
    if (amount >= 1000) return '+${(amount / 1000).toStringAsFixed(0)}K';
    return '+$amount';
  }

  void _incrementController(TextEditingController ctrl, int amount) {
    HapticFeedback.selectionClick();
    final raw = ctrl.text.replaceAll(',', '').trim();
    final current = double.tryParse(raw) ?? 0;
    final next = current + amount;
    ctrl.text = next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
    ctrl.selection = TextSelection.fromPosition(TextPosition(offset: ctrl.text.length));
    setState(() {});
  }

  void _onPinDigit(String digit) {
    if (!_isConfirmingPin) {
      if (_enteredPin.length < CashIOTokens.pinLength) {
        HapticFeedback.lightImpact();
        setState(() {
          _enteredPin += digit;
          _pinError = null;
        });
        if (_enteredPin.length == CashIOTokens.pinLength) {
          setState(() {
            _isConfirmingPin = true;
          });
        }
      }
    } else {
      if (_confirmedPin.length < CashIOTokens.pinLength) {
        HapticFeedback.lightImpact();
        setState(() {
          _confirmedPin += digit;
          _pinError = null;
        });
        if (_confirmedPin.length == CashIOTokens.pinLength) {
          if (_confirmedPin == _enteredPin) {
            HapticFeedback.mediumImpact();
            if (_isEditingFromSummary) {
              _isEditingFromSummary = false;
              _transitionToStage(5);
            } else {
              _transitionToStage(4);
            }
          } else {
            HapticFeedback.heavyImpact();
            setState(() {
              _pinError = 'PINs did not match. Please enter your 6-digit PIN again.';
              _enteredPin = '';
              _confirmedPin = '';
              _isConfirmingPin = false;
            });
          }
        }
      }
    }
  }

  void _onPinDelete() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isConfirmingPin) {
        if (_confirmedPin.isNotEmpty) {
          _confirmedPin = _confirmedPin.substring(0, _confirmedPin.length - 1);
        } else {
          _isConfirmingPin = false;
        }
      } else {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      }
    });
  }

  Future<void> _commitAndLaunchVault() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      final name = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Personal Vault';
      final effectivePin = _enteredPin.isNotEmpty ? _enteredPin : '123456';
      final startingCashCents = CurrencyUtils.parseToCents(_startingCashCtrl.text.trim());
      final startingBankCents = CurrencyUtils.parseToCents(_startingBankCtrl.text.trim());
      final goalTargetCents = CurrencyUtils.parseToCents(_emergencyGoalCtrl.text.trim());

      await HardwareVaultService.instance.setBiometricsEnabled(_enableBiometrics);

      await VaultRepository.instance.initializeProfile(
        name: name,
        currency: _selectedCurrency,
        onlineFx: _autoSyncFx,
        pin: effectivePin,
        mnemonic: _recoveryWords.join(' '),
      ).timeout(const Duration(seconds: 4), onTimeout: () {});

      if (startingCashCents > 0 ||
          startingBankCents > 0 ||
          _createStarterEnvelopes ||
          goalTargetCents > 0) {
        await VaultRepository.instance.setupInitialFinancialData(
          startingCashCents: startingCashCents,
          startingBankCents: startingBankCents,
          createStarterEnvelopes: _createStarterEnvelopes,
          emergencyGoalTargetCents: goalTargetCents,
        ).timeout(const Duration(seconds: 4), onTimeout: () {});
      }

      HapticFeedback.mediumImpact();
      widget.onProfileCreated();
    } catch (_) {
      if (mounted) {
        widget.onProfileCreated();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return FrostedScaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (_currentStage == 0 && details.primaryVelocity != null && details.primaryVelocity! < -120) {
            _onSwipeUpTriggered();
          }
        },
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: CashIOTokens.animSmooth,
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildCurrentStageView(tokens),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStageView(CashIOThemeExtension tokens) {
    switch (_currentStage) {
      case 0:
        return _buildStage0Intro(tokens);
      case 1:
        return _buildStage1IdentityAndCurrency(tokens);
      case 2:
        return _buildStage2InitialCashSetup(tokens);
      case 3:
        return _buildStage3PinAndBiometrics(tokens);
      case 4:
        return _buildStage4RecoverySeed(tokens);
      case 5:
        return _buildStage5Summary(tokens);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STAGE 0: Brand Intro Splash
  // ---------------------------------------------------------------------------
  Widget _buildStage0Intro(CashIOThemeExtension tokens) {
    return KeyedSubtree(
      key: const ValueKey('stage_0_intro'),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              AnimatedBuilder(
                animation: _logoEntranceController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    _buildAnimatedLogoTitle(tokens.textPrimary),
                    const SizedBox(height: CashIOTokens.space3),
                    Text(
                      'AIR-GAPPED ZERO-KNOWLEDGE LEDGER',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.mukta(
                        color: CashIOTokens.brand.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              AnimatedOpacity(
                opacity: _showSwipePrompt ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                child: AnimatedBuilder(
                  animation: _swipePromptPulseController,
                  builder: (context, child) {
                    final t = _swipePromptPulseController.value;
                    final dy = -6.0 * (0.5 - 0.5 * cos(t * 2 * pi));
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: child,
                    );
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onSwipeUpTriggered,
                      borderRadius: BorderRadius.circular(CashIOTokens.radiusPill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: tokens.bgSurface,
                          borderRadius: BorderRadius.circular(CashIOTokens.radiusPill),
                          border: Border.all(
                            color: CashIOTokens.brand.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                              color: CashIOTokens.brand,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Swipe up or tap to start',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.mukta(
                                  color: tokens.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogoTitle(Color textColor) {
    if (!_isCipherFinished) {
      return Text(
        '$_currentDecryptedPrefix$_currentFlickerSuffix',
        style: GoogleFonts.spaceGrotesk(
          color: textColor,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        ),
      );
    }

    return CashIOLogo(
      fontSize: 36,
      animateO: true,
      textColor: textColor,
      accentColor: CashIOTokens.brand,
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 1: Vault Name & Base Currency
  // ---------------------------------------------------------------------------
  Widget _buildStage1IdentityAndCurrency(CashIOThemeExtension tokens) {
    return KeyedSubtree(
      key: const ValueKey('stage_1_identity'),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: tokens.space5, vertical: tokens.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(1, 5, tokens),
                SizedBox(height: tokens.space3),
                Text(
                  'Name your vault & choose currency',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your accounts, budgets, and reports will default to this currency.',
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 14, height: 1.35),
                ),
                SizedBox(height: tokens.space5),

                Text(
                  'VAULT NAME',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Personal Vault, Family Budget',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                SizedBox(height: tokens.space5),

                Text(
                  'BASE CURRENCY',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = ((constraints.maxWidth - 10) / 2).clamp(130.0, 240.0);
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: CurrencyUtils.supportedCurrencies.map((c) {
                        final code = c['code']!;
                        final name = c['name']!;
                        final symbol = c['symbol']!;
                        final isSelected = _selectedCurrency == code;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCurrency = code);
                          },
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          child: Container(
                            width: cardWidth,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.accent.withValues(alpha: 0.16)
                                  : tokens.bgSurface,
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                              border: Border.all(
                                color: isSelected ? tokens.accent : tokens.borderHairline,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      code,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: isSelected ? tokens.accent : tokens.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        symbol,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.mukta(
                                          color: isSelected ? tokens.accent : tokens.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name,
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
                        );
                      }).toList(),
                    );
                  },
                ),
                SizedBox(height: tokens.space5),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      if (_isEditingFromSummary) {
                        _isEditingFromSummary = false;
                        _transitionToStage(5);
                      } else {
                        _transitionToStage(2);
                      }
                    },
                    child: Text(_isEditingFromSummary ? 'Save & Return' : 'Next: Starting Cash'),
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
  // STAGE 2: Starting Cash, Bank Balance & Starter Budgets (Ease-In Step)
  // ---------------------------------------------------------------------------
  Widget _buildStage2InitialCashSetup(CashIOThemeExtension tokens) {
    final quickChips = _quickChipsForCurrency(_selectedCurrency);

    return KeyedSubtree(
      key: const ValueKey('stage_2_cash_setup'),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: tokens.space5, vertical: tokens.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(2, 5, tokens),
                SizedBox(height: tokens.space3),
                Text(
                  'Set your starting cash & balances',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add the cash in your wallet and bank right now so your dashboard is ready to use immediately.',
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 14, height: 1.35),
                ),
                SizedBox(height: tokens.space4),

                // Cash Wallet
                Text(
                  'CASH IN WALLET ($_selectedCurrency)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _startingCashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '$_selectedCurrency ',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.wallet_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quickChips.map((amt) {
                    return ActionChip(
                      label: Text(
                        _formatQuickChip(amt),
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: tokens.accent),
                      ),
                      backgroundColor: tokens.bgSurface,
                      side: BorderSide(color: tokens.borderHairline),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _incrementController(_startingCashCtrl, amt),
                    );
                  }).toList(),
                ),
                SizedBox(height: tokens.space4),

                // Bank Balance
                Text(
                  'BANK OR CARD BALANCE (OPTIONAL)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _startingBankCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '$_selectedCurrency ',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                  ),
                ),
                SizedBox(height: tokens.space4),

                // Savings Goal Target
                Text(
                  'SAVINGS GOAL TARGET (OPTIONAL)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _emergencyGoalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.jetBrainsMono(color: tokens.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '$_selectedCurrency ',
                    hintText: _selectedCurrency == 'IQD' ? 'e.g. 1500000' : 'e.g. 1500',
                    prefixIcon: const Icon(Icons.shield_outlined, size: 20),
                  ),
                ),
                SizedBox(height: tokens.space3),

                Container(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      title: Text(
                        'Auto-create starter budget envelopes',
                        style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Pre-configures Essentials, Bills & Transport, and Personal envelopes',
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                      ),
                      value: _createStarterEnvelopes,
                      activeTrackColor: tokens.accent,
                      onChanged: (val) => setState(() => _createStarterEnvelopes = val),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space5),

                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _transitionToStage(1),
                      child: const Text('Back'),
                    ),
                    SizedBox(width: tokens.space3),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (_isEditingFromSummary) {
                            _isEditingFromSummary = false;
                            _transitionToStage(5);
                          } else {
                            _transitionToStage(3);
                          }
                        },
                        child: Text(_isEditingFromSummary ? 'Save & Return' : 'Next: Security'),
                      ),
                    ),
                  ],
                ),
                if (!_isEditingFromSummary)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        _startingCashCtrl.clear();
                        _startingBankCtrl.clear();
                        _emergencyGoalCtrl.clear();
                        _transitionToStage(3);
                      },
                      child: Text(
                        'Skip for now (start with 0 balance)',
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                      ),
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
  // STAGE 3: 6-Digit PIN & Fingerprint Biometric Unlock
  // ---------------------------------------------------------------------------
  Widget _buildStage3PinAndBiometrics(CashIOThemeExtension tokens) {
    final currentInput = _isConfirmingPin ? _confirmedPin : _enteredPin;

    return KeyedSubtree(
      key: const ValueKey('stage_3_pin'),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: tokens.space5, vertical: tokens.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepIndicator(3, 5, tokens),
                SizedBox(height: tokens.space3),
                Text(
                  _isConfirmingPin ? 'Confirm your 6-digit PIN' : 'Create a 6-digit Master PIN',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isConfirmingPin
                      ? 'Enter the same 6 digits to verify'
                      : 'Protects your vault alongside fingerprint unlock',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                ),
                if (_pinError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _pinError!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mukta(color: CashIOTokens.expense, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
                SizedBox(height: tokens.space4),

                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(CashIOTokens.pinLength, (index) {
                    final isFilled = index < currentInput.length;
                    return AnimatedContainer(
                      duration: CashIOTokens.animFast,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isFilled ? tokens.accent : tokens.bgSurfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFilled ? tokens.accent : tokens.borderHairline,
                          width: 1.4,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: tokens.space4),

                // Fingerprint Toggle
                Container(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      dense: true,
                      secondary: Icon(Icons.fingerprint_rounded, color: tokens.accent, size: 22),
                      title: Text(
                        'Enable Fingerprint Sign-In',
                        style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Prompt fingerprint sensor automatically on app launch',
                        style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                      ),
                      value: _enableBiometrics,
                      activeTrackColor: tokens.accent,
                      onChanged: (val) => setState(() => _enableBiometrics = val),
                    ),
                  ),
                ),
                SizedBox(height: tokens.space4),

                // Responsive Keypad
                LayoutBuilder(
                  builder: (context, constraints) {
                    final keyW = ((constraints.maxWidth - 28) / 3).clamp(68.0, 88.0);
                    return _buildSharpKeypad(tokens, keyWidth: keyW);
                  },
                ),
                SizedBox(height: tokens.space2),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _enteredPin = '';
                      _confirmedPin = '';
                      _isConfirmingPin = false;
                    });
                    _transitionToStage(2);
                  },
                  child: Text('Back to Starting Cash', style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 4: 12-Word Recovery Phrase (Spacious 2-Column Grid)
  // ---------------------------------------------------------------------------
  Widget _buildStage4RecoverySeed(CashIOThemeExtension tokens) {
    return KeyedSubtree(
      key: const ValueKey('stage_4_recovery'),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: tokens.space5, vertical: tokens.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(4, 5, tokens),
                SizedBox(height: tokens.space3),
                Text(
                  'Save your 12-word recovery key',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cash-IO stores everything locally on your phone. Keep this recovery phrase safe in case you ever forget your PIN.',
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13, height: 1.35),
                ),
                SizedBox(height: tokens.space4),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _recoveryWords.length,
                  itemBuilder: (ctx, i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: tokens.bgSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${(i + 1).toString().padLeft(2, '0')}. ${_recoveryWords[i]}',
                          style: GoogleFonts.jetBrainsMono(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: tokens.space3),

                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _recoveryWords.join(' ')));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recovery phrase copied to clipboard.'),
                            backgroundColor: CashIOTokens.income,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Phrase'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _recoveryWords = Bip39Helper.generateMnemonic();
                        });
                        HapticFeedback.selectionClick();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Generate New'),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space2),

                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _backedUpPhrase,
                  activeColor: tokens.accent,
                  title: Text(
                    'I have saved or copied my 12-word recovery key.',
                    style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) => setState(() => _backedUpPhrase = val ?? false),
                ),
                SizedBox(height: tokens.space4),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _backedUpPhrase ? () => _transitionToStage(5) : null,
                    child: const Text('Review & Finish'),
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
  // STAGE 5: Final Summary & Launch
  // ---------------------------------------------------------------------------
  Widget _buildStage5Summary(CashIOThemeExtension tokens) {
    final cashCents = CurrencyUtils.parseToCents(_startingCashCtrl.text.trim());
    final bankCents = CurrencyUtils.parseToCents(_startingBankCtrl.text.trim());
    final totalOpeningCents = cashCents + bankCents;

    return KeyedSubtree(
      key: const ValueKey('stage_5_summary'),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: tokens.space5, vertical: tokens.space4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(5, 5, tokens),
                SizedBox(height: tokens.space3),
                Text(
                  'Ready to launch your vault',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review your setup below or tap Edit on any row to adjust.',
                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 13),
                ),
                SizedBox(height: tokens.space4),

                Container(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        icon: Icons.person_outline,
                        label: 'Vault & Currency',
                        value: '${_nameController.text.trim().isEmpty ? "Personal Vault" : _nameController.text.trim()} • $_selectedCurrency',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          _transitionToStage(1);
                        },
                        tokens: tokens,
                      ),
                      Divider(color: tokens.borderHairline, height: 1),
                      _buildSummaryRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Starting Funds & Budgets',
                        value: totalOpeningCents > 0
                            ? '${CurrencyUtils.format(totalOpeningCents, currency: _selectedCurrency)}${_createStarterEnvelopes ? " • 50/30/20 Envelopes" : ""}'
                            : (_createStarterEnvelopes ? '0 Balance • Starter Envelopes Ready' : 'Starting at 0 Balance'),
                        onEdit: () {
                          _isEditingFromSummary = true;
                          _transitionToStage(2);
                        },
                        tokens: tokens,
                      ),
                      Divider(color: tokens.borderHairline, height: 1),
                      _buildSummaryRow(
                        icon: Icons.fingerprint_rounded,
                        label: 'Unlock Protection',
                        value: _enableBiometrics ? 'Fingerprint + 6-Digit PIN' : '6-Digit Master PIN',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          setState(() {
                            _enteredPin = '';
                            _confirmedPin = '';
                            _isConfirmingPin = false;
                          });
                          _transitionToStage(3);
                        },
                        tokens: tokens,
                      ),
                      Divider(color: tokens.borderHairline, height: 1),
                      _buildSummaryRow(
                        icon: Icons.vpn_key_outlined,
                        label: 'Recovery Phrase',
                        value: '12 Words Saved',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          _transitionToStage(4);
                        },
                        tokens: tokens,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.space5),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isInitializing ? null : _commitAndLaunchVault,
                    icon: _isInitializing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: tokens.bgPrimary),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(_isInitializing ? 'OPENING VAULT...' : 'LAUNCH MY VAULT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onEdit,
    required CashIOThemeExtension tokens,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space3),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.accent),
          SizedBox(width: tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text('Edit', style: GoogleFonts.mukta(color: tokens.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total, CashIOThemeExtension tokens) {
    return Row(
      children: [
        Text(
          'STEP $current OF $total',
          style: GoogleFonts.spaceGrotesk(
            color: tokens.accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        SizedBox(width: tokens.space3),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 3,
              backgroundColor: tokens.borderHairline,
              valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSharpKeypad(CashIOThemeExtension tokens, {required double keyWidth}) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], tokens, keyWidth: keyWidth),
        const SizedBox(height: 8),
        _buildKeypadRow(['4', '5', '6'], tokens, keyWidth: keyWidth),
        const SizedBox(height: 8),
        _buildKeypadRow(['7', '8', '9'], tokens, keyWidth: keyWidth),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: keyWidth + 8),
            _buildDigitKey('0', tokens, keyWidth: keyWidth),
            _buildDeleteKey(tokens, keyWidth: keyWidth),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, CashIOThemeExtension tokens, {required double keyWidth}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) => _buildDigitKey(d, tokens, keyWidth: keyWidth)).toList(),
    );
  }

  Widget _buildDigitKey(String digit, CashIOThemeExtension tokens, {required double keyWidth}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: InkWell(
          onTap: () => _onPinDigit(digit),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Container(
            width: keyWidth,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Text(
              digit,
              style: GoogleFonts.jetBrainsMono(
                color: tokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey(CashIOThemeExtension tokens, {required double keyWidth}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: InkWell(
          onTap: _onPinDelete,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Container(
            width: keyWidth,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Icon(Icons.backspace_outlined, size: 20, color: tokens.accent),
          ),
        ),
      ),
    );
  }
}
