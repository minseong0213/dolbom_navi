import 'package:flutter_test/flutter_test.dart';
import 'package:pregnant_nav/utils/navigation_camera_math.dart';

void main() {
  group('navigation camera math', () {
    test('rotates the map opposite to the vehicle heading', () {
      expect(mapRotationForHeading(0), 0);
      expect(mapRotationForHeading(90), -90);
      expect(mapRotationForHeading(270), -270);
    });

    test('uses the shortest turn across north', () {
      expect(shortestHeadingDelta(350, 10), 20);
      expect(shortestHeadingDelta(10, 350), -20);
      expect(lerpHeadingDegrees(350, 10, 0.5), 0);
      expect(lerpHeadingDegrees(10, 350, 0.5), 0);
    });

    test('normalizes headings', () {
      expect(normalizeDegrees(370), 10);
      expect(normalizeDegrees(-10), 350);
    });

    test('uses the same speed for short and long routes', () {
      final shortRouteProgress = nextSimulationProgress(
        currentProgressM: 0,
        pathLengthM: 2700,
        elapsedSeconds: 0.7,
      );
      final longRouteProgress = nextSimulationProgress(
        currentProgressM: 0,
        pathLengthM: 20000,
        elapsedSeconds: 0.7,
      );

      expect(shortRouteProgress, closeTo(21, 0.001));
      expect(longRouteProgress, closeTo(shortRouteProgress, 0.001));
    });

    test('does not advance past the destination', () {
      expect(
        nextSimulationProgress(
          currentProgressM: 95,
          pathLengthM: 100,
          elapsedSeconds: 1,
        ),
        100,
      );
    });
  });
}
