import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/security/hardware_vault_service.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/widgets/cashio_logo.dart';

class PinAuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const PinAuthScreen({super.key, required this.onAuthenticated});

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> with TickerProviderStateMixin {
  String _enteredPin = '';
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _isVerifying = false;
  bool _biometricsReady = false;
  bool _isBiometricPromptActive = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndPromptBiometrics();
    });
  }

  Future<void> _initializeAndPromptBiometrics() async {
    final prefEnabled = await HardwareVaultService.instance.getBiometricsEnabled();
    final hwAvailable = await BiometricAuthService.instance.isBiometricAvailable();
    if (!mounted) return;

    final canUseBiometrics = prefEnabled && hwAvailable;
    setState(() {
      _biometricsReady = canUseBiometrics;
    });

    if (canUseBiometrics) {
      await _triggerBiometricSignIn();
    }
  }

  Future<void> _triggerBiometricSignIn() async {
    if (_lockoutSeconds > 0 || _isVerifying || _isBiometricPromptActive) return;
    setState(() => _isBiometricPromptActive = true);

    final authenticated = await BiometricAuthService.instance.authenticate(
      title: 'Sign in to ${VaultRepository.instance.profileName}',
      subtitle: 'Touch the fingerprint sensor to unlock your vault',
      cancelText: 'Use 6-Digit PIN',
    );

    if (!mounted) return;
    setState(() => _isBiometricPromptActive = false);

    if (authenticated) {
      HapticFeedback.mediumImpact();
      HardwareVaultService.instance.resetLockout(VaultRepository.instance.profileId);
      await VaultRepository.instance.loadPersistentVault(VaultRepository.instance.profileId);
      if (mounted) {
        widget.onAuthenticated();
      }
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_lockoutSeconds > 0 || _isVerifying) return;
    if (_enteredPin.length < CashIOTokens.pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == CashIOTokens.pinLength) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_lockoutSeconds > 0 || _isVerifying) return;
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 120));

    final isValid = await HardwareVaultService.instance.verifyPin(
      VaultRepository.instance.profileId,
      _enteredPin,
    );

    if (!mounted) return;

    if (isValid) {
      HapticFeedback.mediumImpact();
      await VaultRepository.instance.loadPersistentVault(VaultRepository.instance.profileId);
      if (mounted) {
        widget.onAuthenticated();
      }
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);

      setState(() {
        _enteredPin = '';
        _failedAttempts++;
        _isVerifying = false;
      });

      if (_failedAttempts >= CashIOTokens.maxFailedAttempts) {
        _startLockout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Incorrect PIN. ${CashIOTokens.maxFailedAttempts - _failedAttempts} attempts remaining.',
              style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
            ),
            backgroundColor: CashIOTokens.expense,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startLockout() {
    setState(() {
      _lockoutSeconds = CashIOTokens.lockoutPenalty.inSeconds;
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSeconds > 1) {
        setState(() {
          _lockoutSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _failedAttempts = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return FrostedScaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 680;
            final keyHeight = compactHeight ? 52.0 : 58.0;
            final keyWidth = ((constraints.maxWidth - 64) / 3).clamp(72.0, 92.0);

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space5,
                vertical: compactHeight ? tokens.space3 : tokens.space5,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - (compactHeight ? 24 : 40)).clamp(0.0, double.infinity),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(height: compactHeight ? tokens.space2 : tokens.space5),

                    // Top Brand & Status Section
                    Column(
                      children: [
                        const CashIOLogo(
                          fontSize: 30,
                          animateO: true,
                          showSubtitle: false,
                        ),
                        SizedBox(height: tokens.space2),
                        Text(
                          _lockoutSeconds > 0
                              ? 'SECURITY LOCKOUT ACTIVE • ${_lockoutSeconds}s'
                              : (_biometricsReady
                                  ? 'UNLOCK WITH FINGERPRINT OR MASTER PIN'
                                  : 'ENTER 6-DIGIT MASTER PIN'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            color: _lockoutSeconds > 0 ? tokens.statusExpense : tokens.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.9,
                          ),
                        ),
                        SizedBox(height: compactHeight ? tokens.space4 : tokens.space5),

                        // PIN Dots Indicator
                        AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            final offset = sin(_shakeAnimation.value * pi * 6) *
                                10 *
                                (1.0 - _shakeAnimation.value);
                            return Transform.translate(
                              offset: Offset(offset, 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(CashIOTokens.pinLength, (index) {
                                  final isFilled = index < _enteredPin.length;
                                  return _buildPinDot(isFilled: isFilled, tokens: tokens);
                                }),
                              ),
                            );
                          },
                        ),

                        // Prominent Fingerprint Unlock Pill
                        if (_biometricsReady && _lockoutSeconds == 0) ...[
                          SizedBox(height: compactHeight ? tokens.space4 : tokens.space5),
                          Semantics(
                            button: true,
                            label: 'Sign in with fingerprint sensor',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _triggerBiometricSignIn,
                                borderRadius: BorderRadius.circular(tokens.radiusPill),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: tokens.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                                    border: Border.all(color: tokens.accent.withValues(alpha: 0.45)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fingerprint_rounded, color: tokens.accent, size: 22),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _isBiometricPromptActive
                                              ? 'Waiting for fingerprint...'
                                              : 'Tap to Sign In with Fingerprint',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.spaceGrotesk(
                                            color: tokens.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: compactHeight ? tokens.space4 : tokens.space6),

                    // Responsive Numeric & Fingerprint Keypad
                    _buildKeypad(tokens, keyWidth: keyWidth, keyHeight: keyHeight),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinDot({required bool isFilled, required CashIOThemeExtension tokens}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      width: isFilled ? 16 : 13,
      height: isFilled ? 16 : 13,
      decoration: BoxDecoration(
        color: isFilled ? tokens.accent : tokens.bgSurfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(
          color: isFilled ? tokens.accent : tokens.borderHairline,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _buildKeypad(
    CashIOThemeExtension tokens, {
    required double keyWidth,
    required double keyHeight,
  }) {
    return Column(
      children: [
        _buildRow(['1', '2', '3'], tokens, keyWidth: keyWidth, keyHeight: keyHeight),
        const SizedBox(height: 10),
        _buildRow(['4', '5', '6'], tokens, keyWidth: keyWidth, keyHeight: keyHeight),
        const SizedBox(height: 10),
        _buildRow(['7', '8', '9'], tokens, keyWidth: keyWidth, keyHeight: keyHeight),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _biometricsReady
                ? _buildActionTile(
                    icon: Icons.fingerprint_rounded,
                    tooltip: 'Unlock with Fingerprint',
                    tokens: tokens,
                    keyWidth: keyWidth,
                    keyHeight: keyHeight,
                    iconColor: tokens.accent,
                    onTap: _triggerBiometricSignIn,
                  )
                : SizedBox(width: keyWidth, height: keyHeight),
            const SizedBox(width: 12),
            _buildKeypadTile(
              '0',
              tokens,
              keyWidth: keyWidth,
              keyHeight: keyHeight,
              onTap: () => _onDigitPressed('0'),
            ),
            const SizedBox(width: 12),
            _buildActionTile(
              icon: Icons.backspace_outlined,
              tooltip: 'Delete digit',
              tokens: tokens,
              keyWidth: keyWidth,
              keyHeight: keyHeight,
              iconColor: tokens.textSecondary,
              onTap: _onDeletePressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(
    List<String> digits,
    CashIOThemeExtension tokens, {
    required double keyWidth,
    required double keyHeight,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildKeypadTile(digits[0], tokens, keyWidth: keyWidth, keyHeight: keyHeight, onTap: () => _onDigitPressed(digits[0])),
        const SizedBox(width: 12),
        _buildKeypadTile(digits[1], tokens, keyWidth: keyWidth, keyHeight: keyHeight, onTap: () => _onDigitPressed(digits[1])),
        const SizedBox(width: 12),
        _buildKeypadTile(digits[2], tokens, keyWidth: keyWidth, keyHeight: keyHeight, onTap: () => _onDigitPressed(digits[2])),
      ],
    );
  }

  Widget _buildKeypadTile(
    String digit,
    CashIOThemeExtension tokens, {
    required double keyWidth,
    required double keyHeight,
    required VoidCallback onTap,
  }) {
    return _TactileKeypadButton(
      width: keyWidth,
      height: keyHeight,
      onTap: onTap,
      tokens: tokens,
      semanticLabel: 'Digit $digit',
      child: Text(
        digit,
        style: GoogleFonts.jetBrainsMono(
          color: tokens.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String tooltip,
    required CashIOThemeExtension tokens,
    required double keyWidth,
    required double keyHeight,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return _TactileKeypadButton(
      width: keyWidth,
      height: keyHeight,
      onTap: onTap,
      tokens: tokens,
      semanticLabel: tooltip,
      child: Icon(icon, color: iconColor, size: 24),
    );
  }
}

class _TactileKeypadButton extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback onTap;
  final CashIOThemeExtension tokens;
  final String semanticLabel;
  final Widget child;

  const _TactileKeypadButton({
    required this.width,
    required this.height,
    required this.onTap,
    required this.tokens,
    required this.semanticLabel,
    required this.child,
  });

  @override
  State<_TactileKeypadButton> createState() => _TactileKeypadButtonState();
}

class _TactileKeypadButtonState extends State<_TactileKeypadButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Material(
        color: _isPressed ? tokens.bgSurfaceElevated : tokens.bgSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        child: InkWell(
          onHighlightChanged: (pressed) => setState(() => _isPressed = pressed),
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              border: Border.all(
                color: _isPressed ? tokens.accent : tokens.borderHairline,
                width: 1.0,
              ),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
