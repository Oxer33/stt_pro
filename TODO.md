# TODO List — STT Pro

## Completati ✅

- [x] **Trascrizione vocale offline** — Vosk engine con modelli scaricabili
- [x] **Traduzione on-device** — ML Kit con fallback pivot via inglese
- [x] **Fix race condition traduzioni** — Token preparazione + coda resiliente
- [x] **TTS nativo** — flutter_tts con play/stop, velocità, selezione voce
- [x] **Mappatura codici BCP-47** — `tts_language_mapper.dart`
- [x] **Persistenza preferenze TTS** — SharedPreferences
- [x] **UI card impostazioni TTS** — Toggle, slider velocità, dropdown voce
- [x] **Pulsante play/stop sotto traduzione** — Con cambio colore e icona
- [x] **Build APK release** — `build/app/outputs/flutter-apk/app-release.apk`
- [x] **Push GitHub** — https://github.com/Oxer33/stt_pro
- [x] **File ARCHITETTURA.md** — Documentazione architetturale completa

## Da fare 🔲

### Priorità alta
- [ ] **Tema scuro** — L'app attualmente usa solo tema chiaro
- [ ] **Icona app personalizzata** — Creare e configurare icona
- [ ] **Test unitari TTS** — Test per TtsController e tts_language_mapper

### Priorità media
- [ ] **Esportazione trascrizioni** — Salva come .txt o .pdf
- [ ] **Supporto landscape/tablet** — Layout responsive
- [ ] **Firma APK produzione** — Keystore personalizzato per Play Store
- [ ] **Git LFS** — Per file pesanti (libvosk.a > 50MB)

### Priorità bassa
- [ ] **Accessibilità WCAG** — ARIA labels, contrast ratio, keyboard nav
- [ ] **Rinomina APK** — Da `app-release.apk` a `stt_pro.apk`
- [ ] **App bundle (.aab)** — Per distribuzione Play Store
- [ ] **Aggiungere più lingue** — Espandere oltre le 16 attuali
