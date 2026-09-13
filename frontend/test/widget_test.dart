
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_madura/main.dart';

void main() {
  testWidgets('App menampilkan halaman login', (WidgetTester tester) async {
    await tester.pumpWidget(const KasirMaduraApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Harus ada kolom username & password di layar login.
    expect(find.text('Masuk'), findsWidgets);
  });
}
