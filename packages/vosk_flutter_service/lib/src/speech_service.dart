import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'recognizer.dart';
import 'vosk_flutter.dart';

/// Speech recognition service used to process audio input from the device's
/// microphone.
class SpeechService {
  /// Use [VoskFlutterPlugin.initSpeechService] to create an instance
  /// of [SpeechService].
  SpeechService(this._channel);

  final MethodChannel _channel;
  final StreamController<String> _iosResultController =
      StreamController<String>.broadcast();
  final StreamController<String> _iosPartialResultController =
      StreamController<String>.broadcast();

  Stream<String>? _resultStream;
  Stream<String>? _partialResultStream;
  StreamSubscription<void>? _errorStreamSubscription;

  bool get _usesMethodChannelCallbacks => Platform.isIOS;

  /// Start recognition.
  /// Use [onResult] and [onPartial] to get recognition results.
  Future<bool?> start({final Function? onRecognitionError}) {
    if (!_usesMethodChannelCallbacks) {
      _errorStreamSubscription ??= EventChannel(
        'error_event_channel',
        const StandardMethodCodec(),
        _channel.binaryMessenger,
      ).receiveBroadcastStream().listen(null, onError: onRecognitionError);
    }

    return _channel.invokeMethod<bool>('speechService.start');
  }

  /// Stop recognition.
  Future<bool?> stop() async {
    await _errorStreamSubscription?.cancel();
    return _channel.invokeMethod<bool>('speechService.stop');
  }

  /// Pause/unpause recognition.
  Future<bool?> setPause({required final bool paused}) =>
      _channel.invokeMethod<bool>('speechService.setPause', paused);

  /// Reset recognition.
  /// See [Recognizer.reset].
  Future<bool?> reset() => _channel.invokeMethod<bool>('speechService.reset');

  /// Cancel recognition.
  Future<bool?> cancel() async {
    await _errorStreamSubscription?.cancel();
    return _channel.invokeMethod<bool>('speechService.cancel');
  }

  /// Release service resources.
  Future<void> dispose() async {
    await _errorStreamSubscription?.cancel();
    if (!_iosResultController.isClosed) {
      await _iosResultController.close();
    }
    if (!_iosPartialResultController.isClosed) {
      await _iosPartialResultController.close();
    }
    return _channel.invokeMethod<void>('speechService.destroy');
  }

  /// Get stream with voice recognition results.
  Stream<String> onResult() => _usesMethodChannelCallbacks
      ? _iosResultController.stream
      : _resultStream ??= EventChannel(
          'result_event_channel',
          const StandardMethodCodec(),
          _channel.binaryMessenger,
        ).receiveBroadcastStream().map((final result) => result.toString());

  /// Get stream with voice recognition partial results.
  Stream<String> onPartial() => _usesMethodChannelCallbacks
      ? _iosPartialResultController.stream
      : _partialResultStream ??= EventChannel(
          'partial_event_channel',
          const StandardMethodCodec(),
          _channel.binaryMessenger,
        ).receiveBroadcastStream().map((final result) => result.toString());

  void emitResult(final String result) {
    if (!_iosResultController.isClosed) {
      _iosResultController.add(result);
    }
  }

  void emitPartial(final String result) {
    if (!_iosPartialResultController.isClosed) {
      _iosPartialResultController.add(result);
    }
  }
}
