import 'dart:convert';

class ParsedVoskResult {
  const ParsedVoskResult({required this.text, this.averageConfidence});

  final String text;
  final double? averageConfidence;
}

ParsedVoskResult parseVoskPayload(
  final String rawPayload, {
  required final bool isFinal,
}) {
  try {
    final decoded = jsonDecode(rawPayload);
    if (decoded is! Map<String, dynamic>) {
      return const ParsedVoskResult(text: '');
    }

    final key = isFinal ? 'text' : 'partial';
    final rawText = decoded[key]?.toString() ?? '';
    final words = decoded['result'];

    return ParsedVoskResult(
      text: _normalizeWhitespace(rawText),
      averageConfidence: _extractAverageConfidence(words),
    );
  } on FormatException {
    return ParsedVoskResult(text: _normalizeWhitespace(rawPayload));
  }
}

bool isMeaningfulPreview(final String text) {
  final normalized = _normalizeWhitespace(text);
  if (normalized.isEmpty || normalized.length == 1) {
    return false;
  }

  return _containsSpeechLikeCharacters(normalized);
}

bool shouldCommitResult(final ParsedVoskResult result) {
  if (!isMeaningfulPreview(result.text)) {
    return false;
  }

  final words = result.text.split(' ').where((final value) => value.isNotEmpty);
  final confidence = result.averageConfidence;
  if (confidence != null && confidence < 0.45 && words.length <= 2) {
    return false;
  }

  return true;
}

String _normalizeWhitespace(final String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

double? _extractAverageConfidence(final Object? words) {
  if (words is! List) {
    return null;
  }

  final values = <double>[];
  for (final item in words) {
    if (item is Map && item['conf'] is num) {
      values.add((item['conf'] as num).toDouble());
    }
  }

  if (values.isEmpty) {
    return null;
  }

  final sum = values.fold<double>(
    0,
    (final total, final value) => total + value,
  );
  return sum / values.length;
}

bool _containsSpeechLikeCharacters(final String text) {
  for (final rune in text.runes) {
    if (_isSpeechLikeRune(rune)) {
      return true;
    }
  }

  return false;
}

bool _isSpeechLikeRune(final int rune) {
  final isAsciiDigit = rune >= 0x30 && rune <= 0x39;
  final isAsciiUppercase = rune >= 0x41 && rune <= 0x5A;
  final isAsciiLowercase = rune >= 0x61 && rune <= 0x7A;

  if (isAsciiDigit || isAsciiUppercase || isAsciiLowercase) {
    return true;
  }

  if (rune <= 0x7F) {
    return false;
  }

  return String.fromCharCode(rune).trim().isNotEmpty;
}
