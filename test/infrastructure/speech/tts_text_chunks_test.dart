import 'package:flutter_test/flutter_test.dart';
import 'package:godsense/infrastructure/speech/tts/tts_text_chunks.dart';

void main() {
  test('short speech is unchanged and empty input does not synthesize', () {
    expect(ttsTextChunks('Hola, GodSense.').toList(), ['Hola, GodSense.']);
    expect(ttsTextChunks(' \n\t ').toList(), isEmpty);
    expect(
      () => ttsTextChunks('hola', maxRunes: 0).toList(),
      throwsArgumentError,
    );
  });
  test('long responses preserve words and prefer sentence boundaries', () {
    final text = List.filled(
      80,
      'Esta frase hace deliberadamente larga la síntesis.',
    ).join(' ');
    final chunks = ttsTextChunks(text).toList();
    expect(chunks.join(' '), text);
    expect(chunks.length, greaterThan(1));
    expect(chunks.every((chunk) => chunk.runes.length <= 160), true);
    expect(chunks.every((chunk) => chunk.endsWith('.')), true);
  });
  test('whitespace is normalized without dropping words', () {
    expect(
      ttsTextChunks(' uno\n dos\t tres cuatro ', maxRunes: 8).join(' '),
      'uno dos tres cuatro',
    );
  });
  test('unicode code points and long unbroken words are preserved', () {
    final text = List.filled(21, '🦉').join();
    final chunks = ttsTextChunks(text, maxRunes: 8).toList();
    expect(chunks.join(), text);
    expect(chunks.map((chunk) => chunk.runes.length), [8, 8, 5]);
  });
}
