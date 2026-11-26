import 'package:flutter_test/flutter_test.dart';
import 'package:kleihon/features/settings/privacy_policy.dart';

import '../helpers/fake_comic_source.dart';
import '../helpers/test_app.dart';

void main() {
  test('setiap bagian kebijakan punya judul dan isi', () {
    expect(privacySections, isNotEmpty);
    for (final section in privacySections) {
      expect(section.title.trim(), isNotEmpty);
      expect(section.body.trim(), isNotEmpty);
    }
  });

  testWidgets('halaman menampilkan semua bagian', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      testApp(
        source: FakeComicSource('local'),
        home: const PrivacyPolicyPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kebijakan Privasi KleiHon'), findsOneWidget);
    for (final section in privacySections) {
      expect(find.text(section.title), findsOneWidget);
      expect(find.text(section.body), findsOneWidget);
    }
  });
}
