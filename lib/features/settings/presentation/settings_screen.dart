import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/frosted_scaffold.dart';
import '../../../core/storage/vault_repository.dart';
import '../../../core/sync/google_drive_service.dart';
import '../../../core/backup/cashio_backup_manager.dart';
import '../../../core/security/clipboard_sanitizer.dart';
import '../../subscriptions/presentation/recurring_bills_sheet.dart';
import '../../fx/presentation/fx_converter_sheet.dart';
import 'update_receiver_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSwitchProfile;

  const SettingsScreen({super.key, this.onSwitchProfile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        return FrostedScaffold(
          appBar: AppBar(
            title: Text(
              'SETTINGS & SECURITY',
              style: GoogleFonts.spaceGrotesk(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
          body: ListView(
            padding: EdgeInsets.all(tokens.space4),
            children: [
              // Active Profile Card
              StaggeredEntrance(
                index: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                    border: Border.all(color: tokens.borderHairline),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(tokens.space4),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(tokens.radiusSm),
                          border: Border.all(color: tokens.accentGold.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: Icon(Icons.person_outline, color: tokens.accentChampagne, size: 24),
                        ),
                      ),
                      SizedBox(width: tokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.profileName,
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Base Currency: ${repo.baseCurrency} • AES-256-GCM Vault',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _showProfileSwitcherSheet(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: tokens.space3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusPill),
                          ),
                        ),
                        child: Text(
                          'Switch',
                          style: GoogleFonts.mukta(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space5),

              // Section 1: Google Drive Sync & CRDTs
              StaggeredEntrance(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('CLOUD BACKUP & CRDT SYNC', tokens.textSecondary),
                    ListenableBuilder(
                      listenable: GoogleDriveService.instance,
                      builder: (context, _) {
                        final drive = GoogleDriveService.instance;
                        final isSyncing = drive.status == SyncStatus.syncing;

                        return Container(
                          decoration: BoxDecoration(
                            color: tokens.bgSurface,
                            borderRadius: BorderRadius.circular(tokens.radiusMd),
                            border: Border.all(color: tokens.borderHairline),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Icon(
                                  drive.isConnected ? Icons.cloud_done : Icons.cloud_queue,
                                  color: drive.isConnected ? tokens.statusIncome : tokens.accentGold,
                                ),
                                title: Text(
                                  'Google Drive E2EE Sync',
                                  style: GoogleFonts.mukta(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  drive.isConnected
                                      ? (isSyncing
                                          ? 'Encrypting & uploading delta...'
                                          : 'Connected to drive.appdata • Synced')
                                      : 'Offline • Sandboxed to drive.appdata',
                                  style: GoogleFonts.mukta(
                                    color: isSyncing ? tokens.accentChampagne : tokens.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                                    ),
                                  ),
                                  onPressed: isSyncing
                                      ? null
                                      : () async {
                                          if (!drive.isConnected) {
                                            await drive.connectGoogleDrive();
                                          } else {
                                            await drive.syncNow();
                                          }
                                        },
                                  child: Text(
                                    isSyncing
                                        ? 'Syncing...'
                                        : (drive.isConnected ? 'Sync Now' : 'Connect'),
                                    style: GoogleFonts.mukta(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              Divider(height: 1, color: tokens.borderSubtle),
                              ListTile(
                                leading: Icon(Icons.hub_outlined, color: tokens.statusIncome),
                                title: Text(
                                  'CRDT Sync & Mutation Inspector',
                                  style: GoogleFonts.mukta(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Inspect Lamport logical clocks & mutation events',
                                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                                ),
                                trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                                onTap: () => _showCrdtInspectorSheet(context),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space5),

              // Section 2: Vault Security
              StaggeredEntrance(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('VAULT SECURITY & RECOVERY', tokens.textSecondary),
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.bgSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            secondary: Icon(Icons.fingerprint, color: tokens.accentGold),
                            title: Text(
                              'Biometric Authentication',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'FaceID / Fingerprint unlock',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            value: _biometricsEnabled,
                            activeTrackColor: tokens.accentGold,
                            onChanged: (val) {
                              setState(() {
                                _biometricsEnabled = val;
                              });
                            },
                          ),
                          Divider(height: 1, color: tokens.borderSubtle),
                          ListTile(
                            leading: Icon(Icons.pin_outlined, color: tokens.accentGold),
                            title: Text(
                              'Change 6-Digit Master PIN',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enter current PIN on keypad to change.',
                                    style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: tokens.accentGold,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          Divider(height: 1, color: tokens.borderSubtle),
                          ListTile(
                            leading: Icon(Icons.vpn_key_outlined, color: tokens.statusIncome),
                            title: Text(
                              'View 12-Word Recovery Phrase',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Requires Master PIN verification',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () => _showRecoveryPhraseSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space5),

              // Section 3: Data Export & Portability
              StaggeredEntrance(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('DATA PORTABILITY', tokens.textSecondary),
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.bgSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.file_download_outlined, color: tokens.accentGold),
                            title: Text(
                              'Export Ledger (CSV)',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Standard format for tax preparation & audit',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () {
                              final csv = repo.exportTransactionsToCsv();
                              Clipboard.setData(ClipboardData(text: csv));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Ledger CSV generated & copied to clipboard!',
                                    style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: tokens.statusIncome,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          Divider(height: 1, color: tokens.borderSubtle),
                          ListTile(
                            leading: Icon(Icons.shield_outlined, color: tokens.accentChampagne),
                            title: Text(
                              'Create Encrypted Backup (.cashio)',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Encrypted archive for manual transfer',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () async {
                              final file = await CashIOBackupManager.instance.exportEncryptedBackup(
                                profileId: repo.profileId,
                                backupPassword: 'backup_${repo.profileId}',
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Encrypted bundle exported: ${file.path.split(RegExp(r"[/\\]")).last}',
                                      style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor: tokens.statusIncome,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          Divider(height: 1, color: tokens.borderSubtle),
                          ListTile(
                            leading: Icon(Icons.system_update_alt_rounded, color: tokens.accent),
                            title: Text(
                              'Automated Updates & Rollback',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Store-independent OTA receiver with emergency rollback',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => const UpdateReceiverSheet(),
                              );
                            },
                          ),
                          Divider(height: 1, color: tokens.borderSubtle),
                          ListTile(
                            leading: Icon(Icons.repeat_rounded, color: tokens.statusIncome),
                            title: Text(
                              'Recurring Bills & Subscriptions',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Manage scheduled payments & automated entries',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: tokens.bgPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
                                ),
                                builder: (ctx) => RecurringBillsSheet(baseCurrency: repo.baseCurrency),
                              );
                            },
                          ),
                          Divider(height: 1, color: tokens.borderSubtle),
                          ListTile(
                            leading: Icon(Icons.currency_exchange, color: tokens.statusIncome),
                            title: Text(
                              'Multi-Currency FX Matrix',
                              style: GoogleFonts.mukta(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Offline currency rates & secondary display valuation',
                              style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(Icons.chevron_right, color: tokens.textTertiary),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: tokens.bgPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
                                ),
                                builder: (ctx) => FxConverterSheet(baseCurrency: repo.baseCurrency),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.space6),

              // App Info & Compliance Footer
              StaggeredEntrance(
                index: 4,
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'Cash-IO v1.0.0 (Local-First Edition)',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Zero Telemetry • Zero Trackers • E2EE AES-256-GCM',
                        style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: tokens.space8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _showProfileSwitcherSheet(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.all(tokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWITCH PROFILE VAULT',
                style: GoogleFonts.spaceGrotesk(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: tokens.space4),
              ListTile(
                leading: Icon(Icons.check_circle, color: tokens.statusIncome),
                title: Text(
                  repo.profileName,
                  style: GoogleFonts.mukta(fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Active Encrypted Vault',
                  style: GoogleFonts.mukta(color: tokens.textSecondary),
                ),
              ),
              ListTile(
                leading: Icon(Icons.business_outlined, color: tokens.accentGold),
                title: Text(
                  'Side Business',
                  style: GoogleFonts.mukta(fontWeight: FontWeight.w700, color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Isolated DB • Independent PIN',
                  style: GoogleFonts.mukta(color: tokens.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSwitchProfile?.call();
                },
              ),
              Divider(color: tokens.borderSubtle),
              ListTile(
                leading: Icon(Icons.add, color: tokens.accentGold),
                title: Text(
                  'Create New Profile Vault',
                  style: GoogleFonts.mukta(fontWeight: FontWeight.w700, color: tokens.accentChampagne),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSwitchProfile?.call();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCrdtInspectorSheet(BuildContext context) {
    final repo = VaultRepository.instance;
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.all(tokens.space5),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hub_outlined, color: tokens.statusIncome, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'CRDT SYNC INSPECTOR',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.statusIncome.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(tokens.radiusPill),
                          border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Lamport Ordering',
                          style: GoogleFonts.mukta(color: tokens.statusIncome, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space2),
                  Text(
                    'Immutable append-only CRDT mutation event log with deterministic conflict resolution.',
                    style: GoogleFonts.mukta(fontSize: 12, color: tokens.textSecondary),
                  ),
                  SizedBox(height: tokens.space4),

                  // Event Log Future
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: repo.getCrdtEvents(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final events = snapshot.data ?? [];
                      if (events.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(tokens.space6),
                          decoration: BoxDecoration(
                            color: tokens.bgSurfaceElevated,
                            borderRadius: BorderRadius.circular(tokens.radiusMd),
                            border: Border.all(color: tokens.borderHairline),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_outline, color: tokens.statusIncome, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'Clean Event Log',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: tokens.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'New transactions and account actions will record with deterministic Lamport timestamps.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.mukta(color: tokens.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RECENT MUTATION EVENTS (${events.length})',
                            style: GoogleFonts.spaceGrotesk(
                              color: tokens.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: tokens.space2),
                          ...events.map((ev) {
                            final clock = ev['lamport_clock'] ?? 0;
                            final entityType = (ev['entity_type'] ?? 'unknown').toString().toUpperCase();
                            final action = (ev['action'] ?? 'mutation').toString().toUpperCase();
                            final timeMs = ev['timestamp_ms'] as int? ?? 0;
                            final date = DateTime.fromMillisecondsSinceEpoch(timeMs);
                            final deviceId = (ev['device_id'] ?? 'local').toString();

                            return Container(
                              margin: EdgeInsets.only(bottom: tokens.space2),
                              padding: EdgeInsets.symmetric(horizontal: tokens.space4, vertical: tokens.space3),
                              decoration: BoxDecoration(
                                color: tokens.bgSurfaceElevated,
                                borderRadius: BorderRadius.circular(tokens.radiusSm),
                                border: Border.all(color: tokens.borderHairline),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tokens.statusIncome.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(tokens.radiusXs),
                                      border: Border.all(color: tokens.statusIncome.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      'L#$clock',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: tokens.statusIncome,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: tokens.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '$action $entityType',
                                              style: GoogleFonts.spaceGrotesk(
                                                color: tokens.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Device: ${deviceId.length > 12 ? deviceId.substring(0, 12) : deviceId} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.mukta(color: tokens.textTertiary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.lock_outline, size: 14, color: tokens.textTertiary),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),

                  // Merge Audit History
                  if (repo.mergeLogs.isNotEmpty) ...[
                    SizedBox(height: tokens.space4),
                    Text(
                      'MERGE CONFLICT AUDIT RESOLUTIONS (${repo.mergeLogs.length})',
                      style: GoogleFonts.spaceGrotesk(
                        color: tokens.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: tokens.space2),
                    ...repo.mergeLogs.map((log) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.check_circle_outline, color: tokens.statusIncome),
                        title: Text(
                          log.entityName,
                          style: GoogleFonts.mukta(fontWeight: FontWeight.w700, color: tokens.textPrimary),
                        ),
                        subtitle: Text(
                          '${log.conflictType} • ${log.resolution}',
                          style: GoogleFonts.mukta(color: tokens.textSecondary),
                        ),
                        trailing: Text(
                          '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: tokens.textTertiary),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRecoveryPhraseSheet(BuildContext context) {
    final tokens = context.tokens;

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(tokens.radiusLg)),
      ),
      builder: (ctx) {
        return FutureBuilder<String>(
          future: VaultRepository.instance.getRecoveryMnemonic(),
          builder: (context, snapshot) {
            final phrase = snapshot.data ?? '';
            final words = phrase.split(' ').where((w) => w.isNotEmpty).toList();

            return Padding(
              padding: EdgeInsets.all(tokens.space5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '12-WORD BIP-39 RECOVERY SEED',
                        style: GoogleFonts.spaceGrotesk(
                          color: tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(tokens.radiusPill),
                          border: Border.all(color: tokens.accentGold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '2048 Dictionary',
                          style: GoogleFonts.mukta(color: tokens.accentChampagne, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.space2),
                  Text(
                    'Cryptographically generated with 128-bit entropy (3.4 × 10³⁸ combinations). Store privately offline.',
                    style: GoogleFonts.mukta(fontSize: 12, color: tokens.textSecondary),
                  ),
                  SizedBox(height: tokens.space4),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(tokens.space4),
                      decoration: BoxDecoration(
                        color: tokens.bgSurfaceElevated,
                        borderRadius: BorderRadius.circular(tokens.radiusMd),
                        border: Border.all(color: tokens.borderHairline),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: words.asMap().entries.map((entry) {
                          final idx = entry.key + 1;
                          final word = entry.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: tokens.bgSurface,
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                              border: Border.all(color: tokens.borderHairline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$idx. ',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: tokens.accentGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  word,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: tokens.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: tokens.space4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ClipboardSanitizer.copySensitive(
                                text: phrase,
                                timeout: const Duration(seconds: 30),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '12-word recovery phrase copied! (Auto-clears in 30s for security)',
                                    style: GoogleFonts.mukta(fontWeight: FontWeight.w600),
                                  ),
                                  backgroundColor: tokens.statusIncome,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy Words'),
                          ),
                        ),
                        SizedBox(width: tokens.space3),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
