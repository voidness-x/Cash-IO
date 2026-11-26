import 'dart:convert';
import 'package:flutter/material.dart';
import '../security/hardware_vault_service.dart';
import 'original_theme_snapshot.dart';
import 'theme_extension.dart';

/// Immutable theme preset defining Cash-IO's brand accents and dark/light surfaces.
@immutable
class CashIOThemePreset {
  final String id;
  final String name;
  final String tagline;
  final Color accentColor;
  final Color accentLight;
  final Color accentDark;
  final Color darkBg;
  final Color darkSurface;
  final Color darkSurfaceElevated;
  final Color lightBg;
  final Color lightSurface;
  final Color lightSurfaceElevated;

  const CashIOThemePreset({
    required this.id,
    required this.name,
    required this.tagline,
    required this.accentColor,
    required this.accentLight,
    required this.accentDark,
    required this.darkBg,
    required this.darkSurface,
    required this.darkSurfaceElevated,
    this.lightBg = OriginalCashIOThemeSnapshot.lightBg,
    this.lightSurface = OriginalCashIOThemeSnapshot.lightSurface,
    this.lightSurfaceElevated = OriginalCashIOThemeSnapshot.lightSurfaceElevated,
  });

  CashIOThemeExtension toDarkExtension() {
    return CashIOThemeExtension.dark.copyWith(
      bgPrimary: darkBg,
      bgSurface: darkSurface,
      bgSurfaceElevated: darkSurfaceElevated,
      bgSurfaceGlass: darkSurface.withValues(alpha: 0.88),
      borderHighlight: accentColor.withValues(alpha: 0.45),
      accentGold: accentColor,
      accentChampagne: accentLight,
      accentBrass: accentDark,
      accentGoldBg: accentColor.withValues(alpha: 0.16),
      statusIncome: accentColor,
      statusIncomeBg: accentColor.withValues(alpha: 0.16),
    );
  }

  CashIOThemeExtension toLightExtension() {
    return CashIOThemeExtension.light.copyWith(
      bgPrimary: lightBg,
      bgSurface: lightSurface,
      bgSurfaceElevated: lightSurfaceElevated,
      bgSurfaceGlass: lightSurface.withValues(alpha: 0.94),
      borderHighlight: accentDark,
      accentGold: accentDark,
      accentChampagne: accentColor,
      accentBrass: accentDark,
      accentGoldBg: accentDark.withValues(alpha: 0.12),
      statusIncome: accentDark,
      statusIncomeBg: accentDark.withValues(alpha: 0.12),
    );
  }
}

/// Manages active theme preset, user-customized colors, and light/dark/system mode.
/// Persists selections offline via [HardwareVaultService].
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._();
  static const String _storageKey = 'cashio_theme_pref_v1';
  static const String defaultPresetId = 'indigo_obsidian';

  ThemeController._();

  static const List<CashIOThemePreset> builtInPresets = [
    CashIOThemePreset(
      id: defaultPresetId,
      name: 'Lavender Obsidian (Default)',
      tagline: 'Soft lavender purple & deep obsidian',
      accentColor: Color(0xFF9D8DF1),
      accentLight: Color(0xFFC4B5FD),
      accentDark: Color(0xFF7C6AE6),
      darkBg: Color(0xFF0B0F17),
      darkSurface: Color(0xFF161D2B),
      darkSurfaceElevated: Color(0xFF222C40),
    ),
    CashIOThemePreset(
      id: OriginalCashIOThemeSnapshot.presetId,
      name: OriginalCashIOThemeSnapshot.presetName,
      tagline: 'Classic teal glow & charcoal vault',
      accentColor: OriginalCashIOThemeSnapshot.brand,
      accentLight: OriginalCashIOThemeSnapshot.brandLight,
      accentDark: OriginalCashIOThemeSnapshot.brandDark,
      darkBg: OriginalCashIOThemeSnapshot.darkBg,
      darkSurface: OriginalCashIOThemeSnapshot.darkSurface,
      darkSurfaceElevated: OriginalCashIOThemeSnapshot.darkSurfaceElevated,
      lightBg: OriginalCashIOThemeSnapshot.lightBg,
      lightSurface: OriginalCashIOThemeSnapshot.lightSurface,
      lightSurfaceElevated: OriginalCashIOThemeSnapshot.lightSurfaceElevated,
    ),
    CashIOThemePreset(
      id: 'emerald_vault',
      name: 'Emerald Vault',
      tagline: 'Fresh wealth green & deep obsidian',
      accentColor: Color(0xFF10B981),
      accentLight: Color(0xFF34D399),
      accentDark: Color(0xFF059669),
      darkBg: Color(0xFF111916),
      darkSurface: Color(0xFF1A2621),
      darkSurfaceElevated: Color(0xFF23342D),
    ),
    CashIOThemePreset(
      id: 'ocean_sapphire',
      name: 'Ocean Sapphire',
      tagline: 'Crisp electric blue & midnight slate',
      accentColor: Color(0xFF3B82F6),
      accentLight: Color(0xFF60A5FA),
      accentDark: Color(0xFF2563EB),
      darkBg: Color(0xFF0F172A),
      darkSurface: Color(0xFF1E293B),
      darkSurfaceElevated: Color(0xFF2A384F),
    ),
    CashIOThemePreset(
      id: 'solar_amber',
      name: 'Solar Amber',
      tagline: 'Warm bullion gold & espresso dark',
      accentColor: Color(0xFFF59E0B),
      accentLight: Color(0xFFFBBF24),
      accentDark: Color(0xFFD97706),
      darkBg: Color(0xFF1C1917),
      darkSurface: Color(0xFF292524),
      darkSurfaceElevated: Color(0xFF3A3432),
    ),
    CashIOThemePreset(
      id: 'royal_amethyst',
      name: 'Royal Amethyst',
      tagline: 'Vibrant violet & velvet night',
      accentColor: Color(0xFF8B5CF6),
      accentLight: Color(0xFFA78BFA),
      accentDark: Color(0xFF7C3AED),
      darkBg: Color(0xFF141122),
      darkSurface: Color(0xFF211C36),
      darkSurfaceElevated: Color(0xFF2E274B),
    ),
    CashIOThemePreset(
      id: 'rose_quartz',
      name: 'Rose Quartz',
      tagline: 'Luminous crimson rose & deep plum',
      accentColor: Color(0xFFF43F5E),
      accentLight: Color(0xFFFB7185),
      accentDark: Color(0xFFE11D48),
      darkBg: Color(0xFF1C1217),
      darkSurface: Color(0xFF2B1B23),
      darkSurfaceElevated: Color(0xFF3A242F),
    ),
    CashIOThemePreset(
      id: 'midnight_mono',
      name: 'Titanium Frost',
      tagline: 'Minimalist ice blue & stealth graphite',
      accentColor: Color(0xFF38BDF8),
      accentLight: Color(0xFF7DD3FC),
      accentDark: Color(0xFF0284C7),
      darkBg: Color(0xFF0B0F17),
      darkSurface: Color(0xFF161D2B),
      darkSurfaceElevated: Color(0xFF222C40),
    ),
  ];

  CashIOThemePreset _activePreset = builtInPresets.first;
  ThemeMode _themeMode = ThemeMode.system;

  CashIOThemePreset get activePreset => _activePreset;
  ThemeMode get themeMode => _themeMode;

  CashIOThemeExtension get darkExtension => _activePreset.toDarkExtension();
  CashIOThemeExtension get lightExtension => _activePreset.toLightExtension();

  /// Loads persisted theme selection from local device storage.
  Future<void> loadSavedTheme() async {
    try {
      final raw = await HardwareVaultService.instance.readPreference(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final modeStr = data['mode'] as String?;
      if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.system;
      }

      final presetId = data['presetId'] as String?;
      if (presetId == 'custom') {
        final accentVal = data['accent'] as int?;
        final surfaceVal = data['surface'] as int?;
        final bgVal = data['background'] as int?;
        if (accentVal != null) {
          _activePreset = _buildCustomPreset(
            accent: Color(accentVal),
            surface: surfaceVal != null ? Color(surfaceVal) : null,
            background: bgVal != null ? Color(bgVal) : null,
          );
        }
      } else if (presetId != null) {
        final match = builtInPresets.where((p) => p.id == presetId);
        if (match.isNotEmpty) {
          _activePreset = match.first;
        }
      }
      notifyListeners();
    } catch (_) {
      // Keep safe default if stored preference is malformed
    }
  }

  /// Applies a live unpersisted preview inside Theme Studio (can be committed or reverted).
  void previewTheme({CashIOThemePreset? preset, ThemeMode? mode}) {
    if (preset != null) _activePreset = preset;
    if (mode != null) _themeMode = mode;
    notifyListeners();
  }

  /// Applies a live unpersisted custom color preview inside Theme Studio.
  void previewCustomColors({
    required Color accent,
    Color? surface,
    Color? background,
  }) {
    _activePreset = _buildCustomPreset(
      accent: accent,
      surface: surface,
      background: background,
    );
    notifyListeners();
  }

  /// Persists the currently active theme (preset + mode) to local device storage.
  Future<void> commitCurrentTheme() async {
    notifyListeners();
    await _persist();
  }

  /// Selects one of the curated built-in theme presets and persists it.
  Future<void> selectPreset(String presetId) async {
    final match = builtInPresets.where((p) => p.id == presetId);
    if (match.isEmpty) return;
    _activePreset = match.first;
    notifyListeners();
    await _persist();
  }

  /// Applies user-chosen custom accent (and optional surface/background) colors.
  Future<void> applyCustomColors({
    required Color accent,
    Color? surface,
    Color? background,
  }) async {
    _activePreset = _buildCustomPreset(
      accent: accent,
      surface: surface,
      background: background,
    );
    notifyListeners();
    await _persist();
  }

  /// Changes Light / Dark / System theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  /// Restores the default Indigo Obsidian theme preset.
  Future<void> resetToDefault() async {
    _activePreset = builtInPresets.firstWhere((p) => p.id == defaultPresetId);
    notifyListeners();
    await _persist();
  }

  /// Restores the archived Cyber Teal (Original) theme preset.
  Future<void> resetToOriginal() async {
    _activePreset = builtInPresets.firstWhere((p) => p.id == OriginalCashIOThemeSnapshot.presetId);
    notifyListeners();
    await _persist();
  }

  CashIOThemePreset _buildCustomPreset({
    required Color accent,
    Color? surface,
    Color? background,
  }) {
    final hsl = HSLColor.fromColor(accent);
    final lighter = hsl.withLightness((hsl.lightness + 0.16).clamp(0.0, 0.92)).toColor();
    final darker = hsl.withLightness((hsl.lightness - 0.14).clamp(0.15, 0.85)).toColor();

    final baseSurface = surface ?? _activePreset.darkSurface;
    final baseBg = background ?? _activePreset.darkBg;
    final surfaceHsl = HSLColor.fromColor(baseSurface);
    final elevated = surfaceHsl.withLightness((surfaceHsl.lightness + 0.06).clamp(0.0, 0.95)).toColor();

    return CashIOThemePreset(
      id: 'custom',
      name: 'Custom Theme',
      tagline: 'Personalized colors',
      accentColor: accent,
      accentLight: lighter,
      accentDark: darker,
      darkBg: baseBg,
      darkSurface: baseSurface,
      darkSurfaceElevated: elevated,
    );
  }

  Future<void> _persist() async {
    final payload = <String, dynamic>{
      'presetId': _activePreset.id,
      'mode': _themeMode == ThemeMode.dark
          ? 'dark'
          : _themeMode == ThemeMode.light
              ? 'light'
              : 'system',
      if (_activePreset.id == 'custom') ...{
        'accent': _activePreset.accentColor.toARGB32(),
        'surface': _activePreset.darkSurface.toARGB32(),
        'background': _activePreset.darkBg.toARGB32(),
      },
    };
    await HardwareVaultService.instance.savePreference(_storageKey, jsonEncode(payload));
  }
}
