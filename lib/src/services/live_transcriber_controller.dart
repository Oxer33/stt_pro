import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vosk_flutter_service/vosk_flutter.dart';

import '../models/language_pack.dart';
import 'vosk_result_parser.dart';

enum _BusyAction { downloading, preparing, deleting }

class LiveTranscriberController extends ChangeNotifier {
  LiveTranscriberController({
    final VoskFlutterPlugin? vosk,
    final ModelLoader? modelLoader,
  }) : _vosk = vosk ?? VoskFlutterPlugin.instance(),
       _modelLoader = modelLoader ?? ModelLoader();

  static const int sampleRate = 16000;
  static const String _selectedLanguageKey = 'selected_language_code';
  static const String _translationTargetKey = 'translation_target_code';
  static const String _defaultLanguageCode = 'it';

  final VoskFlutterPlugin _vosk;
  final ModelLoader _modelLoader;
  final OnDeviceTranslatorModelManager _translationModelManager =
      OnDeviceTranslatorModelManager();

  SharedPreferences? _prefs;
  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;
  OnDeviceTranslator? _translator;
  TranslateLanguage? _translatorSourceLanguage;
  TranslateLanguage? _translatorTargetLanguage;
  StreamSubscription<String>? _resultSubscription;
  StreamSubscription<String>? _partialSubscription;

  List<LanguagePack> _packs = commonLanguageSeeds
      .map(LanguagePack.fromSeed)
      .toList(growable: false);
  final List<TranscriptSegment> _segments = <TranscriptSegment>[];
  final Map<String, String> _installedPaths = <String, String>{};

  bool _isInitializing = true;
  bool _isListening = false;
  bool _catalogSynced = false;
  bool _disposed = false;
  bool _isPreparingTranslation = false;
  String? _selectedCode;
  String? _activeCode;
  String? _translationTargetCode;
  String? _busyCode;
  _BusyAction? _busyAction;
  String _partialText = '';
  String? _statusMessage;
  String? _errorMessage;
  String? _translationStatusMessage;
  String? _translationErrorMessage;
  Future<void> _translationChain = Future<void>.value();
  int _translationGeneration = 0;
  int _translationPreparationToken = 0;

  bool get isInitializing => _isInitializing;
  bool get isListening => _isListening;
  bool get catalogSynced => _catalogSynced;
  bool get isPreparingTranslation => _isPreparingTranslation;
  bool get isMobileSupported => Platform.isAndroid || Platform.isIOS;
  bool get hasTranscript => _segments.isNotEmpty || _partialText.isNotEmpty;
  bool get isTranslationEnabled => _translationTargetCode != null;
  String get partialText => _partialText;
  String? get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  String? get translationStatusMessage => _translationStatusMessage;
  String? get translationErrorMessage => _translationErrorMessage;
  String? get translationTargetCode => _translationTargetCode;
  List<LanguagePack> get packs => List.unmodifiable(_packs);
  List<TranscriptSegment> get segments => List.unmodifiable(_segments);
  List<LanguagePack> get translationTargetPacks => List.unmodifiable(
    _packs.where(
      (final pack) =>
          _translateLanguageForCode(pack.code) != null &&
          pack.code != _selectedCode,
    ),
  );

  LanguagePack? get selectedPack => _packFor(_selectedCode);
  LanguagePack? get activePack => _packFor(_activeCode);
  LanguagePack? get translationTargetPack => _packFor(_translationTargetCode);

  Future<void> initialize() async {
    if (!_isInitializing) {
      return;
    }

    _statusMessage = 'Avvio in corso...';
    _notify();

    try {
      _prefs = await SharedPreferences.getInstance();
      _selectedCode = _prefs?.getString(_selectedLanguageKey);
      _translationTargetCode = _prefs?.getString(_translationTargetKey);

      await _loadCatalog();
      await _refreshInstalledPaths();

      _selectedCode = _resolveInitialLanguageCode();
      _translationTargetCode = _resolveInitialTranslationTargetCode(
        _selectedCode!,
      );

      await _prefs?.setString(_selectedLanguageKey, _selectedCode!);
      await _persistTranslationTargetCode();

      if (_installedPaths.containsKey(_selectedCode)) {
        await _prepareLanguage(_packFor(_selectedCode)!);
      } else {
        _statusMessage = 'Scarica una lingua per iniziare.';
      }

      if (isTranslationEnabled) {
        unawaited(_prepareTranslationIfNeeded());
      }
    } catch (error) {
      _errorMessage = 'Impossibile inizializzare STT Pro: $error';
    } finally {
      _isInitializing = false;
      _notify();
    }
  }

  LanguagePackInstallState installStateFor(final LanguagePack pack) {
    if (_busyCode == pack.code) {
      switch (_busyAction) {
        case _BusyAction.downloading:
          return LanguagePackInstallState.downloading;
        case _BusyAction.preparing:
          return LanguagePackInstallState.preparing;
        case _BusyAction.deleting:
          return LanguagePackInstallState.deleting;
        case null:
          break;
      }
    }

    if (_activeCode == pack.code && _speechService != null) {
      return LanguagePackInstallState.active;
    }

    if (_installedPaths.containsKey(pack.code)) {
      return LanguagePackInstallState.installed;
    }

    return LanguagePackInstallState.available;
  }

  bool isSelected(final LanguagePack pack) => _selectedCode == pack.code;

  Future<void> refreshCatalog() async {
    _statusMessage = 'Aggiorno catalogo...';
    _errorMessage = null;
    _notify();

    await _loadCatalog();
    await _refreshInstalledPaths();

    _statusMessage = _catalogSynced
        ? 'Catalogo aggiornato.'
        : 'Catalogo locale.';
    _notify();
  }

  Future<void> selectLanguage(final LanguagePack pack) async {
    _selectedCode = pack.code;
    _errorMessage = null;
    await _prefs?.setString(_selectedLanguageKey, pack.code);

    if (_translationTargetCode == pack.code) {
      _translationTargetCode = _defaultTranslationTargetForSource(pack.code);
      await _persistTranslationTargetCode();
    }

    if (!_installedPaths.containsKey(pack.code)) {
      _statusMessage = 'Scarica ${pack.label} per usarla.';
      _notify();
      unawaited(_prepareTranslationIfNeeded(force: true));
      return;
    }

    await _prepareLanguage(pack);
    unawaited(_prepareTranslationIfNeeded(force: true));
  }

  Future<void> setTranslationTargetCode(final String? packCode) async {
    _translationTargetCode = packCode == _selectedCode ? null : packCode;
    _translationErrorMessage = null;
    await _persistTranslationTargetCode();

    if (!isTranslationEnabled) {
      _translationGeneration++;
      _translationChain = Future<void>.value();
      await _disposeTranslator();
      _translationStatusMessage = null;
      _clearTranslations();
      _notify();
      return;
    }

    _translationGeneration++;
    _translationChain = Future<void>.value();
    await _prepareTranslationIfNeeded(
      force: true,
      retranslateExistingSegments: true,
    );
  }

  Future<void> downloadLanguage(final LanguagePack pack) async {
    if (_busyAction != null) {
      return;
    }

    var activateAfterDownload = false;
    _busyCode = pack.code;
    _busyAction = _BusyAction.downloading;
    _errorMessage = null;
    _statusMessage = 'Scarico ${pack.label}...';
    _notify();

    try {
      await _modelLoader.loadFromNetwork(pack.resolvedUrl);
      await _refreshInstalledPaths();
      _statusMessage = '${pack.label} pronta.';
      activateAfterDownload = _selectedCode == pack.code || activePack == null;
    } catch (error) {
      _errorMessage = 'Download fallito per ${pack.label}: $error';
    } finally {
      _busyCode = null;
      _busyAction = null;
      _notify();
    }

    if (activateAfterDownload) {
      await selectLanguage(pack);
    }
  }

  Future<void> deleteLanguage(final LanguagePack pack) async {
    if (_busyAction != null) {
      return;
    }

    _busyCode = pack.code;
    _busyAction = _BusyAction.deleting;
    _errorMessage = null;
    _statusMessage = 'Rimuovo ${pack.label}...';
    _notify();

    try {
      if (_activeCode == pack.code) {
        await _teardownRecognizer();
      }

      for (final modelName in pack.knownModelNames) {
        final modelPath = await _modelLoader.modelPath(modelName);
        final directory = Directory(modelPath);
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      }

      await _refreshInstalledPaths();
      _statusMessage = '${pack.label} rimossa.';
    } catch (error) {
      _errorMessage = 'Non sono riuscito a eliminare ${pack.label}: $error';
    } finally {
      _busyCode = null;
      _busyAction = null;
      _notify();
    }
  }

  Future<void> toggleListening() async {
    if (!isMobileSupported) {
      _errorMessage = 'Questa build live e` pensata per Android e iOS.';
      _notify();
      return;
    }

    if (_isListening) {
      await stopListening();
      return;
    }

    final pack = selectedPack;
    if (pack == null) {
      _errorMessage = 'Seleziona una lingua.';
      _notify();
      return;
    }

    if (!_installedPaths.containsKey(pack.code)) {
      _errorMessage = 'Scarica prima ${pack.label}.';
      _notify();
      return;
    }

    if (_activeCode != pack.code || _speechService == null) {
      await _prepareLanguage(pack);
    }

    final service = _speechService;
    if (service == null) {
      _errorMessage = 'Il servizio audio non e` pronto.';
      _notify();
      return;
    }

    try {
      await service.start(
        onRecognitionError: (final Object? error) {
          _errorMessage = 'Errore nel flusso live: $error';
          _isListening = false;
          _partialText = '';
          _notify();
        },
      );
      _isListening = true;
      _statusMessage = 'Ascolto attivo.';
      _notify();
    } catch (error) {
      _errorMessage = 'Avvio microfono fallito: $error';
      _notify();
    }
  }

  Future<void> stopListening() async {
    final service = _speechService;
    if (service == null) {
      _isListening = false;
      _partialText = '';
      _notify();
      return;
    }

    try {
      await service.stop();
      _statusMessage = 'Ascolto fermato.';
    } catch (error) {
      _errorMessage = 'Stop microfono fallito: $error';
    } finally {
      _isListening = false;
      _partialText = '';
      _notify();
    }
  }

  Future<void> clearTranscript() async {
    _translationGeneration++;
    _translationChain = Future<void>.value();
    _segments.clear();
    _partialText = '';
    _errorMessage = null;
    _translationErrorMessage = null;

    try {
      await _speechService?.reset();
      await _recognizer?.reset();
    } catch (_) {
      // Best effort.
    }

    _statusMessage = 'Testo pulito.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _teardownRecognizer();
    await _disposeTranslator();
  }

  Future<void> _loadCatalog() async {
    try {
      final remoteModels = await _modelLoader.loadModelsList();
      final nextPacks = <LanguagePack>[];

      for (final seed in commonLanguageSeeds) {
        final candidates = remoteModels.where((final model) {
          if (model.obsolete) {
            return false;
          }

          return seed.code.toLowerCase() == model.lang.toLowerCase() ||
              seed.aliases.any(
                (final alias) =>
                    alias.toLowerCase() == model.lang.toLowerCase(),
              );
        }).toList();

        nextPacks.add(
          LanguagePack.fromSeed(
            seed,
            remoteModel: _pickPreferredModel(candidates),
          ),
        );
      }

      _packs = nextPacks;
      _catalogSynced = true;
    } catch (_) {
      _packs = commonLanguageSeeds
          .map(LanguagePack.fromSeed)
          .toList(growable: false);
      _catalogSynced = false;
    }
  }

  LanguageModelDescription? _pickPreferredModel(
    final List<LanguageModelDescription> models,
  ) {
    if (models.isEmpty) {
      return null;
    }

    models.sort((final left, final right) {
      final typeComparison = _typeRank(
        left.type,
      ).compareTo(_typeRank(right.type));
      if (typeComparison != 0) {
        return typeComparison;
      }

      final versionComparison = _compareVersions(right.version, left.version);
      if (versionComparison != 0) {
        return versionComparison;
      }

      return left.name.compareTo(right.name);
    });

    return models.first;
  }

  int _typeRank(final String type) {
    switch (type) {
      case 'small':
        return 0;
      case 'big-lgraph':
        return 1;
      case 'big':
        return 2;
      default:
        return 3;
    }
  }

  int _compareVersions(final String left, final String right) {
    final leftParts = RegExp(r'\d+')
        .allMatches(left)
        .map((final match) => int.parse(match.group(0)!))
        .toList();
    final rightParts = RegExp(r'\d+')
        .allMatches(right)
        .map((final match) => int.parse(match.group(0)!))
        .toList();

    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return left.compareTo(right);
  }

  Future<void> _refreshInstalledPaths() async {
    final installedEntries = await Future.wait(
      _packs.map((final pack) async {
        for (final modelName in pack.knownModelNames) {
          final modelPath = await _modelLoader.modelPath(modelName);
          if (Directory(modelPath).existsSync()) {
            return MapEntry(pack.code, modelPath);
          }
        }

        return null;
      }),
    );

    _installedPaths
      ..clear()
      ..addEntries(installedEntries.whereType<MapEntry<String, String>>());
  }

  String _resolveInitialLanguageCode() {
    if (_selectedCode != null &&
        _packs.any((final pack) => pack.code == _selectedCode)) {
      return _selectedCode!;
    }

    if (_packs.any((final pack) => pack.code == _defaultLanguageCode)) {
      return _defaultLanguageCode;
    }

    return _packs.first.code;
  }

  String? _resolveInitialTranslationTargetCode(final String sourceCode) {
    if (_translationTargetCode != null &&
        _translationTargetCode != sourceCode &&
        _translateLanguageForCode(_translationTargetCode!) != null) {
      return _translationTargetCode;
    }

    return _defaultTranslationTargetForSource(sourceCode);
  }

  String? _defaultTranslationTargetForSource(final String sourceCode) {
    final fallback = sourceCode == 'en-us' ? 'it' : 'en-us';
    return fallback == sourceCode ? null : fallback;
  }

  Future<void> _persistTranslationTargetCode() async {
    if (_translationTargetCode == null) {
      await _prefs?.remove(_translationTargetKey);
      return;
    }

    await _prefs?.setString(_translationTargetKey, _translationTargetCode!);
  }

  Future<void> _prepareLanguage(final LanguagePack pack) async {
    if (_busyAction != null && _busyAction != _BusyAction.preparing) {
      return;
    }

    final wasListening = _isListening;
    _busyCode = pack.code;
    _busyAction = _BusyAction.preparing;
    _errorMessage = null;
    _statusMessage = 'Preparo ${pack.label}...';
    _notify();

    try {
      if (wasListening) {
        await stopListening();
      }

      await _teardownRecognizer();

      final modelPath = await _resolveInstalledModelPath(pack);
      if (modelPath == null) {
        throw StateError('Il modello ${pack.label} non risulta installato.');
      }

      _model = await _vosk.createModel(modelPath);
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: sampleRate,
      );
      await _recognizer!.setWords(words: true);
      _speechService = await _vosk.initSpeechService(_recognizer!);

      await _resultSubscription?.cancel();
      await _partialSubscription?.cancel();

      _resultSubscription = _speechService!.onResult().listen(
        _handleFinalResult,
      );
      _partialSubscription = _speechService!.onPartial().listen(
        _handlePartialResult,
      );

      _activeCode = pack.code;
      _statusMessage = '${pack.label} pronta.';

      if (wasListening) {
        await toggleListening();
      }
    } on MicrophoneAccessDeniedException {
      _errorMessage = 'Serve il permesso microfono.';
    } catch (error) {
      _errorMessage = 'Non sono riuscito a preparare ${pack.label}: $error';
    } finally {
      _busyCode = null;
      _busyAction = null;
      _notify();
    }
  }

  Future<void> _prepareTranslationIfNeeded({
    final bool force = false,
    final bool retranslateExistingSegments = false,
  }) async {
    final sourceCode = _selectedCode;
    final targetCode = _translationTargetCode;
    final sourceLanguage = sourceCode == null
        ? null
        : _translateLanguageForCode(sourceCode);
    final targetLanguage = targetCode == null
        ? null
        : _translateLanguageForCode(targetCode);
    final requestToken = ++_translationPreparationToken;

    if (sourceLanguage == null ||
        targetLanguage == null ||
        sourceLanguage == targetLanguage) {
      if (!_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        return;
      }

      _translationStatusMessage = null;
      _translationErrorMessage = null;
      await _disposeTranslator();
      if (retranslateExistingSegments) {
        _clearTranslations();
      }
      _notify();
      return;
    }

    if (!force &&
        _translator != null &&
        _translatorSourceLanguage == sourceLanguage &&
        _translatorTargetLanguage == targetLanguage) {
      return;
    }

    _isPreparingTranslation = true;
    _translationErrorMessage = null;
    _translationStatusMessage =
        'Preparo traduzione ${_packFor(targetCode)?.label ?? targetCode}...';
    _notify();

    try {
      await _disposeTranslator();

      if (!_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        return;
      }

      await _ensureTranslationModel(sourceLanguage);
      if (!_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        return;
      }

      await _ensureTranslationModel(targetLanguage);
      if (!_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        return;
      }

      final translator = OnDeviceTranslator(
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
      if (!_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        await translator.close();
        return;
      }

      _translator = translator;
      _translatorSourceLanguage = sourceLanguage;
      _translatorTargetLanguage = targetLanguage;
      _translationStatusMessage =
          '${_packFor(targetCode)?.label ?? targetCode} pronta.';

      if (retranslateExistingSegments && _segments.isNotEmpty) {
        _translationGeneration++;
        _translationChain = Future<void>.value();
        _markAllSegmentsForTranslation();

        for (final segment in List<TranscriptSegment>.from(_segments)) {
          _enqueueTranslation(segment.id, segment.text);
        }
      }
    } catch (error) {
      if (_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        _translationErrorMessage = 'Traduzione non disponibile: $error';
        if (retranslateExistingSegments) {
          _clearTranslations();
        }
      }
    } finally {
      if (_isTranslationPreparationCurrent(
        token: requestToken,
        sourceCode: sourceCode,
        targetCode: targetCode,
      )) {
        _isPreparingTranslation = false;
        _notify();
      }
    }
  }

  bool _isTranslationPreparationCurrent({
    required final int token,
    required final String? sourceCode,
    required final String? targetCode,
  }) =>
      token == _translationPreparationToken &&
      sourceCode == _selectedCode &&
      targetCode == _translationTargetCode;

  Future<void> _ensureTranslationModel(final TranslateLanguage language) async {
    final bcpCode = language.bcpCode;
    final isDownloaded = await _translationModelManager.isModelDownloaded(
      bcpCode,
    );
    if (isDownloaded) {
      return;
    }

    final downloaded = await _translationModelManager.downloadModel(bcpCode);
    if (!downloaded &&
        !await _translationModelManager.isModelDownloaded(bcpCode)) {
      throw StateError('Download modello traduzione $bcpCode fallito.');
    }
  }

  Future<OnDeviceTranslator?> _ensureTranslatorReady() async {
    if (!isTranslationEnabled) {
      return null;
    }

    final sourceCode = _selectedCode;
    final targetCode = _translationTargetCode;
    final sourceLanguage = sourceCode == null
        ? null
        : _translateLanguageForCode(sourceCode);
    final targetLanguage = targetCode == null
        ? null
        : _translateLanguageForCode(targetCode);

    if (sourceLanguage == null ||
        targetLanguage == null ||
        sourceLanguage == targetLanguage) {
      return null;
    }

    if (_translator != null &&
        _translatorSourceLanguage == sourceLanguage &&
        _translatorTargetLanguage == targetLanguage) {
      return _translator;
    }

    await _prepareTranslationIfNeeded(force: true);
    if (_translator != null &&
        _translatorSourceLanguage == sourceLanguage &&
        _translatorTargetLanguage == targetLanguage) {
      return _translator;
    }

    return null;
  }

  Future<void> _disposeTranslator() async {
    if (_translator != null) {
      await _translator!.close();
    }

    _translator = null;
    _translatorSourceLanguage = null;
    _translatorTargetLanguage = null;
  }

  Future<String?> _resolveInstalledModelPath(final LanguagePack pack) async {
    if (_installedPaths.containsKey(pack.code)) {
      return _installedPaths[pack.code];
    }

    for (final modelName in pack.knownModelNames) {
      final candidatePath = await _modelLoader.modelPath(modelName);
      if (Directory(candidatePath).existsSync()) {
        _installedPaths[pack.code] = candidatePath;
        return candidatePath;
      }
    }

    return null;
  }

  void _handlePartialResult(final String payload) {
    final parsed = parseVoskPayload(payload, isFinal: false);
    _partialText = isMeaningfulPreview(parsed.text) ? parsed.text : '';
    _notify();
  }

  void _handleFinalResult(final String payload) {
    final parsed = parseVoskPayload(payload, isFinal: true);
    _partialText = '';

    if (!shouldCommitResult(parsed)) {
      _notify();
      return;
    }

    final lastText = _segments.isNotEmpty ? _segments.last.text : null;
    if (lastText?.toLowerCase() == parsed.text.toLowerCase()) {
      _notify();
      return;
    }

    final shouldTranslate = isTranslationEnabled;
    final segment = TranscriptSegment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: parsed.text,
      capturedAt: DateTime.now(),
      averageConfidence: parsed.averageConfidence,
      isTranslating: shouldTranslate,
    );

    _segments.add(segment);
    _notify();

    if (shouldTranslate) {
      _enqueueTranslation(segment.id, segment.text);
    }
  }

  void _enqueueTranslation(final String segmentId, final String text) {
    final generation = _translationGeneration;
    final sourceLanguage = _selectedCode == null
        ? null
        : _translateLanguageForCode(_selectedCode!);
    final targetLanguage = _translationTargetCode == null
        ? null
        : _translateLanguageForCode(_translationTargetCode!);
    _translationChain = _translationChain.catchError((final Object _) {}).then((
      _,
    ) async {
      try {
        final translator = await _ensureTranslatorReady();
        if (translator == null || generation != _translationGeneration) {
          _updateSegmentTranslation(
            segmentId: segmentId,
            translation: null,
            isTranslating: false,
          );
          return;
        }

        final translatedText = await translator.translateText(text);
        if (generation != _translationGeneration) {
          return;
        }

        _updateSegmentTranslation(
          segmentId: segmentId,
          translation: translatedText,
          isTranslating: false,
        );
      } catch (error) {
        if (generation != _translationGeneration) {
          return;
        }

        final translatedViaPivot = await _translateViaPivot(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );

        if (generation != _translationGeneration) {
          return;
        }

        if (translatedViaPivot != null) {
          _updateSegmentTranslation(
            segmentId: segmentId,
            translation: translatedViaPivot,
            isTranslating: false,
          );
          return;
        }

        _translationErrorMessage = 'Traduzione fallita: $error';
        _updateSegmentTranslation(
          segmentId: segmentId,
          translation: null,
          isTranslating: false,
        );
        _notify();
      }
    });
  }

  Future<String?> _translateViaPivot({
    required final String text,
    required final TranslateLanguage? sourceLanguage,
    required final TranslateLanguage? targetLanguage,
  }) async {
    if (sourceLanguage == null || targetLanguage == null) {
      return null;
    }

    if (sourceLanguage == targetLanguage) {
      return text;
    }

    final pivot = TranslateLanguage.english;
    if (sourceLanguage == pivot || targetLanguage == pivot) {
      return null;
    }

    try {
      await _ensureTranslationModel(sourceLanguage);
      await _ensureTranslationModel(targetLanguage);
      await _ensureTranslationModel(pivot);

      final toPivot = OnDeviceTranslator(
        sourceLanguage: sourceLanguage,
        targetLanguage: pivot,
      );
      try {
        final pivotText = await toPivot.translateText(text);
        final toTarget = OnDeviceTranslator(
          sourceLanguage: pivot,
          targetLanguage: targetLanguage,
        );
        try {
          return await toTarget.translateText(pivotText);
        } finally {
          await toTarget.close();
        }
      } finally {
        await toPivot.close();
      }
    } catch (_) {
      return null;
    }
  }

  void _updateSegmentTranslation({
    required final String segmentId,
    required final String? translation,
    required final bool isTranslating,
  }) {
    final index = _segments.indexWhere(
      (final segment) => segment.id == segmentId,
    );
    if (index == -1) {
      return;
    }

    _segments[index] = _segments[index].copyWith(
      translation: translation,
      isTranslating: isTranslating,
    );
    _notify();
  }

  void _markAllSegmentsForTranslation() {
    for (var index = 0; index < _segments.length; index++) {
      _segments[index] = _segments[index].copyWith(
        translation: null,
        isTranslating: true,
      );
    }
    _notify();
  }

  void _clearTranslations() {
    for (var index = 0; index < _segments.length; index++) {
      _segments[index] = _segments[index].copyWith(
        translation: null,
        isTranslating: false,
      );
    }
  }

  Future<void> _teardownRecognizer() async {
    _isListening = false;
    _partialText = '';

    await _resultSubscription?.cancel();
    await _partialSubscription?.cancel();
    _resultSubscription = null;
    _partialSubscription = null;

    if (_speechService != null) {
      try {
        await _speechService!.dispose();
      } catch (_) {
        // Best effort.
      }
    }

    if (_recognizer != null) {
      try {
        await _recognizer!.dispose();
      } catch (_) {
        // Ignore dispose failures while reconfiguring.
      }
    }

    _model?.dispose();

    _speechService = null;
    _recognizer = null;
    _model = null;
    _activeCode = null;
  }

  LanguagePack? _packFor(final String? code) {
    if (code == null) {
      return null;
    }

    for (final pack in _packs) {
      if (pack.code == code) {
        return pack;
      }
    }

    return null;
  }

  TranslateLanguage? _translateLanguageForCode(final String code) {
    switch (code) {
      case 'it':
        return TranslateLanguage.italian;
      case 'en-us':
        return TranslateLanguage.english;
      case 'es':
        return TranslateLanguage.spanish;
      case 'fr':
        return TranslateLanguage.french;
      case 'de':
        return TranslateLanguage.german;
      case 'pt':
        return TranslateLanguage.portuguese;
      case 'nl':
        return TranslateLanguage.dutch;
      case 'ru':
        return TranslateLanguage.russian;
      case 'ua':
        return TranslateLanguage.ukrainian;
      case 'tr':
        return TranslateLanguage.turkish;
      case 'hi':
        return TranslateLanguage.hindi;
      case 'ja':
        return TranslateLanguage.japanese;
      case 'ko':
        return TranslateLanguage.korean;
      case 'cn':
        return TranslateLanguage.chinese;
      case 'ar':
        return TranslateLanguage.arabic;
      case 'pl':
        return TranslateLanguage.polish;
      default:
        return null;
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
