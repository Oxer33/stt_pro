# STT Pro

App Flutter per trascrizione vocale live offline con Vosk e traduzione on-device con ML Kit.

## Cosa fa

- ascolto continuo dal microfono
- risultati live parziali mentre la persona sta parlando
- commit del transcript solo sui risultati finali utili
- traduzione asincrona dei segmenti finali senza bloccare il live
- filtro di output vuoti, pause e risultati troppo deboli
- catalogo iniziale con le lingue piu comuni
- download locale dei modelli lingua e rimozione dal dispositivo

## Avvio rapido

```bash
flutter pub get
flutter run
```

## Android

La build Android e stata verificata con:

```bash
flutter build apk --debug
```

APK generato in:

`build/app/outputs/flutter-apk/app-debug.apk`

## iOS

Il progetto include il package Vosk locale e i binari iOS sono gia stati scaricati in `packages/vosk_flutter_service/ios/Frameworks`.

Per buildare davvero su iPhone/macOS servono comunque:

- Xcode completo
- CocoaPods installato
- toolchain iOS configurata correttamente

Su questa macchina la build iOS non e stata completata per mancanza della toolchain Apple.

## Note tecniche

- lingua di default: Italiano
- lingua target di default: Inglese
- sample rate riconoscimento live: `16000`
- la traduzione usa modelli ML Kit scaricati on demand sul dispositivo
- i modelli vengono salvati nei documenti dell'app e restano offline dopo il download
