/// High-performance currency formatting and locale utilities for Cash-IO.
/// Supports IQD (Iraqi Dinar) as default base currency with zero-decimal integer formatting.
class CurrencyUtils {
  CurrencyUtils._();

  static const List<Map<String, String>> supportedCurrencies = [
    {'code': 'IQD', 'name': 'Iraqi Dinar', 'symbol': 'ع.د'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'ر.س'},
    {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'CA\$'},
    {'code': 'TRY', 'name': 'Turkish Lira', 'symbol': '₺'},
  ];

  /// Formats an amount in minor units (cents) into a localized currency string.
  /// Example:
  /// - format(2500000, currency: 'IQD') -> '25,000 IQD'
  /// - format(12550, currency: 'USD') -> '$125.50'
  static String format(int amountCents, {String currency = 'IQD', bool showSymbol = true}) {
    final isNegative = amountCents < 0;
    final absCents = amountCents.abs();
    final isIqd = currency.toUpperCase() == 'IQD';

    final double units = absCents / 100.0;
    final int decimals = isIqd ? 0 : 2;

    final parts = units.toStringAsFixed(decimals).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    final formattedNumber = (parts.length > 1 && !isIqd)
        ? '$integerPart.${parts[1]}'
        : integerPart;

    final sign = isNegative ? '-' : '';

    if (!showSymbol) {
      return '$sign$formattedNumber';
    }

    switch (currency.toUpperCase()) {
      case 'IQD':
        return '$sign$formattedNumber IQD';
      case 'USD':
        return '$sign\$$formattedNumber';
      case 'EUR':
        return '$sign€$formattedNumber';
      case 'GBP':
        return '$sign£$formattedNumber';
      case 'SAR':
        return '$sign$formattedNumber SAR';
      case 'AED':
        return '$sign$formattedNumber AED';
      case 'JPY':
        return '$sign¥$formattedNumber';
      case 'CAD':
        return '$sign\$$formattedNumber CAD';
      default:
        return '$sign$formattedNumber $currency';
    }
  }

  /// Parses user text input into minor units (cents).
  static int parseToCents(String input) {
    final cleaned = input.replaceAll(',', '').trim();
    final value = double.tryParse(cleaned) ?? 0.0;
    return (value * 100).round();
  }
}
