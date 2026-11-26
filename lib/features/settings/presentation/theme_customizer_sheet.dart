import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/original_theme_snapshot.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/animated_money_bar.dart';

/// Interactive Theme & Colors studio allowing users to pick built-in presets,
/// customize accent/surface colors freely, switch Dark/Light/System mode,
/// or restore the archived Original Cyber Teal theme in 1 tap.
class ThemeCustomizerSheet extends StatefulWidget {
  const ThemeCustomizerSheet({super.key});

  @override
  State<ThemeCustomizerSheet> createState() => _ThemeCustomizerSheetState();
}

class _ThemeCustomizerSheetState extends State<ThemeCustomizerSheet> {
  static const List<Color> _customAccentSwatches = [
    Color(0xFF00ABB3), // Original Cyber Teal
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Sapphire
    Color(0xFF06B6D4), // Cyan
    Color(0xFF8B5CF6), // Amethyst
    Color(0xFFEC4899), // Pink
    Color(0xFFF43F5E), // Rose
    Color(0xFFF97316), // Sunset Orange
    Color(0xFFF59E0B), // Solar Amber
    Color(0xFF84CC16), // Lime
    Color(0xFF14B8A6), // Mint Teal
    Color(0xFF6366F1), // Indigo
  ];

  static const List<(String, Color, Color)> _surfacePairs = [
    ('Charcoal', Color(0xFF22252A), Color(0xFF3C4048)),
    ('Obsidian', Color(0xFF0B0F17), Color(0xFF161D2B)),
    ('Navy', Color(0xFF0F172A), Color(0xFF1E293B)),
    ('Forest', Color(0xFF111916), Color(0xFF1A2621)),
    ('Espresso', Color(0xFF1C1917), Color(0xFF292524)),
    ('Velvet', Color(0xFF141122), Color(0xFF211C36)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final ctrl = ThemeController.instance;
        final tokens = context.tokens;
        final active = ctrl.activePreset;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.borderHairline,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.palette_rounded, color: tokens.accentGold, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme & Colors',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Pick a preset or craft your own look',
                            style: GoogleFonts.mukta(
                              color: tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Live Preview Card showing Hero Glow + Animated Money Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: tokens.heroGlowDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'LIVE PREVIEW • ${active.name.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.accentChampagne,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.auto_awesome_rounded, color: tokens.accentGold, size: 16),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\$4,250.00',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedMoneyBar(
                        key: ValueKey('preview_bar_${active.id}_${active.accentColor.toARGB32()}'),
                        value: 0.76,
                        height: 8,
                        fillColor: tokens.accentGold,
                        glow: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Appearance Mode Toggle
                Text(
                  'APPEARANCE MODE',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _modeButton(tokens, ctrl, ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
                    const SizedBox(width: 8),
                    _modeButton(tokens, ctrl, ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
                    const SizedBox(width: 8),
                    _modeButton(tokens, ctrl, ThemeMode.light, Icons.light_mode_rounded, 'Light'),
                  ],
                ),
                const SizedBox(height: 18),

                // Built-in Curated Presets
                Text(
                  'CURATED PRESETS',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ThemeController.builtInPresets.map((preset) {
                    final selected = active.id == preset.id;
                    return InkWell(
                      key: ValueKey('theme_preset_${preset.id}'),
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ctrl.selectPreset(preset.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? preset.accentColor.withValues(alpha: 0.16) : tokens.bgSurfaceElevated,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          border: Border.all(
                            color: selected ? preset.accentColor : tokens.borderHairline,
                            width: selected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: preset.accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: preset.accentColor.withValues(alpha: 0.45),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                preset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.mukta(
                                  color: tokens.textPrimary,
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.check_rounded, size: 15, color: preset.accentColor),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Custom Accent Color Swatches
                Text(
                  'CUSTOM ACCENT COLOR',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _customAccentSwatches.map((color) {
                    final isCurrent = active.accentColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ctrl.applyCustomColors(accent: color);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrent ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isCurrent
                              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)]
                              : null,
                        ),
                        child: isCurrent
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Custom Dark Surface Style
                Text(
                  'CARD & CANVAS TONE (DARK MODE)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _surfacePairs.map((pair) {
                    final isCurrent = active.darkBg.toARGB32() == pair.$2.toARGB32() &&
                        active.darkSurface.toARGB32() == pair.$3.toARGB32();
                    return InkWell(
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ctrl.applyCustomColors(
                          accent: active.accentColor,
                          background: pair.$2,
                          surface: pair.$3,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: pair.$3,
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          border: Border.all(
                            color: isCurrent ? active.accentColor : tokens.borderHairline,
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: pair.$2,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              pair.$1,
                              style: GoogleFonts.mukta(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Restore Original Cyber Teal Button
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ctrl.resetToOriginal();
                  },
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(
                    'Reset to ${OriginalCashIOThemeSnapshot.presetName}',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _modeButton(
    CashIOThemeExtension tokens,
    ThemeController ctrl,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final selected = ctrl.themeMode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        onTap: () {
          HapticFeedback.selectionClick();
          ctrl.setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tokens.accentGoldBg : tokens.bgSurfaceElevated,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            border: Border.all(
              color: selected ? tokens.accentGold : tokens.borderHairline,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? tokens.accentGold : tokens.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.mukta(
                  color: selected ? tokens.textPrimary : tokens.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
