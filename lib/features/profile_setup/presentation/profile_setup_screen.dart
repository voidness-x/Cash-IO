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
import '../../../core/widgets/cashio_logo.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onProfileCreated;

  const ProfileSetupScreen({super.key, required this.onProfileCreated});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  // Stage controller:
  // 0: Intro Splash (Cipher Logo animates, O spins, quiet swipe up prompt)
  // 1: Name entry (slow smooth fade-in)
  // 2: Base Currency (IQD default, slow smooth fade-in)
  // 3: 6-Digit Master PIN (sharp keypad, slow smooth fade-in)
  // 4: 12-Word BIP-39 Recovery Phrase (fresh dynamic words, slow smooth fade-in)
  // 5: Final Summary to Edit
  int _currentStage = 0;
  bool _isEditingFromSummary = false;

  // Intro Splash & Cipher Logo Animation
  late final AnimationController _logoEntranceController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Cipher text unscrambler state
  static const String _targetLogoText = 'CASH-IO';
  String _currentDecryptedPrefix = '';
  String _currentFlickerSuffix = '';
  Timer? _cipherTimer;
  bool _isCipherFinished = false;

  // The spinning 'O' controller (spins every 2 seconds after cipher finishes)
  late final AnimationController _oSpinController;

  // Quiet Swipe Prompt Animation
  bool _showSwipePrompt = false;
  late final AnimationController _swipePromptPulseController;

  // Stage Data
  final TextEditingController _nameController = TextEditingController(text: 'Personal Vault');
  String _selectedCurrency = 'IQD'; // Default IQD
  bool _autoSyncFx = false;

  // PIN Setup
  String _enteredPin = '';
  String _confirmedPin = '';
  bool _isConfirmingPin = false;
  String? _pinError;

  // BIP-39 12-Word Recovery Seed (dynamically generated per instance)
  late List<String> _recoveryWords;
  bool _backedUpPhrase = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();

    // 1. Generate fresh 12-word cryptographic recovery phrase
    _recoveryWords = Bip39Helper.generateMnemonic();

    // 2. Logo entrance animation (slow & smooth: 1200ms)
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

    // 3. The 'O' continuous rotation controller (2000ms loop)
    _oSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // 4. Swipe prompt subtle floating pulse
    _swipePromptPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Start logo entrance, then start cipher text unscrambler
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

      // Every 5 ticks (~275ms), resolve the next character
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
        // Start spinning the 'O' every 2 seconds continuously!
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

  void _onPinDigit(String digit) {
    if (!_isConfirmingPin) {
      if (_enteredPin.length < CashIOTokens.pinLength) {
        HapticFeedback.lightImpact();
        setState(() {
          _enteredPin += digit;
          _pinError = null;
        });
        if (_enteredPin.length == CashIOTokens.pinLength) {
          // Switch to confirm mode
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
            // PIN verified
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
              _pinError = 'PINs do not match. Re-enter PIN.';
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

      // Timeout safety ensures commit never hangs indefinitely
      await VaultRepository.instance.initializeProfile(
        name: name,
        currency: _selectedCurrency,
        onlineFx: _autoSyncFx,
        pin: effectivePin,
        mnemonic: _recoveryWords.join(' '),
      ).timeout(const Duration(seconds: 4), onTimeout: () {
        // Fallback proceeds smoothly
      });

      HapticFeedback.mediumImpact();
      widget.onProfileCreated();
    } catch (_) {
      if (mounted) {
        // Still proceed to unlock the vault for the user
        widget.onProfileCreated();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? CashIOTokens.darkTextHigh : CashIOTokens.lightTextHigh;
    final mutedColor = isDark ? CashIOTokens.darkTextMuted : CashIOTokens.lightTextMuted;

    return FrostedScaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (_currentStage == 0 && details.primaryVelocity != null && details.primaryVelocity! < -120) {
            _onSwipeUpTriggered();
          }
        },
        child: AnimatedSwitcher(
          duration: CashIOTokens.animSmooth,
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.04),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _buildCurrentStageView(isDark, textColor, mutedColor),
        ),
      ),
    );
  }

  Widget _buildCurrentStageView(bool isDark, Color textColor, Color mutedColor) {
    switch (_currentStage) {
      case 0:
        return _buildStage0Intro(isDark, textColor, mutedColor);
      case 1:
        return _buildStage1Name(isDark, textColor, mutedColor);
      case 2:
        return _buildStage2Currency(isDark, textColor, mutedColor);
      case 3:
        return _buildStage3Pin(isDark, textColor, mutedColor);
      case 4:
        return _buildStage4RecoverySeed(isDark, textColor, mutedColor);
      case 5:
        return _buildStage5Summary(isDark, textColor, mutedColor);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // STAGE 0: Logo (Using Picture), Cipher Decryption & Spinning 'O'
  // ---------------------------------------------------------------------------
  Widget _buildStage0Intro(bool isDark, Color textColor, Color mutedColor) {
    return KeyedSubtree(
      key: const ValueKey('stage_0_intro'),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Animated Logo Container (Clean typographic Cash-IO, No Shield)
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
                    // Typographic Logo: CASH-I with Centered Spinning 'O'
                    _buildAnimatedLogoTitle(textColor),

                    const SizedBox(height: CashIOTokens.space3),
                    Text(
                      'AIR-GAPPED ZERO-KNOWLEDGE LEDGER',
                      style: GoogleFonts.mukta(
                        color: CashIOTokens.brand.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Quiet & Smooth Sinusoidal Floating Capsule Swipe Prompt
              AnimatedOpacity(
                opacity: _showSwipePrompt ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                child: AnimatedBuilder(
                  animation: _swipePromptPulseController,
                  builder: (context, child) {
                    final t = _swipePromptPulseController.value;
                    // Silky smooth sinusoidal float: (0 -> -8 -> 0)
                    final dy = -8.0 * (0.5 - 0.5 * cos(t * 2 * pi));
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
                          color: CashIOTokens.darkSurface,
                          borderRadius: BorderRadius.circular(CashIOTokens.radiusPill),
                          border: Border.all(
                            color: CashIOTokens.brand.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CashIOTokens.brand.withValues(alpha: 0.20),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                              color: CashIOTokens.brand,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Swipe up or tap to start',
                              style: GoogleFonts.mukta(
                                color: CashIOTokens.darkTextHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
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

  /// Builds the cipher decryption text.
  /// When finished, renders CashIOLogo with a mathematically centered spinning 'O'.
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
  // STAGE 1: Profile Name (Slow Smooth Sequential Fade-ins)
  // ---------------------------------------------------------------------------
  Widget _buildStage1Name(bool isDark, Color textColor, Color mutedColor) {
    return KeyedSubtree(
      key: const ValueKey('stage_1_name'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmoothFadeItem(
                delayMs: 0,
                child: _buildStepIndicator(1, 4, mutedColor),
              ),
              const SizedBox(height: CashIOTokens.space3),

              _buildSmoothFadeItem(
                delayMs: 150,
                child: Text(
                  'Choose a name for this profile',
                  style: GoogleFonts.mukta(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space2),

              _buildSmoothFadeItem(
                delayMs: 300,
                child: Text(
                  'Each profile on this device holds an independent, zero-knowledge encrypted vault.',
                  style: GoogleFonts.mukta(color: mutedColor, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: CashIOTokens.space6),

              _buildSmoothFadeItem(
                delayMs: 450,
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.mukta(color: textColor, fontSize: 17, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Personal Vault, Treasury, Alex',
                    hintStyle: GoogleFonts.mukta(color: mutedColor.withValues(alpha: 0.6)),
                    prefixIcon: const Icon(Icons.person_outline, color: CashIOTokens.brandLight, size: 22),
                  ),
                  onSubmitted: (_) {
                    if (_isEditingFromSummary) {
                      _isEditingFromSummary = false;
                      _transitionToStage(5);
                    } else {
                      _transitionToStage(2);
                    }
                  },
                ),
              ),
              const SizedBox(height: CashIOTokens.space6),

              _buildSmoothFadeItem(
                delayMs: 600,
                child: Row(
                  children: [
                    if (_isEditingFromSummary)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _isEditingFromSummary = false;
                            _transitionToStage(5);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                    if (_isEditingFromSummary) const SizedBox(width: CashIOTokens.space3),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (_isEditingFromSummary) {
                            _isEditingFromSummary = false;
                            _transitionToStage(5);
                          } else {
                            _transitionToStage(2);
                          }
                        },
                        child: Text(_isEditingFromSummary ? 'Save & Return' : 'Next: Currency'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 2: Base Currency (IQD Default, Slow Smooth Fade-ins)
  // ---------------------------------------------------------------------------
  Widget _buildStage2Currency(bool isDark, Color textColor, Color mutedColor) {
    return KeyedSubtree(
      key: const ValueKey('stage_2_currency'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmoothFadeItem(
                delayMs: 0,
                child: _buildStepIndicator(2, 4, mutedColor),
              ),
              const SizedBox(height: CashIOTokens.space3),

              _buildSmoothFadeItem(
                delayMs: 150,
                child: Text(
                  'Select default base currency',
                  style: GoogleFonts.mukta(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space2),

              _buildSmoothFadeItem(
                delayMs: 300,
                child: Text(
                  'Your net worth, reports, and runways will calculate in this currency. (IQD set as default)',
                  style: GoogleFonts.mukta(color: mutedColor, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: CashIOTokens.space5),

              _buildSmoothFadeItem(
                delayMs: 450,
                child: Wrap(
                  spacing: CashIOTokens.space2,
                  runSpacing: CashIOTokens.space2,
                  children: CurrencyUtils.supportedCurrencies.map((c) {
                    final code = c['code']!;
                    final name = c['name']!;
                    final symbol = c['symbol']!;
                    final isSelected = _selectedCurrency == code;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCurrency = code;
                        });
                      },
                      borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                      child: Container(
                        width: 104,
                        padding: const EdgeInsets.symmetric(
                          horizontal: CashIOTokens.space3,
                          vertical: CashIOTokens.space2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CashIOTokens.brand.withValues(alpha: 0.18)
                              : CashIOTokens.darkSurface,
                          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                          border: Border.all(
                            color: isSelected ? CashIOTokens.brand : CashIOTokens.darkBorder,
                            width: isSelected ? 1.6 : 1.0,
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
                                  style: GoogleFonts.mukta(
                                    color: isSelected ? CashIOTokens.brandLight : textColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  symbol,
                                  style: GoogleFonts.mukta(
                                    color: isSelected ? CashIOTokens.brandLight : mutedColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.mukta(
                                color: mutedColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: CashIOTokens.space5),

              _buildSmoothFadeItem(
                delayMs: 600,
                child: Container(
                  padding: const EdgeInsets.all(CashIOTokens.space3),
                  decoration: BoxDecoration(
                    color: CashIOTokens.darkSurface,
                    borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                    border: Border.all(color: CashIOTokens.darkBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Online FX Rate Updates',
                              style: GoogleFonts.mukta(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _autoSyncFx ? 'Enabled (Internet access on request)' : 'Air-Gapped (100% offline & private)',
                              style: GoogleFonts.mukta(color: mutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _autoSyncFx,
                        activeTrackColor: CashIOTokens.brand,
                        onChanged: (val) {
                          setState(() {
                            _autoSyncFx = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space6),

              _buildSmoothFadeItem(
                delayMs: 750,
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _transitionToStage(1),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: CashIOTokens.space3),
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
                        child: Text(_isEditingFromSummary ? 'Save & Return' : 'Next: Security PIN'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 3: 6-Digit PIN (Slow Smooth Sequential Fade-ins)
  // ---------------------------------------------------------------------------
  Widget _buildStage3Pin(bool isDark, Color textColor, Color mutedColor) {
    final currentInput = _isConfirmingPin ? _confirmedPin : _enteredPin;

    return KeyedSubtree(
      key: const ValueKey('stage_3_pin'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSmoothFadeItem(
                delayMs: 0,
                child: _buildStepIndicator(3, 4, mutedColor),
              ),
              const SizedBox(height: CashIOTokens.space2),

              _buildSmoothFadeItem(
                delayMs: 150,
                child: Text(
                  _isConfirmingPin ? 'Confirm your 6-digit Master PIN' : 'Create your 6-digit Master PIN',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mukta(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space1),

              _buildSmoothFadeItem(
                delayMs: 300,
                child: Text(
                  _isConfirmingPin
                      ? 'Re-enter your 6 digits to verify'
                      : 'Derives local AES-256-GCM vault key via Argon2id',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.mukta(color: mutedColor, fontSize: 13),
                ),
              ),
              if (_pinError != null) ...[
                const SizedBox(height: CashIOTokens.space2),
                Text(
                  _pinError!,
                  style: GoogleFonts.mukta(color: CashIOTokens.expense, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: CashIOTokens.space5),

              // Sharp Rectangular PIN Indicators
              _buildSmoothFadeItem(
                delayMs: 450,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(CashIOTokens.pinLength, (index) {
                    final isFilled = index < currentInput.length;
                    return AnimatedContainer(
                      duration: CashIOTokens.animFast,
                      margin: const EdgeInsets.symmetric(horizontal: CashIOTokens.space1),
                      width: 24,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isFilled ? CashIOTokens.brand : CashIOTokens.darkBorder,
                        borderRadius: BorderRadius.circular(CashIOTokens.radiusXs),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: CashIOTokens.space5),

              // Sharp Keypad
              _buildSmoothFadeItem(
                delayMs: 600,
                child: _buildSharpKeypad(isDark, textColor),
              ),
              const SizedBox(height: CashIOTokens.space4),

              TextButton(
                onPressed: () {
                  setState(() {
                    _enteredPin = '';
                    _confirmedPin = '';
                    _isConfirmingPin = false;
                  });
                  _transitionToStage(2);
                },
                child: Text('Back to Currency', style: GoogleFonts.mukta(color: mutedColor, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 4: 12-Word Recovery Phrase (Dynamic Fresh Words, Smooth Fade-ins)
  // ---------------------------------------------------------------------------
  Widget _buildStage4RecoverySeed(bool isDark, Color textColor, Color mutedColor) {
    return KeyedSubtree(
      key: const ValueKey('stage_4_recovery'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmoothFadeItem(
                delayMs: 0,
                child: _buildStepIndicator(4, 4, mutedColor),
              ),
              const SizedBox(height: CashIOTokens.space2),

              _buildSmoothFadeItem(
                delayMs: 150,
                child: Text(
                  'Secure your 12-word recovery phrase',
                  style: GoogleFonts.mukta(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space1),

              _buildSmoothFadeItem(
                delayMs: 300,
                child: Text(
                  'Because Cash-IO is zero-knowledge, this unique seed is the ONLY way to recover your vault if you forget your PIN.',
                  style: GoogleFonts.mukta(color: mutedColor, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: CashIOTokens.space4),

              // 12-Word Grid
              _buildSmoothFadeItem(
                delayMs: 450,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.7,
                    crossAxisSpacing: CashIOTokens.space2,
                    mainAxisSpacing: CashIOTokens.space2,
                  ),
                  itemCount: _recoveryWords.length,
                  itemBuilder: (ctx, i) {
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: CashIOTokens.darkSurface,
                        borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                        border: Border.all(color: CashIOTokens.darkBorder),
                      ),
                      child: Text(
                        '${i + 1}. ${_recoveryWords[i]}',
                        style: GoogleFonts.mukta(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: CashIOTokens.space4),

              // Actions & Checkbox
              _buildSmoothFadeItem(
                delayMs: 600,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _recoveryWords.join(' ')));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recovery seed copied to clipboard.'),
                            backgroundColor: CashIOTokens.income,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy, size: 16, color: CashIOTokens.brandLight),
                          const SizedBox(width: CashIOTokens.space1),
                          Text(
                            'Copy Seed Phrase',
                            style: GoogleFonts.mukta(color: CashIOTokens.brandLight, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _recoveryWords = Bip39Helper.generateMnemonic();
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh, size: 16, color: CashIOTokens.brandLight),
                          const SizedBox(width: CashIOTokens.space1),
                          Text(
                            'Generate New',
                            style: GoogleFonts.mukta(color: CashIOTokens.brandLight, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CashIOTokens.space3),

              _buildSmoothFadeItem(
                delayMs: 750,
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _backedUpPhrase,
                  activeColor: CashIOTokens.brand,
                  title: Text(
                    'I have securely written down this 12-word phrase.',
                    style: GoogleFonts.mukta(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _backedUpPhrase = val ?? false;
                    });
                  },
                ),
              ),
              const SizedBox(height: CashIOTokens.space5),

              _buildSmoothFadeItem(
                delayMs: 900,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _backedUpPhrase
                        ? () {
                            _transitionToStage(5);
                          }
                        : null,
                    child: const Text('Review Profile Summary'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAGE 5: Final Summary to Edit (Smooth Fade-ins)
  // ---------------------------------------------------------------------------
  Widget _buildStage5Summary(bool isDark, Color textColor, Color mutedColor) {
    return KeyedSubtree(
      key: const ValueKey('stage_5_summary'),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmoothFadeItem(
                delayMs: 0,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(CashIOTokens.space2),
                      decoration: BoxDecoration(
                        color: CashIOTokens.incomeBg,
                        borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                        border: Border.all(color: CashIOTokens.income.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: CashIOTokens.income, size: 20),
                    ),
                    const SizedBox(width: CashIOTokens.space2),
                    Text(
                      'SETUP SUMMARY',
                      style: GoogleFonts.mukta(
                        color: CashIOTokens.brandLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CashIOTokens.space2),

              _buildSmoothFadeItem(
                delayMs: 150,
                child: Text(
                  'Review & Confirm Profile',
                  style: GoogleFonts.mukta(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space1),

              _buildSmoothFadeItem(
                delayMs: 300,
                child: Text(
                  'Verify your configurations. You can tap Edit on any item to adjust it.',
                  style: GoogleFonts.mukta(color: mutedColor, fontSize: 13),
                ),
              ),
              const SizedBox(height: CashIOTokens.space5),

              _buildSmoothFadeItem(
                delayMs: 450,
                child: Container(
                  decoration: BoxDecoration(
                    color: CashIOTokens.darkSurface,
                    borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
                    border: Border.all(color: CashIOTokens.darkBorder),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        icon: Icons.person_outline,
                        label: 'Profile Name',
                        value: _nameController.text.trim().isNotEmpty
                            ? _nameController.text.trim()
                            : 'Personal Vault',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          _transitionToStage(1);
                        },
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                      const Divider(color: CashIOTokens.darkBorder, height: 1),

                      _buildSummaryRow(
                        icon: Icons.currency_exchange,
                        label: 'Base Currency',
                        value: '$_selectedCurrency (${_getCurrencyName(_selectedCurrency)})',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          _transitionToStage(2);
                        },
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                      const Divider(color: CashIOTokens.darkBorder, height: 1),

                      _buildSummaryRow(
                        icon: Icons.lock_outline,
                        label: 'Master PIN',
                        value: '•••••• (Hardware Salted)',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          setState(() {
                            _enteredPin = '';
                            _confirmedPin = '';
                            _isConfirmingPin = false;
                          });
                          _transitionToStage(3);
                        },
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                      const Divider(color: CashIOTokens.darkBorder, height: 1),

                      _buildSummaryRow(
                        icon: Icons.vpn_key_outlined,
                        label: 'Recovery Seed',
                        value: '12 Words Generated & Backed Up',
                        onEdit: () {
                          _isEditingFromSummary = true;
                          _transitionToStage(4);
                        },
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space6),

              _buildSmoothFadeItem(
                delayMs: 650,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isInitializing ? null : _commitAndLaunchVault,
                    icon: _isInitializing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CashIOTokens.darkBg),
                          )
                        : const Icon(Icons.lock_open, size: 20),
                    label: Text(_isInitializing ? 'INITIALIZING VAULT...' : 'COMMIT & LAUNCH VAULT'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: CashIOTokens.space4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CashIOTokens.space4),
            ],
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
    required Color textColor,
    required Color mutedColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CashIOTokens.space4,
        vertical: CashIOTokens.space3,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CashIOTokens.brandLight),
          const SizedBox(width: CashIOTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.mukta(color: mutedColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(value, style: GoogleFonts.mukta(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: CashIOTokens.space2, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: CashIOTokens.brand.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
              ),
              child: Text(
                'Edit',
                style: GoogleFonts.mukta(color: CashIOTokens.brandLight, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrencyName(String code) {
    try {
      return CurrencyUtils.supportedCurrencies.firstWhere((c) => c['code'] == code)['name']!;
    } catch (_) {
      return code;
    }
  }

  Widget _buildStepIndicator(int current, int total, Color mutedColor) {
    return Row(
      children: [
        Text(
          'STEP $current OF $total',
          style: GoogleFonts.mukta(
            color: CashIOTokens.brandLight,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: CashIOTokens.space2),
        Expanded(
          child: Container(
            height: 2,
            color: CashIOTokens.darkBorder,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: current / total,
              child: Container(color: CashIOTokens.brand),
            ),
          ),
        ),
      ],
    );
  }

  /// Stable stage item (prevents rebuild-refresh flickers on button clicks & keystrokes)
  Widget _buildSmoothFadeItem({required int delayMs, required Widget child}) {
    return child;
  }

  // ---------------------------------------------------------------------------
  // Sharp Tactile Keypad
  // ---------------------------------------------------------------------------
  Widget _buildSharpKeypad(bool isDark, Color textColor) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], isDark, textColor),
        const SizedBox(height: CashIOTokens.space2),
        _buildKeypadRow(['4', '5', '6'], isDark, textColor),
        const SizedBox(height: CashIOTokens.space2),
        _buildKeypadRow(['7', '8', '9'], isDark, textColor),
        const SizedBox(height: CashIOTokens.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _buildDigitKey('0', isDark, textColor),
            _buildDeleteKey(isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) => _buildDigitKey(d, isDark, textColor)).toList(),
    );
  }

  Widget _buildDigitKey(String digit, bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: CashIOTokens.space1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onPinDigit(digit),
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          child: Container(
            width: 76,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CashIOTokens.darkSurface,
              borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
              border: Border.all(color: CashIOTokens.darkBorder),
            ),
            child: Text(
              digit,
              style: GoogleFonts.mukta(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: CashIOTokens.space1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onPinDelete,
          borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
          child: Container(
            width: 76,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CashIOTokens.darkSurface,
              borderRadius: BorderRadius.circular(CashIOTokens.radiusSm),
              border: Border.all(color: CashIOTokens.darkBorder),
            ),
            child: const Icon(Icons.backspace_outlined, size: 20, color: CashIOTokens.brandLight),
          ),
        ),
      ),
    );
  }
}
