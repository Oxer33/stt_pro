import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/models/language_pack.dart';
import 'src/services/live_transcriber_controller.dart';
import 'src/services/tts_controller.dart';

const _translationOffValue = '__off__';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SttProApp());
}

class SttProApp extends StatelessWidget {
  const SttProApp({super.key});

  @override
  Widget build(final BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F6B5E),
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFF0F6B5E),
            secondary: const Color(0xFFC96B3B),
            surface: Colors.white,
          ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'STT Pro',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4EEE2),
        textTheme: GoogleFonts.spaceGroteskTextTheme(baseTheme.textTheme),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFF0F6B5E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: const Color(0xFF13231F),
            side: const BorderSide(color: Color(0x332F5D54)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAF9),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x1A13231F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0x1A13231F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0F6B5E)),
          ),
        ),
      ),
      home: const LiveTranscriberScreen(),
    );
  }
}

class LiveTranscriberScreen extends StatefulWidget {
  const LiveTranscriberScreen({super.key});

  @override
  State<LiveTranscriberScreen> createState() => _LiveTranscriberScreenState();
}

class _LiveTranscriberScreenState extends State<LiveTranscriberScreen> {
  late final LiveTranscriberController _controller;
  late final TtsController _ttsController;

  /// Tiene traccia del codice target per sincronizzare il TTS.
  String? _lastTranslationTargetCode;

  @override
  void initState() {
    super.initState();
    _controller = LiveTranscriberController();
    _ttsController = TtsController();
    unawaited(_controller.initialize());
    unawaited(_ttsController.initialize());

    // Sincronizza la lingua TTS ogni volta che cambia il target traduzione.
    _controller.addListener(_syncTtsLanguage);
  }

  void _syncTtsLanguage() {
    final targetCode = _controller.translationTargetCode;
    if (targetCode != _lastTranslationTargetCode) {
      _lastTranslationTargetCode = targetCode;
      unawaited(_ttsController.setLanguageFromAppCode(targetCode));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncTtsLanguage);
    _ttsController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (final context, final child) => AnimatedBuilder(
        animation: _ttsController,
        builder: (final context, final child) {
          final translatedBody = _translatedText(_controller.segments);
          return Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF7F0E5),
                    Color(0xFFE7F0ED),
                    Color(0xFFF4E6D8),
                  ],
                ),
              ),
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _controller.refreshCatalog,
                  color: const Color(0xFF0F6B5E),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    children: [
                      _TopBar(controller: _controller),
                      const SizedBox(height: 12),
                      _ControlsCard(controller: _controller),
                      const SizedBox(height: 12),
                      _TranscriptPanel(
                        title: 'Testo',
                        body: _committedText(_controller.segments),
                        trailing: _controller.partialText,
                        status:
                            _controller.errorMessage ??
                            _controller.statusMessage,
                      ),
                      if (_controller.isTranslationEnabled) ...[
                        const SizedBox(height: 12),
                        _TranscriptPanel(
                          title:
                              'Traduzione ${_controller.translationTargetPack?.label ?? ''}',
                          body: translatedBody,
                          trailing: '',
                          status:
                              _controller.translationErrorMessage ??
                              _controller.translationStatusMessage,
                          isLoading: _controller.isPreparingTranslation,
                        ),
                        // ── Pulsante Play/Stop TTS sotto la traduzione ──
                        if (_ttsController.isEnabled &&
                            translatedBody.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _TtsPlaybackRow(
                            ttsController: _ttsController,
                            translatedText: translatedBody,
                          ),
                        ],
                        // ── Avviso voce non disponibile ──
                        if (_ttsController.warningMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _ttsController.warningMessage!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF9B2C2C)),
                          ),
                        ],
                      ],
                      const SizedBox(height: 12),
                      _TtsSettingsCard(ttsController: _ttsController),
                      const SizedBox(height: 12),
                      _LanguagesPanel(controller: _controller),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _committedText(final List<TranscriptSegment> segments) {
    final text = segments.map((final segment) => segment.text).join('\n');
    return text.trim();
  }

  String _translatedText(final List<TranscriptSegment> segments) {
    final lines = segments
        .map((final segment) {
          if (segment.translation != null &&
              segment.translation!.trim().isNotEmpty) {
            return segment.translation!;
          }
          if (segment.isTranslating) {
            return '...';
          }
          return '';
        })
        .where((final line) => line.isNotEmpty)
        .toList();

    return lines.join('\n').trim();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final LiveTranscriberController controller;

  @override
  Widget build(final BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'STT Pro',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF13231F),
            ),
          ),
        ),
        IconButton(
          onPressed: controller.refreshCatalog,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Aggiorna',
        ),
      ],
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({required this.controller});

  final LiveTranscriberController controller;

  @override
  Widget build(final BuildContext context) {
    final selectedPack = controller.selectedPack;
    final isReady =
        selectedPack != null &&
        controller.installStateFor(selectedPack).index >=
            LanguagePackInstallState.installed.index;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LanguageDropdown(
            label: 'Ingresso',
            value: selectedPack?.code,
            items: controller.packs
                .map(
                  (final pack) => DropdownMenuItem<String>(
                    value: pack.code,
                    child: Text(pack.label),
                  ),
                )
                .toList(),
            onChanged: (final value) {
              if (value == null) {
                return;
              }

              final pack = controller.packs.firstWhere(
                (final element) => element.code == value,
              );
              unawaited(controller.selectLanguage(pack));
            },
          ),
          const SizedBox(height: 12),
          _LanguageDropdown(
            label: 'Traduci in',
            value: controller.translationTargetCode ?? _translationOffValue,
            items: [
              const DropdownMenuItem<String>(
                value: _translationOffValue,
                child: Text('Disattiva'),
              ),
              ...controller.translationTargetPacks.map(
                (final pack) => DropdownMenuItem<String>(
                  value: pack.code,
                  child: Text(pack.label),
                ),
              ),
            ],
            onChanged: (final value) {
              final normalized = value == _translationOffValue ? null : value;
              unawaited(controller.setTranslationTargetCode(normalized));
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: controller.isInitializing || !isReady
                      ? null
                      : controller.toggleListening,
                  icon: Icon(
                    controller.isListening
                        ? Icons.stop_circle_rounded
                        : Icons.mic_rounded,
                  ),
                  label: Text(controller.isListening ? 'Ferma' : 'Ascolta'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.hasTranscript
                      ? controller.clearTranscript
                      : null,
                  icon: const Icon(Icons.layers_clear_rounded),
                  label: const Text('Pulisci'),
                ),
              ),
            ],
          ),
          if (controller.isInitializing ||
              controller.isPreparingTranslation ||
              controller.errorMessage != null ||
              controller.translationErrorMessage != null ||
              controller.statusMessage != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (controller.isInitializing ||
                    controller.isPreparingTranslation)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    controller.errorMessage ??
                        controller.translationErrorMessage ??
                        controller.statusMessage ??
                        '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          controller.errorMessage == null &&
                              controller.translationErrorMessage == null
                          ? const Color(0xFF4A5B56)
                          : const Color(0xFF9B2C2C),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({
    required this.title,
    required this.body,
    required this.trailing,
    required this.status,
    this.isLoading = false,
  });

  final String title;
  final String body;
  final String trailing;
  final String? status;
  final bool isLoading;

  @override
  Widget build(final BuildContext context) {
    final monoStyle = GoogleFonts.ibmPlexMono(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      color: const Color(0xFF102723),
      height: 1.45,
    );

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF13231F),
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(body.isEmpty ? '—' : body, style: monoStyle),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              trailing,
              style: monoStyle.copyWith(color: const Color(0xFF6B3A1F)),
            ),
          ],
          if (status != null && status!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              status!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF4A5B56)),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguagesPanel extends StatelessWidget {
  const _LanguagesPanel({required this.controller});

  final LiveTranscriberController controller;

  @override
  Widget build(final BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lingue',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF13231F),
            ),
          ),
          const SizedBox(height: 10),
          ...controller.packs.map(
            (final pack) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LanguageRow(controller: controller, pack: pack),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.controller, required this.pack});

  final LiveTranscriberController controller;
  final LanguagePack pack;

  @override
  Widget build(final BuildContext context) {
    final state = controller.installStateFor(pack);
    final isActive = state == LanguagePackInstallState.active;
    final canDelete = state == LanguagePackInstallState.installed || isActive;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: controller.isSelected(pack)
            ? const Color(0xFFF8FBFA)
            : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: controller.isSelected(pack)
              ? const Color(0xFF0F6B5E)
              : const Color(0x1A13231F),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF13231F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pack.resolvedSize} • ${_stateLabel(state)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF556661),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: switch (state) {
              LanguagePackInstallState.available =>
                () => controller.downloadLanguage(pack),
              LanguagePackInstallState.installed =>
                () => controller.selectLanguage(pack),
              LanguagePackInstallState.active => null,
              LanguagePackInstallState.downloading => null,
              LanguagePackInstallState.preparing => null,
              LanguagePackInstallState.deleting => null,
            },
            child: Text(_primaryLabel(state)),
          ),
          IconButton(
            onPressed: canDelete ? () => controller.deleteLanguage(pack) : null,
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Elimina',
          ),
        ],
      ),
    );
  }

  String _primaryLabel(final LanguagePackInstallState state) {
    switch (state) {
      case LanguagePackInstallState.available:
        return 'Scarica';
      case LanguagePackInstallState.installed:
        return 'Usa';
      case LanguagePackInstallState.active:
        return 'Attiva';
      case LanguagePackInstallState.downloading:
        return '...';
      case LanguagePackInstallState.preparing:
        return '...';
      case LanguagePackInstallState.deleting:
        return '...';
    }
  }

  String _stateLabel(final LanguagePackInstallState state) {
    switch (state) {
      case LanguagePackInstallState.available:
        return 'Non scaricata';
      case LanguagePackInstallState.downloading:
        return 'Download';
      case LanguagePackInstallState.preparing:
        return 'Setup';
      case LanguagePackInstallState.deleting:
        return 'Rimozione';
      case LanguagePackInstallState.installed:
        return 'Pronta';
      case LanguagePackInstallState.active:
        return 'Attiva';
    }
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(final BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(18),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Widget TTS: pulsante Play/Stop sotto la traduzione ──────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _TtsPlaybackRow extends StatelessWidget {
  const _TtsPlaybackRow({
    required this.ttsController,
    required this.translatedText,
  });

  final TtsController ttsController;
  final String translatedText;

  @override
  Widget build(final BuildContext context) {
    final isSpeaking = ttsController.isSpeaking;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              if (isSpeaking) {
                unawaited(ttsController.stop());
              } else {
                unawaited(ttsController.speak(translatedText));
              }
            },
            icon: Icon(
              isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
            ),
            label: Text(isSpeaking ? 'Ferma lettura' : 'Leggi traduzione'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: isSpeaking
                  ? const Color(0xFFC96B3B)
                  : const Color(0xFF0F6B5E),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Widget TTS: card impostazioni ───────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _TtsSettingsCard extends StatelessWidget {
  const _TtsSettingsCard({required this.ttsController});

  final TtsController ttsController;

  @override
  Widget build(final BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titolo + Toggle ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sintesi vocale (TTS)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF13231F),
                  ),
                ),
              ),
              Switch.adaptive(
                value: ttsController.isEnabled,
                activeTrackColor: const Color(0xFF0F6B5E),
                onChanged: (final value) =>
                    unawaited(ttsController.setEnabled(value)),
              ),
            ],
          ),

          if (ttsController.isEnabled) ...[
            const SizedBox(height: 12),

            // ── Slider velocità ──
            Text(
              'Velocità: ${ttsController.displayRate.toStringAsFixed(1)}x',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF4A5B56)),
            ),
            Slider(
              value: ttsController.displayRate,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${ttsController.displayRate.toStringAsFixed(1)}x',
              activeColor: const Color(0xFF0F6B5E),
              onChanged: (final value) => unawaited(
                ttsController.setSpeechRate(
                  TtsController.displayRateToInternal(value),
                ),
              ),
            ),

            // ── Dropdown voce ──
            if (ttsController.availableVoices.isNotEmpty) ...[
              const SizedBox(height: 8),
              _VoiceDropdown(ttsController: ttsController),
            ],
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Widget TTS: dropdown selezione voce ─────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _VoiceDropdown extends StatelessWidget {
  const _VoiceDropdown({required this.ttsController});

  final TtsController ttsController;

  @override
  Widget build(final BuildContext context) {
    final voices = ttsController.availableVoices;
    final currentName = ttsController.preferredVoiceName;

    // Verifica che il valore corrente esista tra le opzioni
    final hasCurrentVoice =
        currentName != null &&
        voices.any((final v) => v['name'] == currentName);

    return DropdownButtonFormField<String>(
      initialValue: hasCurrentVoice ? currentName : null,
      decoration: const InputDecoration(labelText: 'Voce'),
      hint: const Text('Seleziona voce'),
      borderRadius: BorderRadius.circular(18),
      items: voices.map((final voice) {
        final name = voice['name'] ?? 'Sconosciuta';
        final displayName = _formatVoiceName(name);
        return DropdownMenuItem<String>(
          value: name,
          child: Text(displayName, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (final selectedName) {
        if (selectedName == null) return;
        final voice = voices.firstWhere(
          (final v) => v['name'] == selectedName,
          orElse: () => <String, String>{},
        );
        if (voice.isNotEmpty) {
          unawaited(ttsController.setVoice(voice));
        }
      },
    );
  }

  /// Formatta il nome della voce per la visualizzazione nell'interfaccia.
  String _formatVoiceName(final String rawName) {
    // Rimuove prefissi comuni dei motori TTS Android
    var name = rawName;
    for (final prefix in ['com.google.android.tts:', 'com.samsung.SMT:']) {
      if (name.startsWith(prefix)) {
        name = name.substring(prefix.length);
      }
    }
    // Capitalizza
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xBCFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1A13231F)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 26,
            offset: Offset(0, 14),
            color: Color(0x120A201B),
          ),
        ],
      ),
      child: child,
    );
  }
}
