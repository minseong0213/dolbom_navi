import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/scheduler.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_models.dart';
import '../services/voice_alert_service.dart';
import '../theme/nav_mode_palette.dart';
import '../utils/navigation_camera_math.dart';

const _guideOrange = Color(0xFFFF8A3D);
const _guideInk = Color(0xFF17171B);
const _guideMuted = Color(0xFF8B8B94);
const _guideLine = Color(0xFFECECF0);
const _guideSoft = Color(0xFFF5F5F8);
const _simulationFrameInterval = Duration(milliseconds: 33);
const _voiceUpdateInterval = Duration(milliseconds: 200);
const _cameraLookAheadM = 55.0;
const _headingSmoothingTimeS = 0.18;

class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({
    super.key,
    required this.route,
    required this.origin,
    required this.destination,
    required this.pregnancyMode,
    required this.onExit,
  });

  final CandidateRoute route;
  final Coordinate? origin;
  final Coordinate? destination;
  final bool pregnancyMode;
  final VoidCallback onExit;

  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final _distance = const Distance();
  late final VoiceAlertService _voiceAlertService;
  late final RouteVoiceAlertController _voiceAlertController;
  late final Ticker _driveTicker;

  late final List<LatLng> _points;
  late final List<double> _cumulativeMeters;
  late final double _pathLengthM;
  late double _progressM;
  Duration? _lastDriveElapsed;
  double _frameAccumulatorS = 0;
  double _voiceUpdateAccumulatorS = 0;
  double _headingDeg = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _points = widget.route.polyline
        .map((point) => LatLng(point.lat, point.lon))
        .toList();
    _cumulativeMeters = _buildCumulativeMeters(_points);
    _pathLengthM = _cumulativeMeters.isEmpty ? 0 : _cumulativeMeters.last;
    _progressM = 0;
    _headingDeg = _bearingAt(0);
    _driveTicker = createTicker(_onDriveTick);
    _voiceAlertService = VoiceAlertService();
    _voiceAlertController = RouteVoiceAlertController(
      warnings: widget.route.warnings,
      speak: _voiceAlertService.speak,
      enabled: widget.pregnancyMode,
    );
    unawaited(_prepareVoiceAlerts());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnCurrentLocation();
      _startDrive();
    });
  }

  @override
  void dispose() {
    _driveTicker.dispose();
    unawaited(_voiceAlertService.dispose());
    super.dispose();
  }

  Future<void> _prepareVoiceAlerts() async {
    if (!widget.pregnancyMode) {
      return;
    }
    try {
      await _voiceAlertService.initialize();
      if (mounted) {
        await _voiceAlertController.updateProgress(_progressM);
      }
    } catch (_) {
      // Visual warnings remain available if the device has no Korean TTS engine.
    }
  }

  void _startDrive() {
    if (_paused || _pathLengthM <= 0 || _driveTicker.isActive) {
      return;
    }
    _lastDriveElapsed = null;
    _frameAccumulatorS = 0;
    _driveTicker.start();
  }

  void _onDriveTick(Duration elapsed) {
    if (!mounted || _paused || _pathLengthM <= 0) {
      return;
    }

    final previousElapsed = _lastDriveElapsed;
    _lastDriveElapsed = elapsed;
    if (previousElapsed == null) {
      return;
    }

    final elapsedS = (elapsed - previousElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (elapsedS <= 0) {
      return;
    }

    final cappedElapsedS = math.min(elapsedS, 0.1);
    _frameAccumulatorS += cappedElapsedS;
    _voiceUpdateAccumulatorS += cappedElapsedS;
    final frameIntervalS = _simulationFrameInterval.inMicroseconds /
        Duration.microsecondsPerSecond;
    if (_frameAccumulatorS < frameIntervalS) {
      return;
    }

    final driveElapsedS = math.min(_frameAccumulatorS, 0.1);
    _frameAccumulatorS = 0;
    final progressM = nextSimulationProgress(
      currentProgressM: _progressM,
      pathLengthM: _pathLengthM,
      elapsedSeconds: driveElapsedS,
    );
    final desiredHeadingDeg = _bearingAt(progressM);
    final headingBlend = 1 - math.exp(-driveElapsedS / _headingSmoothingTimeS);
    final arrived = progressM >= _pathLengthM;

    setState(() {
      _progressM = progressM;
      _headingDeg = lerpHeadingDegrees(
        _headingDeg,
        desiredHeadingDeg,
        headingBlend,
      );
      if (arrived) {
        _paused = true;
      }
    });
    _centerOnCurrentLocation();

    final voiceIntervalS =
        _voiceUpdateInterval.inMicroseconds / Duration.microsecondsPerSecond;
    if (_voiceUpdateAccumulatorS >= voiceIntervalS || arrived) {
      _voiceUpdateAccumulatorS = 0;
      unawaited(_voiceAlertController.updateProgress(_progressM));
    }
    if (arrived) {
      _driveTicker.stop();
      _lastDriveElapsed = null;
    }
  }

  void _centerOnCurrentLocation() {
    if (_points.isEmpty) {
      return;
    }

    try {
      _mapController.moveAndRotate(
        _cameraCenter,
        17.5,
        mapRotationForHeading(_headingDeg),
      );
    } catch (_) {
      // The map controller may not be attached during the first frame.
    }
  }

  LatLng get _currentLocation => _interpolateAt(_progressM);

  LatLng get _cameraCenter {
    final remainingM = math.max(0.0, _pathLengthM - _progressM);
    final lookAheadM = math.min(_cameraLookAheadM, remainingM);
    if (lookAheadM < 1) {
      return _currentLocation;
    }
    return _offsetLatLng(_currentLocation, _headingDeg, lookAheadM);
  }

  double get _progressRatio {
    if (_pathLengthM <= 0) {
      return 0;
    }
    return (_progressM / _pathLengthM).clamp(0.0, 1.0);
  }

  bool get _arrived => _pathLengthM > 0 && _progressM >= _pathLengthM;

  RouteWarning? get _activeWarning {
    if (!widget.pregnancyMode) {
      return null;
    }
    for (final warning in widget.route.warnings) {
      final remainingM = warning.distanceAlongRouteM - _progressM;
      if (remainingM >= 0 && remainingM <= 300) {
        return warning;
      }
    }
    return null;
  }

  RouteWarning? get _nextWarning {
    if (!widget.pregnancyMode) {
      return null;
    }
    for (final warning in widget.route.warnings) {
      if (warning.distanceAlongRouteM > _progressM) {
        return warning;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = _currentLocation;
    final remainingDistanceM =
        widget.route.summary.totalDistanceM * (1 - _progressRatio);
    final remainingTimeS =
        widget.route.summary.totalTimeS * (1 - _progressRatio);
    final activeWarning = _activeWarning;
    final nextWarning = _nextWarning;

    return Stack(
      children: [
        _SimulationMapStage(
          mapController: _mapController,
          initialCenter: _points.isNotEmpty
              ? _points.first
              : const LatLng(37.5064, 126.7216),
          points: _points,
          currentLocation: currentLocation,
          destination: widget.destination,
          warnings: widget.pregnancyMode ? widget.route.warnings : const [],
          activeWarning: activeWarning,
          headingDeg: _headingDeg,
        ),
        const Positioned.fill(
            child: IgnorePointer(child: _GuidanceMapChrome())),
        Positioned(
          top: MediaQuery.of(context).padding.top + 270,
          right: 14,
          child: _CompassChip(headingDeg: _headingDeg),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 14,
          right: 14,
          child: _GuidanceTopPanel(
            arrived: _arrived,
            activeWarning: activeWarning,
            nextWarning: nextWarning,
            progressM: _progressM,
            remainingDistanceM: remainingDistanceM,
            remainingTimeS: remainingTimeS,
            pregnancyMode: widget.pregnancyMode,
            onExit: widget.onExit,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _GuidanceBottomPanel(
            route: widget.route,
            destinationName: widget.destination?.name ?? '목적지',
            remainingDistanceM: remainingDistanceM,
            remainingTimeS: remainingTimeS,
            progressRatio: _progressRatio,
            paused: _paused,
            arrived: _arrived,
            pregnancyMode: widget.pregnancyMode,
            onTogglePause: _togglePause,
            onExit: widget.onExit,
          ),
        ),
      ],
    );
  }

  List<double> _buildCumulativeMeters(List<LatLng> points) {
    if (points.isEmpty) {
      return const [];
    }

    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i += 1) {
      cumulative.add(cumulative.last + _distance(points[i - 1], points[i]));
    }
    return cumulative;
  }

  LatLng _interpolateAt(double distanceM) {
    if (_points.isEmpty) {
      return const LatLng(37.5064, 126.7216);
    }
    if (_points.length == 1 || distanceM <= 0) {
      return _points.first;
    }
    if (distanceM >= _pathLengthM) {
      return _points.last;
    }

    for (var i = 1; i < _cumulativeMeters.length; i += 1) {
      final segmentStartM = _cumulativeMeters[i - 1];
      final segmentEndM = _cumulativeMeters[i];
      if (distanceM > segmentEndM) {
        continue;
      }

      final segmentLengthM = math.max(1.0, segmentEndM - segmentStartM);
      final t = ((distanceM - segmentStartM) / segmentLengthM).clamp(0.0, 1.0);
      final start = _points[i - 1];
      final end = _points[i];
      return LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      );
    }

    return _points.last;
  }

  double _bearingAt(double distanceM) {
    if (_points.length < 2) {
      return 0;
    }

    var startM = math.max(0.0, distanceM - 8);
    var endM = math.min(_pathLengthM, distanceM + _cameraLookAheadM);
    if (endM - startM < 1) {
      startM = math.max(0.0, _pathLengthM - _cameraLookAheadM);
      endM = _pathLengthM;
    }
    final start = _interpolateAt(startM);
    final end = _interpolateAt(endM);
    final lat1 = start.latitudeInRad;
    final lat2 = end.latitudeInRad;
    final deltaLon = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  LatLng _offsetLatLng(LatLng origin, double bearingDeg, double distanceM) {
    const earthRadiusM = 6371000.0;
    final angularDistance = distanceM / earthRadiusM;
    final bearingRad = bearingDeg * math.pi / 180;
    final lat1 = origin.latitudeInRad;
    final lon1 = origin.longitudeInRad;
    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearingRad),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearingRad) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  void _togglePause() {
    if (_arrived) {
      return;
    }
    if (_paused) {
      setState(() => _paused = false);
      _startDrive();
      return;
    }
    _driveTicker.stop();
    _lastDriveElapsed = null;
    setState(() => _paused = true);
  }
}

class _SimulationMapStage extends StatelessWidget {
  const _SimulationMapStage({
    required this.mapController,
    required this.initialCenter,
    required this.points,
    required this.currentLocation,
    required this.destination,
    required this.warnings,
    required this.activeWarning,
    required this.headingDeg,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final List<LatLng> points;
  final LatLng currentLocation;
  final Coordinate? destination;
  final List<RouteWarning> warnings;
  final RouteWarning? activeWarning;
  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Transform.scale(
      scale: 1.18,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(-0.48),
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 17,
            initialRotation: mapRotationForHeading(headingDeg),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pregnantnav.mvp',
            ),
            if (points.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                      points: points, color: Colors.white, strokeWidth: 16),
                  Polyline(
                    points: points,
                    color: palette.primary.withValues(alpha: 0.33),
                    strokeWidth: 12,
                  ),
                  Polyline(
                    points: points,
                    color: palette.primary,
                    strokeWidth: 8,
                  ),
                ],
              ),
            MarkerLayer(
              rotate: true,
              markers: [
                ...warnings.map(
                  (warning) => Marker(
                    point: LatLng(warning.lat, warning.lon),
                    width: 36,
                    height: 36,
                    child: _WarningMarker(active: warning == activeWarning),
                  ),
                ),
                Marker(
                  point: currentLocation,
                  width: 64,
                  height: 64,
                  child: const _CurrentLocationMarker(),
                ),
                if (destination != null)
                  Marker(
                    point: LatLng(destination!.lat, destination!.lon),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on_rounded,
                        color: _guideOrange, size: 42),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceMapChrome extends StatelessWidget {
  const _GuidanceMapChrome();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.transparent,
            Colors.white.withValues(alpha: 0.50),
          ],
          stops: const [0, 0.22, 0.66, 1],
        ),
      ),
    );
  }
}

class _GuidanceTopPanel extends StatelessWidget {
  const _GuidanceTopPanel({
    required this.arrived,
    required this.activeWarning,
    required this.nextWarning,
    required this.progressM,
    required this.remainingDistanceM,
    required this.remainingTimeS,
    required this.pregnancyMode,
    required this.onExit,
  });

  final bool arrived;
  final RouteWarning? activeWarning;
  final RouteWarning? nextWarning;
  final double progressM;
  final double remainingDistanceM;
  final double remainingTimeS;
  final bool pregnancyMode;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final warning = activeWarning;
    final distanceToWarningM =
        warning == null ? null : warning.distanceAlongRouteM - progressM;
    final urgent = distanceToWarningM != null && distanceToWarningM <= 100;
    final title = pregnancyMode
        ? _titleFor(arrived, warning, distanceToWarningM)
        : arrived
            ? '목적지에 도착했어요'
            : '기본경로로 안내 중';
    final subtitle = pregnancyMode
        ? _subtitleFor(arrived, warning, nextWarning, progressM)
        : arrived
            ? '주행이 종료되었습니다'
            : '도착 시간이 가장 빠른 경로를 안내해요';

    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: arrived
                    ? const Color(0xFFE9F8EF)
                    : urgent
                        ? const Color(0xFFFFF0E3)
                        : palette.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                arrived
                    ? Icons.flag_rounded
                    : warning == null
                        ? pregnancyMode
                            ? Icons.favorite_rounded
                            : Icons.navigation_rounded
                        : Icons.speed_rounded,
                color: arrived
                    ? const Color(0xFF21A35B)
                    : urgent
                        ? _guideOrange
                        : palette.primary,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _guideInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _guideMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _TopMetric(
                          label: '남은거리',
                          value: _formatDistance(remainingDistanceM)),
                      const SizedBox(width: 10),
                      _TopMetric(
                          label: '도착까지',
                          value: _formatDuration(remainingTimeS)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '안내 종료',
              onPressed: onExit,
              icon: const Icon(Icons.close_rounded, color: _guideMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(
      bool arrived, RouteWarning? warning, double? distanceToWarningM) {
    if (arrived) {
      return '목적지에 도착했어요';
    }
    if (warning == null || distanceToWarningM == null) {
      return '안심 경로로 안내 중';
    }
    final roundedDistance = distanceToWarningM <= 100 ? 100 : 300;
    final target = warning.kind == 'continuous' ? '연속 방지턱 구간' : '방지턱';
    return '전방 ${roundedDistance}m $target';
  }

  String _subtitleFor(
    bool arrived,
    RouteWarning? warning,
    RouteWarning? nextWarning,
    double progressM,
  ) {
    if (arrived) {
      return '주행이 종료되었습니다';
    }
    if (warning != null) {
      return warning.kind == 'continuous'
          ? '속도를 낮추고 편안하게 통과하세요'
          : '충격을 줄이도록 천천히 진입하세요';
    }
    if (nextWarning == null) {
      return '남은 구간에 주요 방지턱 알림이 없어요';
    }
    final nextDistanceM =
        math.max(0.0, nextWarning.distanceAlongRouteM - progressM);
    return '다음 방지턱 알림 ${_formatDistance(nextDistanceM)} 앞';
  }
}

class _GuidanceBottomPanel extends StatelessWidget {
  const _GuidanceBottomPanel({
    required this.route,
    required this.destinationName,
    required this.remainingDistanceM,
    required this.remainingTimeS,
    required this.progressRatio,
    required this.paused,
    required this.arrived,
    required this.pregnancyMode,
    required this.onTogglePause,
    required this.onExit,
  });

  final CandidateRoute route;
  final String destinationName;
  final double remainingDistanceM;
  final double remainingTimeS;
  final double progressRatio;
  final bool paused;
  final bool arrived;
  final bool pregnancyMode;
  final VoidCallback onTogglePause;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          18, 14, 18, MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: _guideLine, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  pregnancyMode
                      ? Icons.health_and_safety_rounded
                      : Icons.navigation_rounded,
                  color: palette.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arrived
                          ? '안내 완료'
                          : pregnancyMode
                              ? '임산부 안심 주행'
                              : '기본경로 주행',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _guideInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      destinationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _guideMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _SimulationBadge(paused: paused, arrived: arrived),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 7,
              backgroundColor: _guideSoft,
              valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BottomMetric(
                  label: '남은거리',
                  value: _formatDistance(remainingDistanceM),
                ),
              ),
              Expanded(
                child: _BottomMetric(
                  label: '도착까지',
                  value: _formatDuration(remainingTimeS),
                ),
              ),
              Expanded(
                child: _BottomMetric(
                  label: pregnancyMode ? '방지턱' : '경로',
                  value: pregnancyMode ? '${route.bumpCount}개' : '기본',
                  accent: palette.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.dark,
                    side: BorderSide(color: palette.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: arrived ? null : onTogglePause,
                  icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  label: Text(paused ? '재개' : '일시정지'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onExit,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('안내 종료'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
        border: Border.all(color: palette.primary, width: 4),
      ),
      child: Center(
        child: Icon(
          Icons.navigation_rounded,
          color: palette.dark,
          size: 30,
        ),
      ),
    );
  }
}

class _CompassChip extends StatelessWidget {
  const _CompassChip({required this.headingDeg});

  final double headingDeg;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: mapRotationForHeading(headingDeg) * math.pi / 180,
              child: Icon(
                Icons.navigation_rounded,
                color: palette.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'SIM',
              style: TextStyle(
                color: _guideInk,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningMarker extends StatelessWidget {
  const _WarningMarker({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: active ? _guideOrange : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? Colors.white : palette.primary,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Icon(
        Icons.speed_rounded,
        color: active ? Colors.white : palette.dark,
        size: 19,
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  const _TopMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: _guideMuted, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
              color: _guideInk, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _BottomMetric extends StatelessWidget {
  const _BottomMetric({
    required this.label,
    required this.value,
    this.accent = _guideInk,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: _guideSoft, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: _guideMuted, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: accent, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SimulationBadge extends StatelessWidget {
  const _SimulationBadge({required this.paused, required this.arrived});

  final bool paused;
  final bool arrived;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final text = arrived
        ? '도착'
        : paused
            ? '일시정지'
            : '모의주행';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: arrived ? const Color(0xFFE9F8EF) : palette.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: arrived ? const Color(0xFF21A35B) : palette.dark,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _formatDistance(double meters) {
  final safeMeters = math.max(0.0, meters);
  if (safeMeters >= 1000) {
    return '${(safeMeters / 1000).toStringAsFixed(1)}km';
  }
  return '${safeMeters.round()}m';
}

String _formatDuration(double seconds) {
  final safeSeconds = math.max(0.0, seconds);
  final minutes = math.max(1, (safeSeconds / 60).ceil());
  return '$minutes분';
}
