import 'dart:math' as math;

class BumpFeatures {
  const BumpFeatures({
    required this.zMax,
    required this.zMin,
    required this.amplitude,
    required this.standardDeviation,
    required this.absoluteMean,
    required this.peakOrder,
    required this.peakTimeDifferenceS,
    required this.energy,
    required this.zeroCrossings,
    required this.kurtosis,
  });

  final double zMax;
  final double zMin;
  final double amplitude;
  final double standardDeviation;
  final double absoluteMean;
  final double peakOrder;
  final double peakTimeDifferenceS;
  final double energy;
  final int zeroCrossings;
  final double kurtosis;

  List<double> toModelInput() => [
        zMax,
        zMin,
        amplitude,
        standardDeviation,
        absoluteMean,
        peakOrder,
        peakTimeDifferenceS,
        energy,
        zeroCrossings.toDouble(),
        kurtosis,
      ];
}

class BumpFeatureExtractor {
  const BumpFeatureExtractor({this.sampleRateHz = 50});

  final double sampleRateHz;

  BumpFeatures extract(List<double> zSamples) {
    if (zSamples.isEmpty) {
      throw ArgumentError.value(zSamples, 'zSamples', '샘플이 비어 있습니다.');
    }

    var zMax = zSamples.first;
    var zMin = zSamples.first;
    var maxIndex = 0;
    var minIndex = 0;
    var sum = 0.0;
    var absoluteSum = 0.0;
    var energySum = 0.0;
    var zeroCrossings = 0;

    for (var index = 0; index < zSamples.length; index += 1) {
      final value = zSamples[index];
      if (value > zMax) {
        zMax = value;
        maxIndex = index;
      }
      if (value < zMin) {
        zMin = value;
        minIndex = index;
      }
      sum += value;
      absoluteSum += value.abs();
      energySum += value * value;
      if (index > 0 && _signChanged(zSamples[index - 1], value)) {
        zeroCrossings += 1;
      }
    }

    final mean = sum / zSamples.length;
    final variance = zSamples
            .map((value) => math.pow(value - mean, 2).toDouble())
            .reduce((left, right) => left + right) /
        zSamples.length;
    final standardDeviation = math.sqrt(variance);
    final kurtosis = standardDeviation == 0
        ? 0.0
        : zSamples
                .map(
                  (value) => math
                      .pow((value - mean) / standardDeviation, 4)
                      .toDouble(),
                )
                .reduce((left, right) => left + right) /
            zSamples.length;

    return BumpFeatures(
      zMax: zMax,
      zMin: zMin,
      amplitude: zMax - zMin,
      standardDeviation: standardDeviation,
      absoluteMean: absoluteSum / zSamples.length,
      peakOrder: maxIndex < minIndex ? 1.0 : 0.0,
      peakTimeDifferenceS: (maxIndex - minIndex).abs() / sampleRateHz,
      energy: energySum / zSamples.length,
      zeroCrossings: zeroCrossings,
      kurtosis: kurtosis,
    );
  }

  bool _signChanged(double previous, double current) {
    return (previous < 0 && current >= 0) || (previous >= 0 && current < 0);
  }
}

class BumpDetectionGate {
  BumpDetectionGate({
    this.minSpeedKmh = 10,
    this.maxAccelMps2 = 15,
    this.minConfidence = 0.7,
    this.cooldown = const Duration(seconds: 2),
  });

  final double minSpeedKmh;
  final double maxAccelMps2;
  final double minConfidence;
  final Duration cooldown;

  DateTime? _lastAcceptedAt;

  bool accept({
    required double speedKmh,
    required double zPeakMps2,
    required double confidence,
    required DateTime detectedAt,
  }) {
    if (speedKmh <= minSpeedKmh ||
        zPeakMps2.abs() > maxAccelMps2 ||
        confidence < minConfidence) {
      return false;
    }
    if (_lastAcceptedAt != null &&
        detectedAt.difference(_lastAcceptedAt!) < cooldown) {
      return false;
    }
    _lastAcceptedAt = detectedAt;
    return true;
  }
}
