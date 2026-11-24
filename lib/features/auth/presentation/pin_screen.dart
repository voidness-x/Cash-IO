import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
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

  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Subtle breathing glow animation for vault shield
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // 2. Error shake animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pulseController.dispose();
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

    // Small delay to allow final dot animation to complete smoothly
    await Future.delayed(const Duration(milliseconds: 140));

    final isValid = await HardwareVaultService.instance.verifyPin(
      VaultRepository.instance.profileId,
      _enteredPin,
    );

    if (!mounted) return;

    if (isValid) {
      HapticFeedback.mediumImpact();
      await VaultRepository.instance.loadPersistentVault(VaultRepository.instance.profileId);
      widget.onAuthenticated();
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
              'Incorrect master PIN. ${CashIOTokens.maxFailedAttempts - _failedAttempts} attempts remaining.',
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
      body: Stack(
        children: [
          // Ambient architectural background coordinates
          Positioned.fill(
            child: CustomPaint(
              painter: _ArchitecturalGridPainter(tokens: tokens),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space6),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Brand Typographic Cash-IO with Centered Spinning Vault 'O' (No Shield)
                  const CashIOLogo(
                    fontSize: 32,
                    animateO: true,
                    showSubtitle: false,
                  ),
                  SizedBox(height: tokens.space3),
                  Text(
                    _lockoutSeconds > 0
                        ? 'SECURITY LOCKOUT ACTIVE: ${_lockoutSeconds}s'
                        : 'ENTER AIR-GAPPED MASTER PIN',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mukta(
                      color: _lockoutSeconds > 0 ? tokens.statusExpense : tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: tokens.space6),

                  // Animated PIN Hexagon/Diamond Indicators with Error Shake
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final offset = sin(_shakeAnimation.value * pi * 6) * 12 * (1.0 - _shakeAnimation.value);
                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(CashIOTokens.pinLength, (index) {
                            final isFilled = index < _enteredPin.length;
                            return _buildHexagonDot(isFilled: isFilled, tokens: tokens);
                          }),
                        ),
                      );
                    },
                  ),
                  const Spacer(flex: 3),

                  // Tactile Architectural Keypad
                  _buildKeypad(tokens),
                  SizedBox(height: tokens.space8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexagonDot({required bool isFilled, required CashIOThemeExtension tokens}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: tokens.space2),
      width: isFilled ? 18 : 14,
      height: isFilled ? 18 : 14,
      decoration: BoxDecoration(
        color: isFilled ? tokens.accentGold : tokens.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(
          color: isFilled ? tokens.accentChampagne : tokens.borderHairline,
          width: 1.2,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: tokens.accentGold.withValues(alpha: 0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
    );
  }

  Widget _buildKeypad(CashIOThemeExtension tokens) {
    return Column(
      children: [
        _buildRow(['1', '2', '3'], tokens, subTitles: ['', 'ABC', 'DEF']),
        SizedBox(height: tokens.space3),
        _buildRow(['4', '5', '6'], tokens, subTitles: ['GHI', 'JKL', 'MNO']),
        SizedBox(height: tokens.space3),
        _buildRow(['7', '8', '9'], tokens, subTitles: ['PQRS', 'TUV', 'WXYZ']),
        SizedBox(height: tokens.space3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty placeholder to balance layout
            SizedBox(width: 84, height: 60),
            SizedBox(width: tokens.space3),
            _buildKeypadTile('0', '', tokens, onTap: () => _onDigitPressed('0')),
            SizedBox(width: tokens.space3),
            _buildActionTile(
              icon: Icons.backspace_outlined,
              tokens: tokens,
              onTap: _onDeletePressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits, CashIOThemeExtension tokens, {required List<String> subTitles}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(digits.length, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space1 * 1.5),
          child: _buildKeypadTile(
            digits[i],
            subTitles[i],
            tokens,
            onTap: () => _onDigitPressed(digits[i]),
          ),
        );
      }),
    );
  }

  Widget _buildKeypadTile(
    String digit,
    String subTitle,
    CashIOThemeExtension tokens, {
    required VoidCallback onTap,
  }) {
    return _TactileKeypadButton(
      width: 84,
      height: 60,
      onTap: onTap,
      tokens: tokens,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            digit,
            style: GoogleFonts.jetBrainsMono(
              color: tokens.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subTitle.isNotEmpty) ...[
            Text(
              subTitle,
              style: GoogleFonts.mukta(
                color: tokens.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required CashIOThemeExtension tokens,
    required VoidCallback onTap,
  }) {
    return _TactileKeypadButton(
      width: 84,
      height: 60,
      onTap: onTap,
      tokens: tokens,
      child: Icon(icon, color: tokens.accentGold, size: 22),
    );
  }
}

/// Tactile keypad button with micro-scale spring physics on tap
class _TactileKeypadButton extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback onTap;
  final CashIOThemeExtension tokens;
  final Widget child;

  const _TactileKeypadButton({
    required this.width,
    required this.height,
    required this.onTap,
    required this.tokens,
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

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _isPressed ? tokens.bgSurfaceElevated : tokens.bgSurface,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: _isPressed ? tokens.accentGold : tokens.borderHairline,
              width: 1.0,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: tokens.accentGold.withValues(alpha: 0.15),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

/// Subtle architectural grid coordinates painted in the background
class _ArchitecturalGridPainter extends CustomPainter {
  final CashIOThemeExtension tokens;

  const _ArchitecturalGridPainter({required this.tokens});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tokens.borderHairline.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
