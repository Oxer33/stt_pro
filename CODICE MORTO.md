# Codice Morto — STT Pro

Questo file traccia codice morto o inutilizzato trovato durante le revisioni.

## Revisione del 16 Marzo 2026

**Nessun codice morto rilevato.**

Tutti i file in `lib/` sono attivamente utilizzati:
- `main.dart` — entry point + UI
- `src/models/language_pack.dart` — modelli dati
- `src/services/live_transcriber_controller.dart` — controller STT + traduzione
- `src/services/vosk_result_parser.dart` — parser risultati Vosk
- `src/services/tts_controller.dart` — controller TTS (nuovo)
- `src/services/tts_language_mapper.dart` — mapper codici lingua (nuovo)
