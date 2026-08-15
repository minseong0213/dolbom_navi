import 'package:flutter_tts/flutter_tts.dart';

import '../models/route_models.dart';

typedef VoiceSpeaker = Future<void> Function(String message);

class VoiceAlertService {
  VoiceAlertService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready) {
      return;
    }
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.46);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);
    _ready = true;
  }

  Future<void> speak(String message) async {
    if (!_ready) {
      await initialize();
    }
    await _tts.speak(message);
  }

  Future<void> dispose() => _tts.stop();
}

class RouteVoiceAlertController {
  RouteVoiceAlertController({
    required this.warnings,
    required this.speak,
    required this.enabled,
  });

  final List<RouteWarning> warnings;
  final VoiceSpeaker speak;
  final bool enabled;

  final Set<String> _announced = {};
  double? _previousProgressM;

  Future<void> updateProgress(double progressM) async {
    if (!enabled || warnings.isEmpty) {
      _previousProgressM = progressM;
      return;
    }

    final messages = <String>[];
    for (var index = 0; index < warnings.length; index += 1) {
      final warning = warnings[index];
      final remainingM = warning.distanceAlongRouteM - progressM;
      final previousRemainingM = _previousProgressM == null
          ? double.infinity
          : warning.distanceAlongRouteM - _previousProgressM!;
      if (remainingM < 0) {
        continue;
      }

      final triggers = [...warning.triggerDistancesM]..sort();
      int? crossedTrigger;
      for (final trigger in triggers) {
        final key = '$index:$trigger';
        if (_announced.contains(key)) {
          continue;
        }
        if (remainingM <= trigger && previousRemainingM > trigger) {
          crossedTrigger = trigger;
          break;
        }
      }
      if (crossedTrigger == null) {
        continue;
      }

      for (final trigger in triggers) {
        if (trigger >= crossedTrigger) {
          _announced.add('$index:$trigger');
        }
      }
      messages.add(_messageFor(warning, crossedTrigger));
    }

    _previousProgressM = progressM;
    if (messages.isNotEmpty) {
      await speak(messages.join(' '));
    }
  }

  String _messageFor(RouteWarning warning, int triggerM) {
    final distanceText = [triggerM, '미터'].join();
    if (warning.kind == 'continuous') {
      return [
        '전방 ',
        distanceText,
        '부터 연속 방지턱 구간입니다. 속도를 줄이고 천천히 주행해 주세요.',
      ].join();
    }
    return [
      '전방 ',
      distanceText,
      '에 방지턱이 있습니다. 속도를 줄여 주세요.',
    ].join();
  }
}
