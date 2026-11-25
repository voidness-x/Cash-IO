import 'dart:ui';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/database_helper.dart';
import 'core/storage/vault_repository.dart';
import 'core/security/app_privacy_shield.dart';
import 'features/auth/presentation/pin_screen.dart';
import 'features/profile_setup/presentation/profile_setup_screen.dart';
import 'features/navigation/presentation/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Graceful offline resilience: absorb transient Google Fonts fetch errors when device is air-gapped
  final defaultFlutterError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Failed to load font') || msg.contains('fonts.gstatic.com')) {
      return;
    }
    defaultFlutterError?.call(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final msg = error.toString();
    if (msg.contains('Failed to load font') || msg.contains('fonts.gstatic.com')) {
      return true;
    }
    return false;
  };

  runApp(const CashIOApp());
}

class CashIOApp extends StatefulWidget {
  const CashIOApp({super.key});

  @override
  State<CashIOApp> createState() => _CashIOAppState();
}

class _CashIOAppState extends State<CashIOApp> {
  bool _hasProfile = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkInitialVault();
  }

  Future<void> _checkInitialVault() async {
    try {
      final exists = await DatabaseHelper.instance.hasAnyProfile();
      if (exists) {
        final primary = await DatabaseHelper.instance.getPrimaryProfile();
        if (primary != null) {
          final id = primary['id'] as String;
          await VaultRepository.instance.loadPersistentVault(id);
        }
      }
      if (mounted) {
        setState(() {
          _hasProfile = exists;
        });
      }
    } catch (_) {}
  }

  void _onProfileCreated() {
    setState(() {
      _hasProfile = true;
      _isAuthenticated = true;
    });
  }

  void _onAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _onSwitchProfile() {
    setState(() {
      // Immediate cryptographic unmount: return to profile switcher / PIN lock
      _isAuthenticated = false;
      _hasProfile = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cash-IO',
      debugShowCheckedModeBanner: false,
      theme: CashIOTheme.lightTheme,
      darkTheme: CashIOTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically tracks OS dark/light mode
      builder: (context, child) => AppPrivacyShield(child: child ?? const SizedBox.shrink()),
      home: !_hasProfile
          ? ProfileSetupScreen(onProfileCreated: _onProfileCreated)
          : !_isAuthenticated
              ? PinAuthScreen(onAuthenticated: _onAuthenticated)
              : MainScaffold(onSwitchProfile: _onSwitchProfile),
    );
  }
}
