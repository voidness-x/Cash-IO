import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cash_io/main.dart';
import 'package:cash_io/core/widgets/cashio_logo.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Cash-IO Profile Setup Screen renders centered logo and prompt on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(const CashIOApp());
    await tester.pump();

    // Verify initial profile intro screen is rendered with brand subtitle
    expect(find.text('AIR-GAPPED ZERO-KNOWLEDGE LEDGER'), findsOneWidget);

    // Complete entrance animation (1200ms)
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(); // Triggers .then to start cipher timer

    // Advance periodic cipher timer to resolve characters
    for (int i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('CASH-IO', findRichText: true), findsOneWidget);
    expect(find.byType(CashIOLogo), findsOneWidget);
    expect(find.text('Swipe up or tap to start'), findsOneWidget);
  });
}
