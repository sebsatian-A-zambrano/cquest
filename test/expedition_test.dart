import 'dart:math';

import 'package:cquest/src/expedition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'each world supports both routes and changes collision after a repair',
    () {
      for (final map in expeditionMaps) {
        final progress = ExpeditionProgress();
        expect(
          map.findPath(map.spawn, map.at('N'), progress, nearby: true),
          isNotNull,
        );
        for (final choice in [0, 1]) {
          progress.choice = choice;
          final charge = map.at(choice == 0 ? 'A' : 'D');
          expect(
            map.findPath(map.spawn, charge, progress, nearby: true),
            isNotNull,
          );
          expect(
            map.findPath(charge, map.at('O'), progress, nearby: true),
            isNotNull,
          );
        }
        expect(map.findPath(map.spawn, map.at('G'), progress), isNull);
        expect(map.walkable(map.at('B'), progress), isFalse);
        progress.repaired = true;
        expect(map.walkable(map.at('B'), progress), isTrue);
        expect(map.findPath(map.spawn, map.at('G'), progress), isNotNull);
      }
    },
  );

  test('the journal round trips a decision and discards invalid positions', () {
    final map = expeditionMaps.first;
    final old = ExpeditionProgress(
      choice: 1,
      charged: true,
      memory: true,
      repaired: true,
    );
    final saved = ExpeditionProgress.decode(
      old.encode(const Point<int>(999, -1)),
    );
    expect(saved.choice, 1);
    expect(saved.xp, 95);
    expect(saved.charged && saved.memory && saved.repaired, isTrue);
    expect(map.walkable(saved.position!, saved), isFalse);
    expect(ExpeditionProgress.decode('bad json').choice, isNull);
  });
}
