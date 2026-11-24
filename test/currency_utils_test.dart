import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils Tests', () {
    test('IQD formats as integer without decimals with thousands separators', () {
      expect(CurrencyUtils.format(2500000, currency: 'IQD'), '25,000 IQD');
      expect(CurrencyUtils.format(150000000, currency: 'IQD'), '1,500,000 IQD');
      expect(CurrencyUtils.format(50000, currency: 'IQD'), '500 IQD');
      expect(CurrencyUtils.format(0, currency: 'IQD'), '0 IQD');
      expect(CurrencyUtils.format(-750000, currency: 'IQD'), '-7,500 IQD');
    });

    test('USD formats with two decimal places', () {
      expect(CurrencyUtils.format(12550, currency: 'USD'), '\$125.50');
      expect(CurrencyUtils.format(100, currency: 'USD'), '\$1.00');
      expect(CurrencyUtils.format(0, currency: 'USD'), '\$0.00');
      expect(CurrencyUtils.format(-5025, currency: 'USD'), '-\$50.25');
    });

    test('EUR, GBP, SAR, AED format with proper symbols', () {
      expect(CurrencyUtils.format(9900, currency: 'EUR'), '€99.00');
      expect(CurrencyUtils.format(4500, currency: 'GBP'), '£45.00');
      expect(CurrencyUtils.format(20000, currency: 'SAR'), '200.00 SAR');
      expect(CurrencyUtils.format(15000, currency: 'AED'), '150.00 AED');
    });

    test('parseToCents parses numbers and comma-separated amounts accurately', () {
      expect(CurrencyUtils.parseToCents('25000'), 2500000);
      expect(CurrencyUtils.parseToCents('1,500,000'), 150000000);
      expect(CurrencyUtils.parseToCents('125.50'), 12550);
      expect(CurrencyUtils.parseToCents('0'), 0);
      expect(CurrencyUtils.parseToCents('invalid'), 0);
    });
  });
}
