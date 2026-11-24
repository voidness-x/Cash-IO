import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
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
  String? _progressMessage;
  String? _statusFeedback;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _statusFeedback = null;
    });

    final update = await _service.checkForUpdates();
    if (mounted) {
      setState(() {
        _isChecking = false;
        _availableUpdate = update;
        if (update == null) {
          _statusFeedback = 'Cash-IO is up to date (v${_service.currentVersion}).';
          _isError = false;
        }
      });
    }
  }

  Future<void> _installUpdate() async {
    if (_availableUpdate == null) return;

    setState(() {
      _isApplying = true;
      _progressMessage = 'Creating emergency pre-update backup snapshot (.cashio.bak)...';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _progressMessage = 'Verifying SHA-256 checksum and cryptographic signatures...');

    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _progressMessage = 'Applying state migrations & running double-entry invariant check...');

    final result = await _service.applyUpdate(_availableUpdate!);

    if (mounted) {
      setState(() {
        _isApplying = false;
        _progressMessage = null;
        _statusFeedback = result.message;
        _isError = !result.success;
        if (result.success) {
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
            Text(
              'Confirm Emergency Rollback',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to rollback to version ${snapshot.fromVersion}?',
              style: GoogleFonts.mukta(color: tokens.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This will restore all ledger postings, accounts, and envelopes to the exact cryptographic snapshot captured on ${snapshot.timestamp.year}-${snapshot.timestamp.month.toString().padLeft(2, '0')}-${snapshot.timestamp.day.toString().padLeft(2, '0')} ${snapshot.timestamp.hour.toString().padLeft(2, '0')}:${snapshot.timestamp.minute.toString().padLeft(2, '0')}.',
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
                'Checksum: ${snapshot.checksumSha256.substring(0, 16)}...',
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
                      ? 'Successfully rolled back to v${snapshot.fromVersion}. Ledger state restored.'
                      : 'Rollback failed.';
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
                Row(
                  children: [
                    Icon(Icons.system_update_alt_rounded, color: tokens.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AUTOMATED UPDATE RECEIVER',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Store-Independent OTA',
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
              'Verified GitHub Releases (${UpdateReceiverService.githubRepositoryUrl}). Updates verify SHA-256 signatures and automatically capture an emergency rollback snapshot.',
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
                        'CURRENT RUNNING VERSION',
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
                    tooltip: 'Check for updates',
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
                  color: _isError ? tokens.statusExpense.withValues(alpha: 0.1) : tokens.statusIncome.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isError ? tokens.statusExpense.withValues(alpha: 0.3) : tokens.statusIncome.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: _isError ? tokens.statusExpense : tokens.statusIncome,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusFeedback!,
                        style: GoogleFonts.mukta(
                          color: _isError ? tokens.statusExpense : tokens.statusIncome,
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
                  color: tokens.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'UPDATE READY TO INSTALL',
                          style: GoogleFonts.spaceGrotesk(
                            color: tokens.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Release: ${_availableUpdate!.releaseDate}',
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
                      LinearProgressIndicator(color: tokens.accent, backgroundColor: tokens.bgCanvas),
                      const SizedBox(height: 8),
                      Text(
                        _progressMessage ?? 'Applying update...',
                        style: GoogleFonts.mukta(color: tokens.accent, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.accent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _installUpdate,
                          icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                          label: Text(
                            'INSTALL UPDATE & BACKUP SNAPSHOT',
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
              'Snapshots automatically created before every update. If any update disrupts your data, rollback with one click.',
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
                    'No emergency snapshots stored yet. A snapshot is automatically created whenever an update is applied.',
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
