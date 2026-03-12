import 'package:path/path.dart' as path;
import 'package:vosk_flutter_service/vosk_flutter.dart';

enum LanguagePackInstallState {
  available,
  downloading,
  preparing,
  deleting,
  installed,
  active,
}

class LanguagePackSeed {
  const LanguagePackSeed({
    required this.code,
    required this.label,
    required this.nativeLabel,
    required this.fallbackUrl,
    required this.fallbackSize,
    this.aliases = const [],
    this.recommended = false,
  });

  final String code;
  final String label;
  final String nativeLabel;
  final String fallbackUrl;
  final String fallbackSize;
  final List<String> aliases;
  final bool recommended;
}

class LanguagePack {
  const LanguagePack({
    required this.code,
    required this.label,
    required this.nativeLabel,
    required this.fallbackUrl,
    required this.fallbackSize,
    required this.aliases,
    required this.recommended,
    this.remoteModel,
  });

  factory LanguagePack.fromSeed(
    final LanguagePackSeed seed, {
    final LanguageModelDescription? remoteModel,
  }) => LanguagePack(
    code: seed.code,
    label: seed.label,
    nativeLabel: seed.nativeLabel,
    fallbackUrl: seed.fallbackUrl,
    fallbackSize: seed.fallbackSize,
    aliases: seed.aliases,
    recommended: seed.recommended,
    remoteModel: remoteModel,
  );

  final String code;
  final String label;
  final String nativeLabel;
  final String fallbackUrl;
  final String fallbackSize;
  final List<String> aliases;
  final bool recommended;
  final LanguageModelDescription? remoteModel;

  String get resolvedUrl => remoteModel?.url ?? fallbackUrl;
  String get resolvedSize => remoteModel?.sizeText ?? fallbackSize;
  String get resolvedType => remoteModel?.type ?? 'small';
  String get currentModelName => path.basenameWithoutExtension(resolvedUrl);
  String get fallbackModelName => path.basenameWithoutExtension(fallbackUrl);

  List<String> get knownModelNames =>
      {currentModelName, fallbackModelName}.toList(growable: false);

  bool matchesLang(final String lang) => {
    code.toLowerCase(),
    ...aliases.map((final value) => value.toLowerCase()),
  }.contains(lang.toLowerCase());

  LanguagePack copyWith({final LanguageModelDescription? remoteModel}) =>
      LanguagePack(
        code: code,
        label: label,
        nativeLabel: nativeLabel,
        fallbackUrl: fallbackUrl,
        fallbackSize: fallbackSize,
        aliases: aliases,
        recommended: recommended,
        remoteModel: remoteModel,
      );
}

class TranscriptSegment {
  static const Object _translationSentinel = Object();

  const TranscriptSegment({
    required this.id,
    required this.text,
    required this.capturedAt,
    this.averageConfidence,
    this.translation,
    this.isTranslating = false,
  });

  final String id;
  final String text;
  final DateTime capturedAt;
  final double? averageConfidence;
  final String? translation;
  final bool isTranslating;

  TranscriptSegment copyWith({
    final Object? translation = _translationSentinel,
    final bool? isTranslating,
  }) => TranscriptSegment(
    id: id,
    text: text,
    capturedAt: capturedAt,
    averageConfidence: averageConfidence,
    translation: identical(translation, _translationSentinel)
        ? this.translation
        : translation as String?,
    isTranslating: isTranslating ?? this.isTranslating,
  );
}

const commonLanguageSeeds = <LanguagePackSeed>[
  LanguagePackSeed(
    code: 'it',
    label: 'Italiano',
    nativeLabel: 'Italiano',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip',
    fallbackSize: '47.4 MiB',
    recommended: true,
  ),
  LanguagePackSeed(
    code: 'en-us',
    label: 'English',
    nativeLabel: 'English (US)',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    fallbackSize: '39.3 MiB',
    aliases: ['en'],
    recommended: true,
  ),
  LanguagePackSeed(
    code: 'es',
    label: 'Spagnolo',
    nativeLabel: 'Español',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip',
    fallbackSize: '38.0 MiB',
    recommended: true,
  ),
  LanguagePackSeed(
    code: 'fr',
    label: 'Francese',
    nativeLabel: 'Français',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip',
    fallbackSize: '40.3 MiB',
    recommended: true,
  ),
  LanguagePackSeed(
    code: 'de',
    label: 'Tedesco',
    nativeLabel: 'Deutsch',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip',
    fallbackSize: '44.3 MiB',
  ),
  LanguagePackSeed(
    code: 'pt',
    label: 'Portoghese',
    nativeLabel: 'Português',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip',
    fallbackSize: '30.9 MiB',
  ),
  LanguagePackSeed(
    code: 'nl',
    label: 'Olandese',
    nativeLabel: 'Nederlands',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-nl-0.22.zip',
    fallbackSize: '38.6 MiB',
  ),
  LanguagePackSeed(
    code: 'ru',
    label: 'Russo',
    nativeLabel: 'Русский',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip',
    fallbackSize: '44.1 MiB',
  ),
  LanguagePackSeed(
    code: 'ua',
    label: 'Ucraino',
    nativeLabel: 'Українська',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-uk-v3-small.zip',
    fallbackSize: '137.2 MiB',
  ),
  LanguagePackSeed(
    code: 'tr',
    label: 'Turco',
    nativeLabel: 'Türkçe',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip',
    fallbackSize: '35.1 MiB',
  ),
  LanguagePackSeed(
    code: 'hi',
    label: 'Hindi',
    nativeLabel: 'हिन्दी',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip',
    fallbackSize: '42.4 MiB',
  ),
  LanguagePackSeed(
    code: 'ja',
    label: 'Giapponese',
    nativeLabel: '日本語',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-ja-0.22.zip',
    fallbackSize: '47.4 MiB',
  ),
  LanguagePackSeed(
    code: 'ko',
    label: 'Coreano',
    nativeLabel: '한국어',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-ko-0.22.zip',
    fallbackSize: '82.9 MiB',
  ),
  LanguagePackSeed(
    code: 'cn',
    label: 'Cinese',
    nativeLabel: '中文',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip',
    fallbackSize: '41.9 MiB',
  ),
  LanguagePackSeed(
    code: 'ar',
    label: 'Arabo',
    nativeLabel: 'العربية',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-ar-0.3.zip',
    fallbackSize: '99.5 MiB',
  ),
  LanguagePackSeed(
    code: 'pl',
    label: 'Polacco',
    nativeLabel: 'Polski',
    fallbackUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-pl-0.22.zip',
    fallbackSize: '50.5 MiB',
  ),
];
