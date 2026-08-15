import 'dart:math' as math;

const simulationSpeedMps = 30.0;

double nextSimulationProgress({
  required double currentProgressM,
  required double pathLengthM,
  required double elapsedSeconds,
  double speedMps = simulationSpeedMps,
}) {
  if (pathLengthM <= 0) {
    return 0;
  }
  final safeCurrentM = currentProgressM.clamp(0.0, pathLengthM).toDouble();
  final advanceM = math.max(0.0, elapsedSeconds) * math.max(0.0, speedMps);
  return math.min(pathLengthM, safeCurrentM + advanceM);
}

double normalizeDegrees(double degrees) {
  final normalized = degrees % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

double shortestHeadingDelta(double fromDegrees, double toDegrees) {
  final from = normalizeDegrees(fromDegrees);
  final to = normalizeDegrees(toDegrees);
  return (to - from + 540) % 360 - 180;
}

double lerpHeadingDegrees(
  double fromDegrees,
  double toDegrees,
  double t,
) {
  final clampedT = t.clamp(0.0, 1.0).toDouble();
  return normalizeDegrees(
    fromDegrees + shortestHeadingDelta(fromDegrees, toDegrees) * clampedT,
  );
}

double mapRotationForHeading(double headingDegrees) {
  return -normalizeDegrees(headingDegrees);
}
