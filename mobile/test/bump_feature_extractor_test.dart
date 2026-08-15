import 'package:flutter_test/flutter_test.dart';
import 'package:pregnant_nav/services/bump_feature_extractor.dart';

void main() {
  test('extracts the documented ten Z-axis features', () {
    const extractor = BumpFeatureExtractor(sampleRateHz: 50);
    final features = extractor.extract([-2, -1, 0, 3, 1]);

    expect(features.zMax, 3);
    expect(features.zMin, -2);
    expect(features.amplitude, 5);
    expect(features.absoluteMean, 1.4);
    expect(features.peakOrder, 0);
    expect(features.peakTimeDifferenceS, 0.06);
    expect(features.zeroCrossings, 1);
    expect(features.toModelInput(), hasLength(10));
  });

  test('applies speed, acceleration, confidence and cooldown filters', () {
    final gate = BumpDetectionGate();
    final now = DateTime.utc(2026, 7, 12, 12);

    expect(
      gate.accept(
        speedKmh: 10,
        zPeakMps2: 5,
        confidence: 0.9,
        detectedAt: now,
      ),
      isFalse,
    );
    expect(
      gate.accept(
        speedKmh: 20,
        zPeakMps2: 16,
        confidence: 0.9,
        detectedAt: now,
      ),
      isFalse,
    );
    expect(
      gate.accept(
        speedKmh: 20,
        zPeakMps2: 5,
        confidence: 0.69,
        detectedAt: now,
      ),
      isFalse,
    );
    expect(
      gate.accept(
        speedKmh: 20,
        zPeakMps2: 5,
        confidence: 0.9,
        detectedAt: now,
      ),
      isTrue,
    );
    expect(
      gate.accept(
        speedKmh: 20,
        zPeakMps2: 5,
        confidence: 0.9,
        detectedAt: now.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      gate.accept(
        speedKmh: 20,
        zPeakMps2: 5,
        confidence: 0.9,
        detectedAt: now.add(const Duration(seconds: 2)),
      ),
      isTrue,
    );
  });
}
