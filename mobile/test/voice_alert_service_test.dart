import 'package:flutter_test/flutter_test.dart';
import 'package:pregnant_nav/models/route_models.dart';
import 'package:pregnant_nav/services/voice_alert_service.dart';

void main() {
  const warning = RouteWarning(
    kind: 'single',
    message: '500m 지점 방지턱',
    distanceAlongRouteM: 500,
    lat: 37.5,
    lon: 126.7,
    bumpCount: 1,
    impactSum: 1.0,
  );

  test('announces 300m and 100m thresholds once', () async {
    final spoken = <String>[];
    final controller = RouteVoiceAlertController(
      warnings: const [warning],
      speak: (message) async => spoken.add(message),
      enabled: true,
    );

    await controller.updateProgress(0);
    await controller.updateProgress(210);
    await controller.updateProgress(390);
    await controller.updateProgress(410);
    await controller.updateProgress(450);

    expect(spoken, hasLength(2));
    expect(spoken.first, contains('300미터'));
    expect(spoken.last, contains('100미터'));
  });

  test('does not announce pregnancy warnings in general mode', () async {
    final spoken = <String>[];
    final controller = RouteVoiceAlertController(
      warnings: const [warning],
      speak: (message) async => spoken.add(message),
      enabled: false,
    );

    await controller.updateProgress(450);

    expect(spoken, isEmpty);
  });

  test('uses a continuous-section voice message', () async {
    final spoken = <String>[];
    final controller = RouteVoiceAlertController(
      warnings: const [
        RouteWarning(
          kind: 'continuous',
          message: '250m 지점 연속 방지턱 구간',
          distanceAlongRouteM: 250,
          lat: 37.5,
          lon: 126.7,
          bumpCount: 3,
          impactSum: 2.0,
        ),
      ],
      speak: (message) async => spoken.add(message),
      enabled: true,
    );

    await controller.updateProgress(0);

    expect(spoken.single, contains('연속 방지턱 구간'));
  });
}
