import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/domain/identity/league_identity.dart';

void main() {
  group('League identity value objects', () {
    test('normalizes platforms and preserves composite match identity', () {
      final key = MatchKey(platformId: PlatformId(' la1 '), gameId: 42);

      expect(key.platformId.value, 'LA1');
      expect(key.toString(), 'LA1:42');
      expect(key, MatchKey(platformId: PlatformId('LA1'), gameId: 42));
      expect(key, isNot(MatchKey(platformId: PlatformId('LA2'), gameId: 42)));
    });

    test('rejects ambiguous patch keys and negative game time', () {
      expect(() => PatchKey('16.17.1'), throwsFormatException);
      expect(() => PatchKey('16_17'), throwsFormatException);
      expect(
        () => GameTime(const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
    });

    test('orders logical game time in integer milliseconds', () {
      final early = GameTime(const Duration(minutes: 10));
      final late = GameTime(const Duration(minutes: 10, milliseconds: 1));

      expect(early.compareTo(late), lessThan(0));
      expect(late.milliseconds, 600001);
    });
  });
}
