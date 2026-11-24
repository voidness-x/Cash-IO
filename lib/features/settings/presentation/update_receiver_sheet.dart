import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/services/ota_platform_bridge.dart';
import '../../../core/services/update_receiver_service.dart';

class UpdateReceiverSheet extends StatefulWidget {
  const UpdateReceiverSheet({super.key});

  @override
  State<UpdateReceiverSheet> createState() => _UpdateReceiverSheetState();
}

class _UpdateReceiverSheetState extends State<UpdateReceiverSheet> {
  final _service = UpdateReceiverService.instance;
  AppUpdateManifest? _availableUpdate;
  bool _isChecking = false;
  bool _isApplying = false;
  double _progressValue = 0.0;
  String? _progressMessage;
  String? _statusFeedback;
  bool _isError = false;
  bool _needsPermissionRetry = false;

  @override
  void initState() {
    super.initState();
    _availableUpdate = _service.availableUpdate;
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _statusFeedback = null;
      _needsPermissionRetry = false;
    });

    final update = await _service.checkForUpdates(forceCheck: true);
    if (mounted) {
      setState(() {
        _isChecking = false;
        _availableUpdate = update;
        if (update == null) {
          _statusFeedback =
              'Cash-IO is up to date (v${_service.currentVersion} • Build ${_service.currentBuild}). Checked GitHub Releases.';
          _isError = false;
        }
      });
    }
  }

  Future<void> _installUpdate() async {
    if (_availableUpdate == null) return;

    setState(() {
      _isApplying = true;
      _needsPermissionRetry = false;
      _progressValue = 0.05;
      _progressMessage = 'Creating emergency pre-update backup snapshot (.cashio.bak)...';
    });

    final result = await _service.applyUpdate(
      _availableUpdate!,
      onProgress: (progress, statusText) {
        if (mounted) {
          setState(() {
            _progressValue = progress;
            _progressMessage = statusText;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isApplying = false;
        _progressMessage = null;
        _statusFeedback = result.message;
        _isError = !result.success && !result.needsInstallPermission;
        _needsPermissionRetry = result.needsInstallPermission;
        if (result.success && !result.launchedSystemInstaller) {
          _availableUpdate = null;
        }
      });
    }
  }

  void _confirmRollback(EmergencyRollbackSnapshot snapshot) {
    final tokens = context.tokens;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tokens.borderHairline),
        ),
        title: Row(
          children: [
            Icon(Icons.history, color: tokens.statusExpense, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirm Emergency Rollback',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textPrimary,
                  fontSize: 16,
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
              'Are you sure you want to rollback ledger data to version ${snapshot.fromVersion}?',
              style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This restores all ledger postings, accounts, savings goals, and envelopes to the exact cryptographic snapshot captured on ${snapshot.timestamp.year}-${snapshot.timestamp.month.toString().padLeft(2, '0')}-${snapshot.timestamp.day.toString().padLeft(2, '0')} ${snapshot.timestamp.hour.toString().padLeft(2, '0')}:${snapshot.timestamp.minute.toString().padLeft(2, '0')}.',
              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.bgCanvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SHA-256: ${snapshot.checksumSha256.substring(0, 20)}...',
                style: GoogleFonts.jetBrainsMono(color: tokens.textTertiary, fontSize: 10),
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
              backgroundColor: tokens.statusExpense,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _service.rollbackToSnapshot(snapshot.snapshotId);
              if (mounted) {
                setState(() {
                  _statusFeedback = success
                      ? 'Successfully rolled back vault state to v${snapshot.fromVersion}.'
                      : 'Rollback aborted: snapshot integrity check failed.';
                  _isError = !success;
                });
              }
            },
            child: const Text('ROLLBACK NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final snapshots = _service.availableRollbackSnapshots;
    final platformBadge = OtaPlatformBridge.isAndroidNative
        ? 'Android Self-Updating APK'
        : (OtaPlatformBridge.isIOSNative ? 'iOS Signed Release OTA' : 'GitHub Releases OTA');

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

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.system_update_alt_rounded, color: tokens.accent, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'AUTOMATED UPDATE RECEIVER',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    platformBadge,
                    style: GoogleFonts.mukta(
                      color: tokens.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Live GitHub Releases channel (${UpdateReceiverService.githubRepositoryUrl}). Verifies SHA-256 signatures and captures a persistent .cashio.bak snapshot prior to install.',
              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
            ),
            SizedBox(height: tokens.space4),

            // Current Version Card
            Container(
              padding: EdgeInsets.all(tokens.space4),
              decoration: BoxDecoration(
                color: tokens.bgCanvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.borderHairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT INSTALLED VERSION',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${_service.currentVersion} (Build ${_service.currentBuild})',
                        style: GoogleFonts.jetBrainsMono(
                          color: tokens.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: _isChecking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 20),
                    tooltip: 'Check GitHub Releases now',
                    onPressed: _isChecking || _isApplying ? null : _checkForUpdates,
                  ),
                ],
              ),
            ),

            if (_statusFeedback != null) ...[
              SizedBox(height: tokens.space3),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? tokens.statusExpense.withValues(alpha: 0.1)
                      : (_needsPermissionRetry
                          ? tokens.accent.withValues(alpha: 0.12)
                          : tokens.statusIncome.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isError
                        ? tokens.statusExpense.withValues(alpha: 0.3)
                        : (_needsPermissionRetry
                            ? tokens.accent.withValues(alpha: 0.4)
                            : tokens.statusIncome.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError
                          ? Icons.error_outline
                          : (_needsPermissionRetry ? Icons.security_update_warning_rounded : Icons.check_circle_outline),
                      color: _isError
                          ? tokens.statusExpense
                          : (_needsPermissionRetry ? tokens.accent : tokens.statusIncome),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusFeedback!,
                        style: GoogleFonts.mukta(
                          color: _isError
                              ? tokens.statusExpense
                              : (_needsPermissionRetry ? tokens.textPrimary : tokens.statusIncome),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Available Update Deck
            if (_availableUpdate != null) ...[
              SizedBox(height: tokens.space4),
              Container(
                padding: EdgeInsets.all(tokens.space4),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.accent.withValues(alpha: 0.45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NEW GITHUB RELEASE AVAILABLE • v${_availableUpdate!.version}',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (_availableUpdate!.releaseDate.isNotEmpty)
                          Text(
                            _availableUpdate!.releaseDate,
                            style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _availableUpdate!.title,
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._availableUpdate!.changelog.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: tokens.accent, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: tokens.space4),

                    if (_isApplying) ...[
                      LinearProgressIndicator(
                        value: _progressValue > 0 ? _progressValue : null,
                        color: tokens.accent,
                        backgroundColor: tokens.bgCanvas,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _progressMessage ?? 'Downloading & verifying update...',
                        style: GoogleFonts.mukta(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _installUpdate,
                          icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                          label: Text(
                            OtaPlatformBridge.isAndroidNative
                                ? (_needsPermissionRetry
                                    ? 'PERMISSION GRANTED — INSTALL APK NOW'
                                    : 'BACKUP VAULT & INSTALL APK UPDATE')
                                : 'INSTALL UPDATE & BACKUP SNAPSHOT',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Emergency Rollback Archive
            SizedBox(height: tokens.space5),
            Row(
              children: [
                Icon(Icons.history, color: tokens.textSecondary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'EMERGENCY ROLLBACK ARCHIVE (.CASHIO.BAK)',
                  style: GoogleFonts.spaceGrotesk(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Persistent snapshots saved before every OTA update. Restore your vault with one tap if needed.',
              style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
            ),
            SizedBox(height: tokens.space3),

            if (snapshots.isEmpty)
              Container(
                padding: EdgeInsets.all(tokens.space4),
                decoration: BoxDecoration(
                  color: tokens.bgCanvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: tokens.borderHairline),
                ),
                child: Center(
                  child: Text(
                    'No emergency snapshots stored yet. A snapshot is automatically persisted whenever an update is installed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 12),
                  ),
                ),
              )
            else ...[
              ...snapshots.map((snap) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.bgCanvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.archive_outlined, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pre-Update to v${snap.targetVersion} (Saved v${snap.fromVersion})',
                              style: GoogleFonts.spaceGrotesk(
                                color: tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${snap.timestamp.year}-${snap.timestamp.month.toString().padLeft(2, '0')}-${snap.timestamp.day.toString().padLeft(2, '0')} • ${snap.timestamp.hour.toString().padLeft(2, '0')}:${snap.timestamp.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.statusExpense,
                          side: BorderSide(color: tokens.statusExpense.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _confirmRollback(snap),
                        child: const Text('Rollback'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
