/// Mappa i codici lingua interni dell'app (usati in [LanguagePack.code])
/// ai codici BCP-47 standard richiesti dal motore TTS nativo di Android/iOS.
///
/// I codici interni dell'app seguono le convenzioni Vosk (es. 'it', 'en-us',
/// 'cn', 'ua'). Alcuni differiscono dallo standard BCP-47 e vanno normalizzati.
///
/// Questo file NON modifica la pipeline STT/traduzione.
library;

/// Ritorna il codice BCP-47 corrispondente al codice lingua interno dell'app.
/// Se il codice non è mappato, ritorna `null`.
String? appCodeToBcp47(final String appCode) => _appCodeToBcp47Map[appCode];

/// Mappa completa codice-app → BCP-47.
/// Copre tutte le 16 lingue presenti in `commonLanguageSeeds`.
const Map<String, String> _appCodeToBcp47Map = <String, String>{
  // ── Lingue principali ──────────────────────────────────────────────────
  'it': 'it-IT', // Italiano
  'en-us': 'en-US', // English (US)
  'es': 'es-ES', // Spagnolo
  'fr': 'fr-FR', // Francese
  'de': 'de-DE', // Tedesco
  'pt': 'pt-BR', // Portoghese (Brasile, più diffuso come voce TTS)
  'nl': 'nl-NL', // Olandese
  'ru': 'ru-RU', // Russo
  'ua': 'uk-UA', // Ucraino  (codice app 'ua', BCP-47 'uk')
  'tr': 'tr-TR', // Turco
  'hi': 'hi-IN', // Hindi
  'ja': 'ja-JP', // Giapponese
  'ko': 'ko-KR', // Coreano
  'cn': 'zh-CN', // Cinese mandarino semplificato
  'ar': 'ar-SA', // Arabo (Arabia Saudita)
  'pl': 'pl-PL', // Polacco
};

/// Tutti i codici BCP-47 supportati dall'app, utile per filtrare le voci
/// disponibili sul dispositivo.
List<String> get allSupportedBcp47Codes =>
    _appCodeToBcp47Map.values.toList(growable: false);

/// Ritorna il codice app a partire da un codice BCP-47.
/// Utile per il percorso inverso (es. dalle voci di sistema al codice app).
String? bcp47ToAppCode(final String bcp47Code) {
  for (final entry in _appCodeToBcp47Map.entries) {
    if (entry.value.toLowerCase() == bcp47Code.toLowerCase()) {
      return entry.key;
    }
  }

  // Fallback: prova a matchare solo la parte lingua (es. 'it' da 'it-IT')
  final langPrefix = bcp47Code.split('-').first.toLowerCase();
  for (final entry in _appCodeToBcp47Map.entries) {
    if (entry.value.split('-').first.toLowerCase() == langPrefix) {
      return entry.key;
    }
  }

  return null;
}
