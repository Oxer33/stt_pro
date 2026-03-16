/// Schermata "Modalità Chat" per conversazioni in tempo reale.
///
/// Mostra ogni segmento di trascrizione come bolla separata,
/// con traduzione live sotto e TTS streaming automatico.
///
/// NON modifica la pipeline STT/traduzione.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/language_pack.dart';
import '../services/live_transcriber_controller.dart';
import '../services/tts_controller.dart';

/// Schermata full-screen per la modalità conversazione.
class ChatModeScreen extends StatefulWidget {
  const ChatModeScreen({
    required this.controller,
    required this.ttsController,
    super.key,
  });

  final LiveTranscriberController controller;
  final TtsController ttsController;

  @override
  State<ChatModeScreen> createState() => _ChatModeScreenState();
}

class _ChatModeScreenState extends State<ChatModeScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Tiene traccia dell'ultimo segmento tradotto per il TTS streaming.
  int _lastSpokenSegmentCount = 0;

  /// Salva lo stato streaming precedente per ripristinarlo all'uscita.
  late bool _previousStreamingState;

  @override
  void initState() {
    super.initState();

    // Attiva streaming TTS automaticamente nella chat mode.
    _previousStreamingState = widget.ttsController.isStreaming;
    unawaited(widget.ttsController.setStreaming(true));

    // Ascolta cambiamenti per auto-scroll e auto-TTS.
    widget.controller.addListener(_onControllerUpdate);
    widget.ttsController.addListener(_onTtsUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    widget.ttsController.removeListener(_onTtsUpdate);

    // Ripristina lo stato streaming precedente.
    unawaited(widget.ttsController.setStreaming(_previousStreamingState));

    _scrollController.dispose();
    super.dispose();
  }

  /// Callback: nuovi segmenti → auto-scroll + auto-TTS.
  void _onControllerUpdate() {
    _autoScrollToBottom();
    _autoSpeakNewSegments();
  }

  void _onTtsUpdate() {
    // Rebuild per aggiornare stato play/stop.
  }

  /// Scorri automaticamente in basso quando arrivano nuovi segmenti.
  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Accoda automaticamente i nuovi segmenti tradotti al TTS.
  void _autoSpeakNewSegments() {
    final segments = widget.controller.segments;

    for (var i = _lastSpokenSegmentCount; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.translation != null &&
          segment.translation!.trim().isNotEmpty) {
        widget.ttsController.enqueueSegment(
          segmentId: segment.id,
          text: segment.translation!,
        );
      }
    }

    // Aggiorna anche segmenti già noti che ora hanno traduzione.
    for (var i = 0; i < _lastSpokenSegmentCount && i < segments.length; i++) {
      final segment = segments[i];
      if (segment.translation != null &&
          segment.translation!.trim().isNotEmpty) {
        widget.ttsController.enqueueSegment(
          segmentId: segment.id,
          text: segment.translation!,
        );
      }
    }

    _lastSpokenSegmentCount = segments.length;
  }

  @override
  Widget build(final BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (final context, final _) => AnimatedBuilder(
        animation: widget.ttsController,
        builder: (final context, final _) => Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F3460),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Barra superiore ──
                  _ChatTopBar(
                    controller: widget.controller,
                    ttsController: widget.ttsController,
                    onClose: () => Navigator.of(context).pop(),
                  ),

                  // ── Lista bolle chat ──
                  Expanded(
                    child: _ChatBubbleList(
                      controller: widget.controller,
                      ttsController: widget.ttsController,
                      scrollController: _scrollController,
                    ),
                  ),

                  // ── Barra inferiore con controlli ──
                  _ChatBottomBar(
                    controller: widget.controller,
                    ttsController: widget.ttsController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Barra superiore ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar({
    required this.controller,
    required this.ttsController,
    required this.onClose,
  });

  final LiveTranscriberController controller;
  final TtsController ttsController;
  final VoidCallback onClose;

  @override
  Widget build(final BuildContext context) {
    final sourcePack = controller.selectedPack;
    final targetPack = controller.translationTargetPack;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Row(
        children: [
          // Pulsante chiudi
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Torna alla home',
          ),
          const SizedBox(width: 4),

          // Info lingue
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modalità Chat',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${sourcePack?.label ?? '?'} → ${targetPack?.label ?? '?'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0x99FFFFFF),
                  ),
                ),
              ],
            ),
          ),

          // Indicatore ascolto
          if (controller.isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F6B5E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

          // Toggle TTS streaming
          IconButton(
            onPressed: () {
              if (ttsController.isSpeaking) {
                unawaited(ttsController.stop());
              } else {
                unawaited(
                  ttsController.setStreaming(!ttsController.isStreaming),
                );
              }
            },
            icon: Icon(
              ttsController.isStreaming
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: ttsController.isStreaming
                  ? const Color(0xFF4ECDC4)
                  : const Color(0x66FFFFFF),
            ),
            tooltip: ttsController.isStreaming
                ? 'Disattiva lettura automatica'
                : 'Attiva lettura automatica',
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Lista bolle chat ────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ChatBubbleList extends StatelessWidget {
  const _ChatBubbleList({
    required this.controller,
    required this.ttsController,
    required this.scrollController,
  });

  final LiveTranscriberController controller;
  final TtsController ttsController;
  final ScrollController scrollController;

  @override
  Widget build(final BuildContext context) {
    final segments = controller.segments;
    final partialText = controller.partialText;
    final hasPartial = partialText.isNotEmpty;

    if (segments.isEmpty && !hasPartial) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: Color(0x44FFFFFF),
              ),
              const SizedBox(height: 16),
              Text(
                controller.isListening
                    ? 'In ascolto...\nParla per iniziare la conversazione'
                    : 'Premi il microfono per iniziare',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0x66FFFFFF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: segments.length + (hasPartial ? 1 : 0),
      itemBuilder: (final context, final index) {
        // Ultimo elemento = testo parziale
        if (index == segments.length && hasPartial) {
          return _PartialBubble(text: partialText);
        }

        final segment = segments[index];
        return _ChatBubble(segment: segment, ttsController: ttsController);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Bolla chat per segmento completo ────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.segment, required this.ttsController});

  final TranscriptSegment segment;
  final TtsController ttsController;

  @override
  Widget build(final BuildContext context) {
    final hasTranslation =
        segment.translation != null && segment.translation!.trim().isNotEmpty;
    final isTranslating = segment.isTranslating;

    final monoStyle = GoogleFonts.ibmPlexMono(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      height: 1.45,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Bolla originale (destra) ──
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0x22FFFFFF)),
              ),
              child: Text(
                segment.text,
                style: monoStyle.copyWith(color: const Color(0xCCFFFFFF)),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // ── Bolla traduzione (sinistra) ──
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasTranslation
                    ? const Color(0xFF0F6B5E)
                    : const Color(0xFF2A2A4A),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: hasTranslation
                      ? const Color(0x334ECDC4)
                      : const Color(0x22FFFFFF),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      hasTranslation
                          ? segment.translation!
                          : (isTranslating ? 'Traduco...' : '—'),
                      style: monoStyle.copyWith(
                        color: hasTranslation
                            ? Colors.white
                            : const Color(0x88FFFFFF),
                        fontStyle: isTranslating
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                  // Pulsante play singolo segmento
                  if (hasTranslation && ttsController.isEnabled) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          unawaited(ttsController.speak(segment.translation!)),
                      child: const Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: Color(0x99FFFFFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Timestamp ──
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(
              _formatTime(segment.capturedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0x44FFFFFF),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(final DateTime dateTime) {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    final s = dateTime.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Bolla parziale (testo in corso) ─────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _PartialBubble extends StatelessWidget {
  const _PartialBubble({required this.text});

  final String text;

  @override
  Widget build(final BuildContext context) {
    final monoStyle = GoogleFonts.ibmPlexMono(
      textStyle: Theme.of(context).textTheme.bodyMedium,
      height: 1.45,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x44C96B3B),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: const Color(0x33C96B3B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xAAC96B3B),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  style: monoStyle.copyWith(
                    color: const Color(0xAAC96B3B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Barra inferiore ─────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _ChatBottomBar extends StatelessWidget {
  const _ChatBottomBar({required this.controller, required this.ttsController});

  final LiveTranscriberController controller;
  final TtsController ttsController;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
        color: Color(0x22000000),
      ),
      child: Row(
        children: [
          // Pulsante microfono grande
          Expanded(child: _MicButton(controller: controller)),
          const SizedBox(width: 12),
          // Pulsante pulisci
          IconButton(
            onPressed: controller.hasTranscript
                ? () {
                    ttsController.clearQueue();
                    unawaited(ttsController.stop());
                    unawaited(controller.clearTranscript());
                  }
                : null,
            icon: Icon(
              Icons.delete_sweep_rounded,
              color: controller.hasTranscript
                  ? const Color(0x99FFFFFF)
                  : const Color(0x33FFFFFF),
            ),
            tooltip: 'Pulisci conversazione',
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({required this.controller});

  final LiveTranscriberController controller;

  @override
  Widget build(final BuildContext context) {
    final isListening = controller.isListening;

    return FilledButton.icon(
      onPressed: controller.isInitializing ? null : controller.toggleListening,
      icon: Icon(
        isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
        size: 28,
      ),
      label: Text(
        isListening ? 'Ferma ascolto' : 'Inizia ascolto',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: isListening
            ? const Color(0xFFC96B3B)
            : const Color(0xFF0F6B5E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
