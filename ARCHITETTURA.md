# Architettura STT Pro

## Panoramica

STT Pro è un'app Flutter per trascrizione vocale in tempo reale (Speech-to-Text)
con traduzione on-device e sintesi vocale (Text-to-Speech) del testo tradotto.

**Stack tecnologico:**
- **Framework:** Flutter (Dart)
- **STT Engine:** Vosk (offline, via `vosk_flutter_service` locale)
- **Traduzione:** Google ML Kit On-Device Translation (`google_mlkit_translation`)
- **TTS Engine:** `flutter_tts` (motore nativo Android/iOS, zero modelli esterni)
- **Persistenza:** `shared_preferences`

---

## Struttura file

```
lib/
├── main.dart                          # Entry point + UI home
├── src/
│   ├── models/
│   │   └── language_pack.dart         # Modelli: LanguagePack, TranscriptSegment, seed lingue
│   ├── screens/
│   │   └── chat_mode_screen.dart      # Schermata Modalità Chat (bolle, TTS streaming)
│   └── services/
│       ├── live_transcriber_controller.dart  # Controller STT + traduzione
│       ├── tts_controller.dart              # Controller TTS (play/stop/streaming/voce)
│       ├── tts_language_mapper.dart          # Mappatura codici app → BCP-47 per TTS
│       └── vosk_result_parser.dart           # Parser risultati Vosk
packages/
└── vosk_flutter_service/              # Plugin Vosk locale (Android/iOS/desktop)
```

---

## Flusso dati

```
Microfono → Vosk (STT offline) → Segmenti testo
                                    ↓
                              ML Kit Translation (on-device)
                                    ↓
                              Testo tradotto → flutter_tts (lettura vocale)
```

### Pipeline STT
1. `LiveTranscriberController` gestisce il ciclo di vita del riconoscitore Vosk
2. I risultati parziali aggiornano `_partialText`, quelli finali creano `TranscriptSegment`
3. Ogni segmento viene accodato per traduzione via `_enqueueTranslation()`

### Pipeline Traduzione
1. Traduzione diretta source→target via `OnDeviceTranslator`
2. Se fallisce (es. it→es), fallback automatico via pivot inglese (it→en→es)
3. Token di preparazione (`_translationPreparationToken`) per evitare race condition
4. Coda resiliente con `.catchError()` per non bloccarsi su errori async

### Pipeline TTS
1. `TtsController` usa `flutter_tts` (motore nativo del dispositivo)
2. `tts_language_mapper.dart` converte codici app → BCP-47
3. La lingua TTS si sincronizza automaticamente con il target di traduzione
4. Supporto voci neurali (priorità), fallback a voci standard
5. Impostazioni persistenti: toggle, velocità (0.5x–2.0x), voce preferita/auto
6. **Modalità streaming**: coda auto-speak per segmenti tradotti in tempo reale
7. Deduplicazione segmenti già letti via `_spokenSegmentIds`

### Modalità Chat
1. `ChatModeScreen` mostra ogni segmento come bolla chat separata
2. Testo originale a destra, traduzione a sinistra (stile messaggeria)
3. Testo parziale (in corso) mostrato con indicatore di caricamento
4. Auto-scroll verso il basso ad ogni nuovo segmento
5. TTS streaming automatico: legge ogni traduzione appena pronta
6. Pulsante play su ogni singola bolla tradotta
7. Indicatore LIVE quando l'ascolto è attivo

---

## Lingue supportate (16)

| Codice app | BCP-47  | Lingua     |
|-----------|---------|------------|
| it        | it-IT   | Italiano   |
| en-us     | en-US   | English    |
| es        | es-ES   | Spagnolo   |
| fr        | fr-FR   | Francese   |
| de        | de-DE   | Tedesco    |
| pt        | pt-BR   | Portoghese |
| nl        | nl-NL   | Olandese   |
| ru        | ru-RU   | Russo      |
| ua        | uk-UA   | Ucraino    |
| tr        | tr-TR   | Turco      |
| hi        | hi-IN   | Hindi      |
| ja        | ja-JP   | Giapponese |
| ko        | ko-KR   | Coreano    |
| cn        | zh-CN   | Cinese     |
| ar        | ar-SA   | Arabo      |
| pl        | pl-PL   | Polacco    |

---

## Decisioni architetturali

- **Microservizi:** Separazione netta tra STT (Vosk), traduzione (ML Kit) e TTS (nativo)
- **Nessun backend:** Tutto on-device, nessuna chiamata a server esterni
- **Pivot translation:** Per coppie di lingue non supportate direttamente, traduzione
  a due passaggi via inglese come lingua ponte
- **Race condition mitigation:** Token incrementale per invalidare preparazioni obsolete
- **Persistenza leggera:** SharedPreferences per preferenze utente (lingua, target, TTS)

---

## Cosa è stato fatto

- [x] Trascrizione vocale offline con Vosk
- [x] Traduzione on-device con ML Kit (diretta + pivot via inglese)
- [x] Fix race condition traduzioni (token di preparazione)
- [x] TTS nativo con flutter_tts (play/stop, velocità, selezione voce)
- [x] Mappatura codici lingua app → BCP-47
- [x] Persistenza preferenze TTS
- [x] UI completa con card impostazioni TTS
- [x] Opzione "Automatica" nel dropdown voce TTS
- [x] **Modalità Chat** con bolle per ogni segmento e TTS streaming
- [x] Auto-speak in tempo reale dei segmenti tradotti
- [x] Build APK release funzionante
- [x] Push su GitHub

## Cosa manca / Miglioramenti futuri

- [ ] Tema scuro (attualmente solo tema chiaro)
- [ ] Icona app personalizzata
- [ ] Esportazione trascrizioni (testo, PDF)
- [ ] Supporto landscape / tablet
- [ ] Test unitari per TtsController e tts_language_mapper
- [ ] Git LFS per file grandi (libvosk.a)
- [ ] Firma APK con keystore di produzione
- [ ] Accessibilità completa (ARIA labels, keyboard navigation)
