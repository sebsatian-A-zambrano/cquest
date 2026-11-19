import 'package:cquest/main.dart';
import 'package:cquest/src/campaign.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the RPG keeps all 28 coding challenges', () async {
    final campaign = await loadCampaign();
    expect(campaign, hasLength(28));
    expect(campaign.map((lab) => lab.id).toSet(), hasLength(28));
    expect(campaign.take(14).every((lab) => lab.language == 'alg'), isTrue);
    expect(campaign.skip(14).every((lab) => lab.language == 'c'), isTrue);
    expect(campaign.last.editable, containsAll(['reglas.c', 'informe.c']));
  });

  testWidgets('walking to Nico opens a route decision inside the scenario', (
    tester,
  ) async {
    await tester.pumpWidget(const CQuest());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
    final campaign = find.text('La noche sin faros');
    expect(campaign, findsOneWidget);
    await tester.ensureVisible(campaign);
    await tester.tap(campaign);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Embarcadero de Sal'), findsOneWidget);
    expect(find.text('Habla con Nico.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ayudar a asegurar el muelle'), findsOneWidget);
    expect(find.text('Buscar la reserva en las rocas'), findsOneWidget);
  });
}
