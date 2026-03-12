import 'package:flutter_test/flutter_test.dart';
import 'package:stt_pro/src/services/vosk_result_parser.dart';

void main() {
  group('parseVoskPayload', () {
    test('reads final text and confidence', () {
      final parsed = parseVoskPayload(
        '{"text":"ciao mondo","result":[{"conf":0.90},{"conf":0.80}]}',
        isFinal: true,
      );

      expect(parsed.text, 'ciao mondo');
      expect(parsed.averageConfidence, closeTo(0.85, 0.001));
    });

    test('reads partial text', () {
      final parsed = parseVoskPayload('{"partial":"ciao"}', isFinal: false);

      expect(parsed.text, 'ciao');
      expect(parsed.averageConfidence, isNull);
    });
  });

  group('shouldCommitResult', () {
    test('rejects empty or single-char output', () {
      expect(shouldCommitResult(const ParsedVoskResult(text: '')), isFalse);
      expect(shouldCommitResult(const ParsedVoskResult(text: 'a')), isFalse);
    });

    test('rejects low-confidence short noise', () {
      expect(
        shouldCommitResult(
          const ParsedVoskResult(text: 'eh', averageConfidence: 0.20),
        ),
        isFalse,
      );
    });

    test('accepts normal speech-like results', () {
      expect(
        shouldCommitResult(
          const ParsedVoskResult(text: 'ciao a tutti', averageConfidence: 0.82),
        ),
        isTrue,
      );
    });
  });
}
