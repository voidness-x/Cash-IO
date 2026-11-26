import 'package:flutter/material.dart';
import '../models/finance_models.dart';
import 'database_helper.dart';
import '../security/hardware_vault_service.dart';
import '../security/bip39_wordlist.dart';
import '../sync/crdt_sync_engine.dart';
import '../sync/google_drive_service.dart';

class VaultRepository extends ChangeNotifier {
  static final VaultRepository instance = VaultRepository._internal();
  VaultRepository._internal();

  String _profileId = 'default_profile';
  String _profileName = 'Personal Vault';
  String _baseCurrency = 'IQD';
  bool _onlineFxSync = false;
  int _availableToAssignCents = 0;

  final List<AccountModel> _accounts = [];
  final List<TransactionModel> _transactions = [];
  final List<EnvelopeModel> _envelopes = [];
  final List<MergeAuditLogModel> _mergeLogs = [];
  final List<RecurringTransactionModel> _recurringTransactions = [];
  final List<SavingsGoalModel> _savingsGoals = [];
  String _secondaryCurrency = 'USD';

  // Getters
  String get profileId => _profileId;
  String get profileName => _profileName;
  String get baseCurrency => _baseCurrency;
  String get secondaryCurrency => _secondaryCurrency;
  bool get onlineFxSync => _onlineFxSync;
  int get availableToAssignCents => _availableToAssignCents;

  List<AccountModel> get accounts => List.unmodifiable(_accounts);
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<EnvelopeModel> get envelopes => List.unmodifiable(_envelopes);
  List<MergeAuditLogModel> get mergeLogs => List.unmodifiable(_mergeLogs);
  List<RecurringTransactionModel> get recurringTransactions => List.unmodifiable(_recurringTransactions);
  List<SavingsGoalModel> get savingsGoals => List.unmodifiable(_savingsGoals);

  static int _idCounter = 0;
  static String _generateUniqueId(String prefix) {
    _idCounter++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  static const String _placeholderProfileId = 'default_profile';

  final Map<String, _VaultSnapshot> _inMemoryVaultSnapshots = {};

  void _snapshotCurrentVault() {
    if (_profileId.isEmpty || _profileId == _placeholderProfileId) return;
    _inMemoryVaultSnapshots[_profileId] = _VaultSnapshot(
      name: _profileName,
      currency: _baseCurrency,
      accounts: List.from(_accounts),
      transactions: List.from(_transactions),
      envelopes: List.from(_envelopes),
      recurringTransactions: List.from(_recurringTransactions),
      savingsGoals: List.from(_savingsGoals),
    );
  }

  void setSecondaryCurrency(String curr) {
    _secondaryCurrency = curr;
    notifyListeners();
  }

  // Net Worth: Total Assets - Total Liabilities
  int get totalAssetsCents {
    return _accounts
        .where((a) => a.type == AccountType.asset)
        .fold(0, (sum, a) => sum + a.balanceCents);
  }

  int get totalLiabilitiesCents {
    return _accounts
        .where((a) => a.type == AccountType.liability)
        .fold(0, (sum, a) => sum + a.balanceCents);
  }

  int get netWorthCents => totalAssetsCents - totalLiabilitiesCents;

  int get last30DaysIncomeCents {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    int income = 0;
    for (final tx in _transactions) {
      if (tx.timestamp.isAfter(thirtyDaysAgo)) {
        for (final p in tx.postings) {
          final acc = _findAccount(p.accountId);
          if (acc != null && acc.type == AccountType.income && p.amountCents < 0) {
            income += p.amountCents.abs();
          }
        }
      }
    }
    return income;
  }

  int get last30DaysExpenseCents {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    int expense = 0;
    for (final tx in _transactions) {
      if (tx.timestamp.isAfter(thirtyDaysAgo)) {
        for (final p in tx.postings) {
          final acc = _findAccount(p.accountId);
          if (acc != null && acc.type == AccountType.expense && p.amountCents > 0) {
            expense += p.amountCents;
          }
        }
      }
    }
    return expense;
  }

  AccountModel? _findAccount(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Category breakdown of all expenses over the given period (default 30 days)
  Map<String, int> getCategorySpendingCents({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final Map<String, int> result = {};

    for (final tx in _transactions) {
      if (tx.timestamp.isAfter(cutoff)) {
        for (final p in tx.postings) {
          final acc = _findAccount(p.accountId);
          if (acc != null && acc.type == AccountType.expense && p.amountCents > 0) {
            String catName = acc.name.replaceFirst(RegExp(r'^Expenses:\s*'), '');
            result[catName] = (result[catName] ?? 0) + p.amountCents;
          }
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Multi-Currency Offline FX Conversion Matrix
  // ---------------------------------------------------------------------------
  static final Map<String, double> _usdRates = {
    'USD': 1.0,
    'IQD': 1310.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'SAR': 3.75,
    'AED': 3.67,
  };

  /// Converts cents in `fromCurr` to cents in `toCurr`
  int convertCents(int cents, String fromCurr, String toCurr) {
    if (fromCurr == toCurr) return cents;
    final fromRate = _usdRates[fromCurr] ?? 1.0;
    final toRate = _usdRates[toCurr] ?? 1.0;
    final inUsd = (cents / 100.0) / fromRate;
    final inTarget = inUsd * toRate;
    return (inTarget * 100.0).round();
  }

  // ---------------------------------------------------------------------------
  // Recurring Subscriptions & Scheduled Transactions Engine
  // ---------------------------------------------------------------------------
  Future<void> addRecurringTransaction({
    required String title,
    required int amountCents,
    required String sourceAccountId,
    required String destinationAccountId,
    required RecurringInterval interval,
    required DateTime nextDueDate,
    bool isExpense = true,
    bool autoPost = false,
    IconData icon = Icons.repeat_rounded,
  }) async {
    final item = RecurringTransactionModel(
      id: _generateUniqueId('rec'),
      title: title,
      amountCents: amountCents,
      sourceAccountId: sourceAccountId,
      destinationAccountId: destinationAccountId,
      interval: interval,
      nextDueDate: nextDueDate,
      isExpense: isExpense,
      autoPost: autoPost,
      icon: icon,
    );
    _recurringTransactions.add(item);
    notifyListeners();
  }

  Future<bool> postDueRecurringTransaction(String id) async {
    final index = _recurringTransactions.indexWhere((r) => r.id == id);
    if (index == -1) return false;

    final item = _recurringTransactions[index];
    final postings = item.isExpense
        ? [
            PostingModel(accountId: item.destinationAccountId, amountCents: item.amountCents),
            PostingModel(accountId: item.sourceAccountId, amountCents: -item.amountCents),
          ]
        : [
            PostingModel(accountId: item.sourceAccountId, amountCents: item.amountCents),
            PostingModel(accountId: item.destinationAccountId, amountCents: -item.amountCents),
          ];

    final success = await recordTransaction(
      description: 'Scheduled: ${item.title}',
      postings: postings,
      note: 'Recurring schedule (${item.interval.name})',
    );

    if (success) {
      _recurringTransactions[index] = item.copyWith(
        nextDueDate: item.calculateNextDate(),
      );
      notifyListeners();
    }
    return success;
  }

  void removeRecurringTransaction(String id) {
    _recurringTransactions.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Savings Goals & Locked Vaults Operations
  // ---------------------------------------------------------------------------
  Future<void> addSavingsGoal({
    required String name,
    required int targetAmountCents,
    required DateTime targetDate,
    bool isLocked = false,
    IconData icon = Icons.savings_outlined,
    int initialDepositCents = 0,
  }) async {
    final goal = SavingsGoalModel(
      id: _generateUniqueId('goal'),
      name: name,
      targetAmountCents: targetAmountCents,
      currentBalanceCents: initialDepositCents,
      targetDate: targetDate,
      isLocked: isLocked,
      icon: icon,
    );
    _savingsGoals.add(goal);
    notifyListeners();
  }

  Future<bool> depositToGoal(String goalId, int amountCents, {String? sourceAssetAccountId}) async {
    final index = _savingsGoals.indexWhere((g) => g.id == goalId);
    if (index == -1 || amountCents <= 0) return false;

    final goal = _savingsGoals[index];
    final assetAccounts = _accounts.where((a) => a.type == AccountType.asset).toList();
    final sourceId = sourceAssetAccountId ?? (assetAccounts.isNotEmpty ? assetAccounts.first.id : null);

    if (sourceId != null) {
      final updatedBalance = goal.currentBalanceCents + amountCents;
      _savingsGoals[index] = goal.copyWith(currentBalanceCents: updatedBalance);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> withdrawFromGoal(String goalId, int amountCents, {required String targetAssetAccountId}) async {
    final index = _savingsGoals.indexWhere((g) => g.id == goalId);
    if (index == -1 || amountCents <= 0) return false;

    final goal = _savingsGoals[index];
    if (goal.isLocked) return false; // Locked vault requires explicit unlock first
    if (goal.currentBalanceCents < amountCents) return false;

    final updatedBalance = goal.currentBalanceCents - amountCents;
    _savingsGoals[index] = goal.copyWith(currentBalanceCents: updatedBalance);
    notifyListeners();
    return true;
  }

  void toggleGoalLock(String goalId, bool locked) {
    final index = _savingsGoals.indexWhere((g) => g.id == goalId);
    if (index != -1) {
      _savingsGoals[index] = _savingsGoals[index].copyWith(isLocked: locked);
      notifyListeners();
    }
  }

  void removeSavingsGoal(String goalId) {
    _savingsGoals.removeWhere((g) => g.id == goalId);
    notifyListeners();
  }

  /// Asynchronously loads persistent SQLite data for this profile into memory
  Future<void> loadPersistentVault(String profileId) async {
    _snapshotCurrentVault();

    _profileId = profileId;
    if (_inMemoryVaultSnapshots.containsKey(profileId)) {
      final snap = _inMemoryVaultSnapshots[profileId]!;
      _profileName = snap.name;
      _baseCurrency = snap.currency;
      _accounts.clear();
      _accounts.addAll(snap.accounts);
      _transactions.clear();
      _transactions.addAll(snap.transactions);
      _envelopes.clear();
      _envelopes.addAll(snap.envelopes);
      _recurringTransactions.clear();
      _recurringTransactions.addAll(snap.recurringTransactions);
      _savingsGoals.clear();
      _savingsGoals.addAll(snap.savingsGoals);
    } else {
      _accounts.clear();
      _transactions.clear();
      _envelopes.clear();
      _recurringTransactions.clear();
      _savingsGoals.clear();
    }

    try {
      final profileData = await DatabaseHelper.instance.getProfile(profileId).timeout(const Duration(seconds: 2));
      if (profileData != null) {
        _profileName = profileData['name'] as String? ?? _profileName;
        _baseCurrency = profileData['currency'] as String? ?? _baseCurrency;
      }

      final dbAccounts = await DatabaseHelper.instance.getAccounts(profileId).timeout(const Duration(seconds: 2));
      if (dbAccounts.isNotEmpty) {
        _accounts.clear();
        _accounts.addAll(dbAccounts);
      }

      final dbTxs = await DatabaseHelper.instance.getTransactions(profileId).timeout(const Duration(seconds: 2));
      if (dbTxs.isNotEmpty) {
        _transactions.clear();
        _transactions.addAll(dbTxs);
      }

      final dbEnvelopes = await DatabaseHelper.instance.getEnvelopes(profileId).timeout(const Duration(seconds: 2));
      if (dbEnvelopes.isNotEmpty) {
        _envelopes.clear();
        _envelopes.addAll(dbEnvelopes);
      }
    } catch (e) {
      debugPrint('Notice loading persistent vault: $e');
    }

    // Calculate Available to Assign
    final totalAssigned = _envelopes.fold(0, (sum, e) => sum + e.assignedCents);
    _availableToAssignCents = totalAssetsCents - totalAssigned;

    _snapshotCurrentVault();
    notifyListeners();
  }

  /// Lists all known real user profiles in the database or active profile fallback,
  /// filtering out the uninitialized placeholder `default_profile` so users never see an un-openable ghost vault.
  Future<List<Map<String, dynamic>>> getAvailableProfiles() async {
    _snapshotCurrentVault();
    final Map<String, Map<String, dynamic>> combined = {};

    for (final entry in _inMemoryVaultSnapshots.entries) {
      if (entry.key == _placeholderProfileId) continue;
      combined[entry.key] = {
        'id': entry.key,
        'name': entry.value.name,
        'currency': entry.value.currency,
      };
    }

    try {
      final dbList = await DatabaseHelper.instance.getAllProfiles().timeout(const Duration(seconds: 2));
      for (final p in dbList) {
        final id = p['id'] as String;
        if (id == _placeholderProfileId) continue;
        combined[id] = p;
      }
    } catch (_) {}

    if (combined.isNotEmpty) return combined.values.toList();

    if (_profileId.isNotEmpty && _profileId != _placeholderProfileId) {
      return [
        {
          'id': _profileId,
          'name': _profileName,
          'currency': _baseCurrency,
        }
      ];
    }

    return const [];
  }

  /// Switches active vault after verifying PIN against hardware keystore
  Future<bool> switchVault(String profileId, String enteredPin) async {
    final isValid = await HardwareVaultService.instance.verifyPin(profileId, enteredPin);
    if (!isValid) return false;

    await loadPersistentVault(profileId);
    return true;
  }

  /// Creates and activates a new secondary cryptographic vault with isolated PIN & seed
  Future<String> createSecondaryVault({
    required String name,
    required String currency,
    required String pin,
    String? mnemonic,
  }) async {
    final newProfileId = _generateUniqueId('profile');
    final salt = HardwareVaultService.instance.generateProfileSalt();
    final effectiveMnemonic = mnemonic ?? Bip39Helper.generateMnemonic().join(' ');

    await HardwareVaultService.instance.saveProfileVaultCredentials(
      profileId: newProfileId,
      pin: pin,
      salt: salt,
      mnemonic: effectiveMnemonic,
    );

    try {
      await DatabaseHelper.instance.saveProfile(
        id: newProfileId,
        name: name,
        currency: currency,
        pinSalt: salt,
        seedHash: HardwareVaultService.instance.hashPin(effectiveMnemonic, salt),
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Persistence notice (saveProfile secondary): $e');
    }

    _snapshotCurrentVault();

    // Switch to the newly created vault
    _profileId = newProfileId;
    _profileName = name;
    _baseCurrency = currency;
    _accounts.clear();
    _transactions.clear();
    _envelopes.clear();
    _recurringTransactions.clear();
    _savingsGoals.clear();

    await addAccount(
      name: 'Cash Wallet',
      type: AccountType.asset,
      currency: currency,
      initialBalanceCents: 0,
      icon: Icons.wallet_outlined,
    );
    await addAccount(
      name: 'Primary Bank',
      type: AccountType.asset,
      currency: currency,
      initialBalanceCents: 0,
      icon: Icons.account_balance_outlined,
    );
    await addAccount(
      name: 'Daily Expenses',
      type: AccountType.expense,
      currency: currency,
      initialBalanceCents: 0,
      icon: Icons.shopping_bag_outlined,
    );

    _snapshotCurrentVault();
    notifyListeners();
    return newProfileId;
  }

  Future<void> initializeProfile({
    required String name,
    required String currency,
    required bool onlineFx,
    String? pin,
    String? mnemonic,
  }) async {
    _profileId = _generateUniqueId('profile');
    _profileName = name;
    _baseCurrency = currency;
    _onlineFxSync = onlineFx;
    _accounts.clear();
    _transactions.clear();
    _envelopes.clear();
    _recurringTransactions.clear();
    _savingsGoals.clear();

    // Hardware Vault setup
    final salt = HardwareVaultService.instance.generateProfileSalt();
    final effectivePin = pin ?? '123456';
    final effectiveMnemonic = mnemonic ?? Bip39Helper.generateMnemonic().join(' ');

    await HardwareVaultService.instance.saveProfileVaultCredentials(
      profileId: _profileId,
      pin: effectivePin,
      salt: salt,
      mnemonic: effectiveMnemonic,
    );

    try {
      await DatabaseHelper.instance.saveProfile(
        id: _profileId,
        name: name,
        currency: currency,
        pinSalt: salt,
        seedHash: HardwareVaultService.instance.hashPin(effectiveMnemonic, salt),
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Persistence notice (saveProfile): $e');
    }

    try {
      // Seed clean foundational double-entry accounts in user's selected base currency
      await addAccount(
        name: 'Cash Wallet',
        type: AccountType.asset,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.wallet_outlined,
      );
      await addAccount(
        name: 'Primary Bank',
        type: AccountType.asset,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.account_balance_outlined,
      );
      await addAccount(
        name: 'Daily Expenses',
        type: AccountType.expense,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.shopping_bag_outlined,
      );
      await addAccount(
        name: 'Income & Salary',
        type: AccountType.income,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.payments_outlined,
      );
    } catch (_) {}

    _snapshotCurrentVault();
    notifyListeners();
  }

  /// Eases the user into Cash-IO by recording opening Cash & Bank balances via strict
  /// zero-sum double-entry transactions (`Opening Balances` -> Asset) and optionally
  /// provisioning 50/30/20 starter budget envelopes and an Emergency Reserve goal vault.
  Future<void> setupInitialFinancialData({
    required int startingCashCents,
    int startingBankCents = 0,
    bool createStarterEnvelopes = true,
    int emergencyGoalTargetCents = 0,
  }) async {
    final currency = _baseCurrency;

    // Ensure Cash Wallet, Primary Bank, and Opening Balances accounts exist
    AccountModel? cashAcc = _accounts
        .where((a) => a.type == AccountType.asset && a.name.toLowerCase().contains('cash'))
        .firstOrNull;
    if (cashAcc == null) {
      await addAccount(
        name: 'Cash Wallet',
        type: AccountType.asset,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.wallet_outlined,
      );
      cashAcc = _accounts.where((a) => a.type == AccountType.asset).first;
    }

    AccountModel? bankAcc = _accounts
        .where((a) => a.type == AccountType.asset && a.name.toLowerCase().contains('bank'))
        .firstOrNull;
    if (bankAcc == null) {
      await addAccount(
        name: 'Primary Bank',
        type: AccountType.asset,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.account_balance_outlined,
      );
      bankAcc = _accounts.where((a) => a.type == AccountType.asset).last;
    }

    AccountModel? openingEquity = _accounts
        .where((a) => a.type == AccountType.income && a.name == 'Opening Balances')
        .firstOrNull;
    if ((startingCashCents > 0 || startingBankCents > 0) && openingEquity == null) {
      await addAccount(
        name: 'Opening Balances',
        type: AccountType.income,
        currency: currency,
        initialBalanceCents: 0,
        icon: Icons.flag_outlined,
      );
      openingEquity = _accounts
          .where((a) => a.type == AccountType.income && a.name == 'Opening Balances')
          .first;
    }

    if (startingCashCents > 0 && openingEquity != null) {
      await recordTransaction(
        description: 'Opening Cash Balance',
        postings: [
          PostingModel(accountId: cashAcc.id, amountCents: startingCashCents),
          PostingModel(accountId: openingEquity.id, amountCents: -startingCashCents),
        ],
        note: 'Initial cash setup',
      );
    }

    if (startingBankCents > 0 && openingEquity != null) {
      await recordTransaction(
        description: 'Opening Bank Balance',
        postings: [
          PostingModel(accountId: bankAcc.id, amountCents: startingBankCents),
          PostingModel(accountId: openingEquity.id, amountCents: -startingBankCents),
        ],
        note: 'Initial bank setup',
      );
    }

    final totalLiquid = totalAssetsCents;
    final totalAssigned = _envelopes.fold<int>(0, (sum, e) => sum + e.assignedCents);
    _availableToAssignCents = totalLiquid - totalAssigned;

    if (createStarterEnvelopes && _envelopes.isEmpty) {
      final baseline = totalLiquid > 0
          ? totalLiquid
          : (currency == 'IQD' ? 50000000 : 100000);
      final needsTarget = (baseline * 0.50).round();
      final wantsTarget = (baseline * 0.30).round();
      final bufferTarget = (baseline * 0.20).round();

      await addEnvelope(
        name: 'Essentials & Groceries',
        targetCents: needsTarget,
        icon: Icons.shopping_basket_outlined,
      );
      await addEnvelope(
        name: 'Bills & Transport',
        targetCents: wantsTarget,
        icon: Icons.directions_car_outlined,
      );
      await addEnvelope(
        name: 'Personal & Dining',
        targetCents: bufferTarget,
        icon: Icons.local_cafe_outlined,
      );

      // Auto-allocate 80% of starting cash across starter envelopes if user funded vault
      if (totalLiquid > 0 && _envelopes.length >= 3) {
        final e0 = (totalLiquid * 0.45).round();
        final e1 = (totalLiquid * 0.20).round();
        final e2 = (totalLiquid * 0.15).round();
        await assignToEnvelope(_envelopes[0].id, e0);
        await assignToEnvelope(_envelopes[1].id, e1);
        await assignToEnvelope(_envelopes[2].id, e2);
      }
    }

    if (emergencyGoalTargetCents > 0 && _savingsGoals.isEmpty) {
      final openingReserve = totalLiquid > 0 ? (totalLiquid * 0.10).round() : 0;
      await addSavingsGoal(
        name: 'Emergency Reserve',
        targetAmountCents: emergencyGoalTargetCents,
        targetDate: DateTime.now().add(const Duration(days: 180)),
        isLocked: true,
        icon: Icons.shield_outlined,
        initialDepositCents: openingReserve,
      );
    }

    _snapshotCurrentVault();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Account Operations
  // ---------------------------------------------------------------------------
  Future<void> addAccount({
    required String name,
    required AccountType type,
    required String currency,
    int initialBalanceCents = 0,
    IconData icon = Icons.account_balance_wallet_outlined,
  }) async {
    final account = AccountModel(
      id: _generateUniqueId('acc'),
      name: name,
      type: type,
      currency: currency,
      balanceCents: initialBalanceCents,
      icon: icon,
    );
    _accounts.add(account);

    if (type == AccountType.asset && initialBalanceCents > 0) {
      _availableToAssignCents += initialBalanceCents;
    }

    notifyListeners();

    // Persist to SQLite & CRDT with timeout protection
    try {
      await DatabaseHelper.instance.insertAccount(_profileId, account).timeout(const Duration(seconds: 2));
      final event = CrdtSyncEngine.instance.createMutationEvent(
        profileId: _profileId,
        entityType: 'account',
        entityId: account.id,
        action: 'create',
        payload: {
          'name': account.name,
          'type': account.type.name,
          'currency': account.currency,
          'balance_cents': account.balanceCents,
        },
      );
      await DatabaseHelper.instance.insertCrdtEvent(event).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Persistence notice (addAccount): $e');
    }

    // Debounced background sync (~5s after edits)
    try {
      GoogleDriveService.instance.scheduleDebouncedSync();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Double-Entry Transaction Operations
  // ---------------------------------------------------------------------------
  Future<bool> recordTransaction({
    required String description,
    required List<PostingModel> postings,
    List<String> receiptPaths = const [],
    String? note,
  }) async {
    final sum = postings.fold<int>(0, (acc, p) => acc + p.amountCents);
    if (sum != 0) return false;

    final tx = TransactionModel(
      id: _generateUniqueId('tx'),
      timestamp: DateTime.now(),
      description: description,
      postings: postings,
      receiptPaths: receiptPaths,
      note: note,
    );

    _transactions.insert(0, tx);

    for (final p in postings) {
      final index = _accounts.indexWhere((a) => a.id == p.accountId);
      if (index != -1) {
        final acc = _accounts[index];
        int newBalance = acc.balanceCents;
        if (acc.type == AccountType.asset || acc.type == AccountType.expense) {
          newBalance += p.amountCents;
        } else {
          newBalance += (-p.amountCents);
        }
        _accounts[index] = acc.copyWith(balanceCents: newBalance);
        try {
          await DatabaseHelper.instance.updateAccountBalance(acc.id, newBalance).timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Persistence notice (updateAccountBalance): $e');
        }
      }
    }

    notifyListeners();

    // Persist to SQLite & CRDT with timeout protection
    try {
      await DatabaseHelper.instance.insertTransaction(_profileId, tx).timeout(const Duration(seconds: 2));
      final event = CrdtSyncEngine.instance.createMutationEvent(
        profileId: _profileId,
        entityType: 'transaction',
        entityId: tx.id,
        action: 'create',
        payload: {
          'description': tx.description,
          'timestamp_ms': tx.timestamp.millisecondsSinceEpoch,
          'postings': tx.postings.map((p) => {'account_id': p.accountId, 'amount_cents': p.amountCents}).toList(),
        },
      );
      await DatabaseHelper.instance.insertCrdtEvent(event).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Persistence notice (insertTransaction): $e');
    }

    // Debounced background sync (~5s after edits)
    try {
      GoogleDriveService.instance.scheduleDebouncedSync();
    } catch (_) {}
    return true;
  }

  // ---------------------------------------------------------------------------
  // Envelope Budgeting Operations
  // ---------------------------------------------------------------------------
  Future<void> addEnvelope({
    required String name,
    required int targetCents,
    IconData icon = Icons.folder_outlined,
  }) async {
    final envelope = EnvelopeModel(
      id: _generateUniqueId('env'),
      name: name,
      assignedCents: 0,
      spentCents: 0,
      targetCents: targetCents,
      icon: icon,
    );
    _envelopes.add(envelope);
    notifyListeners();

    try {
      await DatabaseHelper.instance.insertEnvelope(_profileId, envelope).timeout(const Duration(seconds: 2));
      final event = CrdtSyncEngine.instance.createMutationEvent(
        profileId: _profileId,
        entityType: 'envelope',
        entityId: envelope.id,
        action: 'create',
        payload: {
          'name': envelope.name,
          'assigned_cents': envelope.assignedCents,
          'target_cents': envelope.targetCents,
        },
      );
      await DatabaseHelper.instance.insertCrdtEvent(event).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Persistence notice (insertEnvelope): $e');
    }

    try {
      GoogleDriveService.instance.scheduleDebouncedSync();
    } catch (_) {}
  }

  Future<void> assignToEnvelope(String envelopeId, int centsToAssign) async {
    final index = _envelopes.indexWhere((e) => e.id == envelopeId);
    if (index != -1) {
      final env = _envelopes[index];
      final newAssigned = env.assignedCents + centsToAssign;
      _envelopes[index] = env.copyWith(assignedCents: newAssigned);
      _availableToAssignCents -= centsToAssign;
      notifyListeners();

      try {
        await DatabaseHelper.instance.updateEnvelopeAssigned(envelopeId, newAssigned).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Persistence notice (updateEnvelopeAssigned): $e');
      }
      try {
        GoogleDriveService.instance.scheduleDebouncedSync();
      } catch (_) {}
    }
  }

  Future<void> recordEnvelopeSpend(String envelopeId, int spentCents) async {
    if (spentCents <= 0) return;
    final index = _envelopes.indexWhere((e) => e.id == envelopeId);
    if (index == -1) return;

    final env = _envelopes[index];
    final newSpent = env.spentCents + spentCents;
    _envelopes[index] = env.copyWith(spentCents: newSpent);
    _snapshotCurrentVault();
    notifyListeners();

    try {
      await DatabaseHelper.instance.updateEnvelopeSpent(envelopeId, newSpent).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Persistence notice (updateEnvelopeSpent): $e');
    }
    try {
      GoogleDriveService.instance.scheduleDebouncedSync();
    } catch (_) {}
  }

  Future<void> reallocateBudget({
    required String fromEnvelopeId,
    required String toEnvelopeId,
    required int cents,
  }) async {
    await assignToEnvelope(fromEnvelopeId, -cents);
    await assignToEnvelope(toEnvelopeId, cents);
  }

  // ---------------------------------------------------------------------------
  // Google Drive CRDT Sync & Audit History
  // ---------------------------------------------------------------------------
  void recordMergeAuditLog(MergeAuditLogModel log) {
    _mergeLogs.insert(0, log);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getCrdtEvents() async {
    return await DatabaseHelper.instance.getCrdtEvents(_profileId);
  }

  Future<void> triggerGoogleDriveSync() async {
    await GoogleDriveService.instance.syncNow();
  }

  // ---------------------------------------------------------------------------
  // Cryptographic Mnemonic Access
  // ---------------------------------------------------------------------------
  Future<String> getRecoveryMnemonic() async {
    final stored = await HardwareVaultService.instance.getRecoveryMnemonic(_profileId);
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    final fresh = Bip39Helper.generateMnemonic().join(' ');
    await HardwareVaultService.instance.saveProfileVaultCredentials(
      profileId: _profileId,
      pin: '123456',
      salt: HardwareVaultService.instance.generateProfileSalt(),
      mnemonic: fresh,
    );
    return fresh;
  }

  // ---------------------------------------------------------------------------
  // Emergency Snapshot State Restoration
  // ---------------------------------------------------------------------------
  /// Atomically restores full in-memory vault state from a verified emergency snapshot.
  void restoreFromEmergencySnapshot(Map<String, dynamic> data) {
    _profileId = data['profile_id'] as String? ?? _profileId;
    _profileName = data['profile_name'] as String? ?? _profileName;
    _baseCurrency = data['currency'] as String? ?? _baseCurrency;

    _accounts.clear();
    final accountsRaw = data['accounts'] as List<dynamic>? ?? const [];
    for (final raw in accountsRaw) {
      final a = Map<String, dynamic>.from(raw as Map);
      _accounts.add(AccountModel(
        id: a['id'] as String,
        name: a['name'] as String,
        type: AccountType.values.firstWhere(
          (t) => t.name == a['type'],
          orElse: () => AccountType.asset,
        ),
        currency: a['currency'] as String,
        balanceCents: a['balance_cents'] as int,
      ));
    }

    _transactions.clear();
    final txsRaw = data['transactions'] as List<dynamic>? ?? const [];
    for (final raw in txsRaw) {
      final t = Map<String, dynamic>.from(raw as Map);
      final postingsList = (t['postings'] as List<dynamic>? ?? const []).map((pRaw) {
        final p = Map<String, dynamic>.from(pRaw as Map);
        return PostingModel(
          accountId: p['account_id'] as String,
          amountCents: p['amount_cents'] as int,
        );
      }).toList();

      _transactions.add(TransactionModel(
        id: t['id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(t['timestamp_ms'] as int),
        description: t['description'] as String,
        postings: postingsList,
        receiptPaths: List<String>.from(t['receipt_paths'] as List<dynamic>? ?? const []),
        note: t['note'] as String?,
      ));
    }

    _envelopes.clear();
    final envRaw = data['envelopes'] as List<dynamic>? ?? const [];
    for (final raw in envRaw) {
      final e = Map<String, dynamic>.from(raw as Map);
      _envelopes.add(EnvelopeModel(
        id: e['id'] as String,
        name: e['name'] as String,
        assignedCents: e['assigned_cents'] as int? ?? 0,
        spentCents: e['spent_cents'] as int? ?? 0,
        targetCents: e['target_cents'] as int? ?? 0,
      ));
    }

    _savingsGoals.clear();
    final goalsRaw = data['savings_goals'] as List<dynamic>? ?? const [];
    for (final raw in goalsRaw) {
      final g = Map<String, dynamic>.from(raw as Map);
      _savingsGoals.add(SavingsGoalModel(
        id: g['id'] as String,
        name: g['name'] as String,
        targetAmountCents: g['target_cents'] as int,
        currentBalanceCents: g['current_cents'] as int,
        targetDate: DateTime.fromMillisecondsSinceEpoch(g['target_date_ms'] as int),
        isLocked: g['is_locked'] as bool? ?? true,
      ));
    }

    final totalAssigned = _envelopes.fold<int>(0, (sum, e) => sum + e.assignedCents);
    _availableToAssignCents = totalAssetsCents - totalAssigned;

    _snapshotCurrentVault();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CSV Export Utility (Hardened against CWE-1236 Formula Injection)
  // ---------------------------------------------------------------------------
  /// Neutralizes spreadsheet formula injection triggers (`=`, `+`, `-`, `@`, TAB, CR)
  /// and applies RFC 4180 double-quote escaping.
  static String sanitizeCsvCell(String raw) {
    String sanitized = raw.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (sanitized.isNotEmpty) {
      final first = sanitized[0];
      if (first == '=' || first == '+' || first == '-' || first == '@' || first == '\t' || first == '\r') {
        sanitized = "'$sanitized";
      }
    }
    final escaped = sanitized.replaceAll('"', '""');
    return '"$escaped"';
  }

  String exportTransactionsToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Date,Description,Account,Amount,Currency');
    for (final tx in _transactions) {
      for (final p in tx.postings) {
        final acc = _findAccount(p.accountId);
        final accName = acc?.name ?? 'Unknown';
        final amt = (p.amountCents / 100.0).toStringAsFixed(2);
        final safeDesc = sanitizeCsvCell(tx.description);
        final safeAcc = sanitizeCsvCell(accName);
        final safeCurr = sanitizeCsvCell(_baseCurrency);
        buffer.writeln('${tx.timestamp.toIso8601String()},$safeDesc,$safeAcc,$amt,$safeCurr');
      }
    }
    return buffer.toString();
  }
}

class _VaultSnapshot {
  final String name;
  final String currency;
  final List<AccountModel> accounts;
  final List<TransactionModel> transactions;
  final List<EnvelopeModel> envelopes;
  final List<RecurringTransactionModel> recurringTransactions;
  final List<SavingsGoalModel> savingsGoals;

  _VaultSnapshot({
    required this.name,
    required this.currency,
    required this.accounts,
    required this.transactions,
    required this.envelopes,
    required this.recurringTransactions,
    required this.savingsGoals,
  });
}
