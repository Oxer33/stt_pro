/// Controller per il Text-to-Speech (TTS) dell'app STT Pro.
///
/// Usa il pacchetto [flutter_tts] che sfrutta il motore TTS nativo del
/// dispositivo (Android / iOS). Zero download aggiuntivi, zero modelli esterni.
///
/// Questo file NON modifica la pipeline STT/traduzione.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_language_mapper.dart';

/// Stato corrente della riproduzione TTS.
enum TtsPlaybackState {
  /// Fermo, nessun audio in corso.
  stopped,

  /// In riproduzione.
  playing,

  /// In pausa (non usato su Android ma pronto per iOS).
  paused,
}

/// Controller TTS con supporto a:
/// - Play/stop del testo tradotto
/// - Toggle abilitazione
/// - Velocità regolabile (0.5x – 2.0x)
/// - Selezione voce tra quelle disponibili sul dispositivo
/// - Persistenza preferenze via SharedPreferences
class TtsController extends ChangeNotifier {
  TtsController();

  // ── Chiavi SharedPreferences ─────────────────────────────────────────
  static const String _enabledKey = 'tts_enabled';
  static const String _speechRateKey = 'tts_speech_rate';
  static const String _preferredVoiceKey = 'tts_preferred_voice';

  // ── Valori di default ────────────────────────────────────────────────
  static const double defaultSpeechRate = 0.5;
  static const double minSpeechRate = 0.25;
  static const double maxSpeechRate = 1.0;

  // ── Stato interno ────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  SharedPreferences? _prefs;

  bool _initialized = false;
  bool _disposed = false;
  bool _enabled = true;
  double _speechRate = defaultSpeechRate;
  String? _currentBcp47;
  TtsPlaybackState _playbackState = TtsPlaybackState.stopped;

  /// Lista di voci disponibili per la lingua target corrente.
  List<Map<String, String>> _availableVoices = <Map<String, String>>[];

  /// Voce selezionata dall'utente (nome).
  String? _preferredVoiceName;

  /// Messaggio di avviso (es. voce non disponibile).
  String? _warningMessage;

  // ── Getter pubblici ──────────────────────────────────────────────────
  bool get isEnabled => _enabled;
  double get speechRate => _speechRate;
  TtsPlaybackState get playbackState => _playbackState;
  bool get isSpeaking => _playbackState == TtsPlaybackState.playing;
  List<Map<String, String>> get availableVoices =>
      List.unmodifiable(_availableVoices);
  String? get preferredVoiceName => _preferredVoiceName;
  String? get warningMessage => _warningMessage;
  String? get currentBcp47 => _currentBcp47;

  // ── Inizializzazione ─────────────────────────────────────────────────

  /// Inizializza il controller TTS. Deve essere chiamato una sola volta
  /// all'avvio dell'app.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Carica preferenze salvate
    _prefs = await SharedPreferences.getInstance();
    _enabled = _prefs?.getBool(_enabledKey) ?? true;
    _speechRate = _prefs?.getDouble(_speechRateKey) ?? defaultSpeechRate;
    _preferredVoiceName = _prefs?.getString(_preferredVoiceKey);

    // Configura i callback del motore TTS
    _tts.setStartHandler(() {
      _playbackState = TtsPlaybackState.playing;
      _notify();
    });

    _tts.setCompletionHandler(() {
      _playbackState = TtsPlaybackState.stopped;
      _notify();
    });

    _tts.setCancelHandler(() {
      _playbackState = TtsPlaybackState.stopped;
      _notify();
    });

    _tts.setErrorHandler((final dynamic error) {
      debugPrint('[TTS] Errore: $error');
      _playbackState = TtsPlaybackState.stopped;
      _notify();
    });

    // Imposta velocità iniziale
    await _tts.setSpeechRate(_speechRate);

    _notify();
  }

  // ── Lingua target ────────────────────────────────────────────────────

  /// Aggiorna la lingua TTS in base al codice app della lingua target
  /// di traduzione. Carica dinamicamente le voci disponibili.
  Future<void> setLanguageFromAppCode(final String? appCode) async {
    final bcp47 = appCode == null ? null : appCodeToBcp47(appCode);

    if (bcp47 == _currentBcp47) return;
    _currentBcp47 = bcp47;
    _warningMessage = null;

    if (bcp47 == null) {
      _availableVoices = [];
      await stop();
      _notify();
      return;
    }

    // Imposta la lingua sul motore TTS
    final result = await _tts.setLanguage(bcp47);
    if (result != 1) {
      _warningMessage =
          'Voce non disponibile per questa lingua. '
          'Installa le voci da Impostazioni → Accessibilità → Text-to-Speech';
      _availableVoices = [];
      _notify();
      return;
    }

    // Carica voci disponibili per questa lingua
    await _loadVoicesForLanguage(bcp47);
    _notify();
  }

  /// Carica e filtra le voci disponibili sul dispositivo per il codice BCP-47.
  Future<void> _loadVoicesForLanguage(final String bcp47) async {
    try {
      final allVoices = await _tts.getVoices;
      if (allVoices == null) {
        _availableVoices = [];
        return;
      }

      final langPrefix = bcp47.split('-').first.toLowerCase();

      // Filtra le voci che corrispondono alla lingua target
      _availableVoices = (allVoices as List<dynamic>)
          .cast<Map<dynamic, dynamic>>()
          .map(
            (final v) => v.map(
              (final key, final value) =>
                  MapEntry(key.toString(), value.toString()),
            ),
          )
          .where((final voice) {
            final locale = (voice['locale'] ?? '').toLowerCase();
            return locale.startsWith(langPrefix);
          })
          .toList();

      // Ordina: voci neurali/di alta qualità prima
      _availableVoices.sort((final a, final b) {
        final aName = (a['name'] ?? '').toLowerCase();
        final bName = (b['name'] ?? '').toLowerCase();

        // Preferisci voci neurali
        final aIsNeural =
            aName.contains('neural') ||
            aName.contains('wavenet') ||
            aName.contains('enhanced');
        final bIsNeural =
            bName.contains('neural') ||
            bName.contains('wavenet') ||
            bName.contains('enhanced');

        if (aIsNeural && !bIsNeural) return -1;
        if (!aIsNeural && bIsNeural) return 1;
        return aName.compareTo(bName);
      });

      // Seleziona la voce preferita o la prima neurale disponibile
      await _applyPreferredVoice();
    } catch (error) {
      debugPrint('[TTS] Errore caricamento voci: $error');
      _availableVoices = [];
    }
  }

  /// Applica la voce preferita salvata, oppure seleziona la migliore
  /// disponibile (neurale se possibile).
  Future<void> _applyPreferredVoice() async {
    if (_availableVoices.isEmpty) return;

    // Cerca la voce preferita salvata
    Map<String, String>? targetVoice;

    if (_preferredVoiceName != null) {
      targetVoice = _availableVoices.cast<Map<String, String>?>().firstWhere(
        (final v) => v?['name'] == _preferredVoiceName,
        orElse: () => null,
      );
    }

    // Fallback: prima voce (già ordinata con neurali prima)
    targetVoice ??= _availableVoices.first;

    await _tts.setVoice({
      'name': targetVoice['name'] ?? '',
      'locale': targetVoice['locale'] ?? '',
    });
  }

  // ── Controlli riproduzione ───────────────────────────────────────────

  /// Legge ad alta voce il testo fornito. Se già in riproduzione, ferma prima.
  Future<void> speak(final String text) async {
    if (!_enabled || text.trim().isEmpty) return;

    if (isSpeaking) {
      await stop();
    }

    _warningMessage = null;

    // Verifica che la lingua sia impostata
    if (_currentBcp47 == null) {
      _warningMessage = 'Nessuna lingua target impostata per il TTS.';
      _notify();
      return;
    }

    // Verifica disponibilità voce
    final isAvailable = await _tts.isLanguageAvailable(_currentBcp47!);
    if (isAvailable != true) {
      _warningMessage =
          'Voce non disponibile per questa lingua. '
          'Installa le voci da Impostazioni → Accessibilità → Text-to-Speech';
      _notify();
      return;
    }

    _playbackState = TtsPlaybackState.playing;
    _notify();

    await _tts.speak(text);
  }

  /// Ferma la riproduzione TTS in corso.
  Future<void> stop() async {
    await _tts.stop();
    _playbackState = TtsPlaybackState.stopped;
    _notify();
  }

  // ── Impostazioni ─────────────────────────────────────────────────────

  /// Abilita o disabilita il TTS. Se disabilitato, ferma la riproduzione.
  Future<void> setEnabled(final bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    await _prefs?.setBool(_enabledKey, value);

    if (!_enabled) {
      await stop();
    }

    _notify();
  }

  /// Imposta la velocità del parlato (range: 0.25 – 1.0 per flutter_tts,
  /// esposto all'utente come 0.5x – 2.0x).
  Future<void> setSpeechRate(final double rate) async {
    _speechRate = rate.clamp(minSpeechRate, maxSpeechRate);
    await _prefs?.setDouble(_speechRateKey, _speechRate);
    await _tts.setSpeechRate(_speechRate);
    _notify();
  }

  /// Seleziona una voce specifica dal dispositivo.
  Future<void> setVoice(final Map<String, String> voice) async {
    _preferredVoiceName = voice['name'];
    await _prefs?.setString(_preferredVoiceKey, _preferredVoiceName ?? '');

    await _tts.setVoice({
      'name': voice['name'] ?? '',
      'locale': voice['locale'] ?? '',
    });

    _notify();
  }

  // ── Utilità ──────────────────────────────────────────────────────────

  /// Converte il valore interno speechRate (0.25–1.0) nel moltiplicatore
  /// visibile all'utente (0.5x–2.0x).
  double get displayRate => _speechRate * 2.0;

  /// Converte il moltiplicatore dell'utente (0.5x–2.0x) nel valore interno.
  static double displayRateToInternal(final double displayValue) =>
      displayValue / 2.0;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _tts.stop();
    super.dispose();
  }
}
