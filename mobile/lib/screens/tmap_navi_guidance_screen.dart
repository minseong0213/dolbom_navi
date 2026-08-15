import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tmap_ui_sdk/auth/data/auth_data.dart';
import 'package:tmap_ui_sdk/auth/data/init_result.dart';
import 'package:tmap_ui_sdk/config/sdk_config.dart';
import 'package:tmap_ui_sdk/event/data/driveguide/tmap_driveguide.dart';
import 'package:tmap_ui_sdk/event/data/sdkStatus/tmap_sdk_status.dart';
import 'package:tmap_ui_sdk/route/data/planning_option.dart';
import 'package:tmap_ui_sdk/route/data/route_point.dart';
import 'package:tmap_ui_sdk/route/data/route_request_data.dart';
import 'package:tmap_ui_sdk/tmap_ui_sdk_manager.dart';
import 'package:tmap_ui_sdk/widget/tmap_view_widget.dart';

import '../models/route_models.dart';
import '../services/voice_alert_service.dart';
import '../theme/nav_mode_palette.dart';

const _tmapInk = Color(0xFF17171B);
const _tmapMuted = Color(0xFF8B8B94);
const _tmapLine = Color(0xFFECECF0);
const _tmapSoft = Color(0xFFF5F5F8);

class TmapNaviGuidanceScreen extends StatefulWidget {
  const TmapNaviGuidanceScreen({
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
  State<TmapNaviGuidanceScreen> createState() => _TmapNaviGuidanceScreenState();
}

class _TmapNaviGuidanceScreenState extends State<TmapNaviGuidanceScreen> {
  static const _clientApiKey = String.fromEnvironment('TMAP_NAVI_API_KEY');
  static const _legacyApiKey = String.fromEnvironment('TMAP_API_KEY');
  static const _clientId = String.fromEnvironment('TMAP_CLIENT_ID');
  static const _clientApCode = String.fromEnvironment('TMAP_AP_CODE');
  static const _userKey = String.fromEnvironment('TMAP_USER_KEY');
  static const _deviceKey = String.fromEnvironment('TMAP_DEVICE_KEY');

  bool _initializing = true;
  bool _ready = false;
  String _statusText = 'SDK 초기화 중';
  String? _error;
  TmapDriveGuide? _driveGuide;
  late final VoiceAlertService _voiceAlertService;
  late final RouteVoiceAlertController _voiceAlertController;

  String get _apiKey =>
      _clientApiKey.isNotEmpty ? _clientApiKey : _legacyApiKey;

  @override
  void initState() {
    super.initState();
    _voiceAlertService = VoiceAlertService();
    _voiceAlertController = RouteVoiceAlertController(
      warnings: widget.route.warnings,
      speak: _voiceAlertService.speak,
      enabled: widget.pregnancyMode,
    );
    unawaited(_prepareVoiceAlerts());
    _prepareSdk();
  }

  @override
  void dispose() {
    TmapUISDKManager().stopTmapSDKStatusStream();
    TmapUISDKManager().stopTmapDriveGuideStream();
    unawaited(_voiceAlertService.dispose());
    super.dispose();
  }

  Future<void> _prepareVoiceAlerts() async {
    if (!widget.pregnancyMode) {
      return;
    }
    try {
      await _voiceAlertService.initialize();
    } catch (_) {
      // TMAP guidance remains usable if Korean TTS is unavailable.
    }
  }

  Future<void> _prepareSdk() async {
    if (_apiKey.isEmpty) {
      setState(() {
        _initializing = false;
        _error = 'TMAP Navi SDK 키가 필요합니다.';
      });
      return;
    }

    final permission = await Permission.location.request();
    if (!permission.isGranted) {
      setState(() {
        _initializing = false;
        _error = '위치 권한을 허용해야 TMAP 길안내를 시작할 수 있습니다.';
      });
      return;
    }

    try {
      await TmapUISDKManager().startTmapSDKStatusStream(_onSdkStatus);
      await TmapUISDKManager().startTmapDriveGuideStream(_onDriveGuide);

      final result = await TmapUISDKManager().initSDK(
        AuthData(
          clientServiceName: 'pregnant_nav',
          clientAppVersion: '0.1.0',
          clientID: _clientId,
          clientApiKey: _apiKey,
          clientApCode: _clientApCode,
          userKey: _userKey,
          deviceKey: _deviceKey,
          isAvailableInBackground: false,
        ),
      );

      if (result != InitResult.granted) {
        setState(() {
          _initializing = false;
          _error = 'TMAP Navi SDK 인증에 실패했습니다.';
          _statusText = result?.text ?? 'notGranted';
        });
        return;
      }

      await TmapUISDKManager().setConfigSDK(
        SDKConfig(
          carType: UISDKCarModel.normal,
          fuelType: UISDKFuel.gas,
          showTrafficAccident: true,
          mapTextSize: UISDKMapFontSize.medium,
          nightMode: UISDKAutoNightModeType.auto,
          isUseSpeedReactMapScale: true,
          isShowTrafficInRoute: true,
          isShowExitPopupWhenStopDriving: true,
          useRealTimeAutoReroute: true,
          suspendInBackground: true,
        ),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _ready = true;
        _statusText = 'SDK 준비 완료';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _error = 'TMAP Navi SDK 초기화 실패: $error';
      });
    }
  }

  void _onSdkStatus(TmapSDKStatusMsg status) {
    if (!mounted) {
      return;
    }

    if (status.sdkStatus == TmapSDKStatus.dismissReq ||
        status.sdkStatus == TmapSDKStatus.finished) {
      final extraData = status.extraData.trim();
      if (extraData == '429') {
        setState(() {
          _ready = false;
          _initializing = false;
          _statusText = 'TMAP 요청 제한';
          _error =
              'TMAP 요청 제한(429)이 발생했어요. 잠시 후 다시 시도하거나 TMAP 대시보드에서 Navi SDK 사용량을 확인해 주세요.';
        });
        return;
      }
      widget.onExit();
      return;
    }

    setState(() {
      _statusText = status.sdkStatus?.text ?? 'unknown';
    });
  }

  void _onDriveGuide(TmapDriveGuide guide) {
    if (!mounted) {
      return;
    }
    setState(() => _driveGuide = guide);
    final drivenM = math.max(
      0.0,
      widget.route.summary.totalDistanceM -
          guide.remainDistanceToDestinationInMeter,
    );
    unawaited(_voiceAlertController.updateProgress(drivenM));
  }

  Future<void> _stopAndExit() async {
    await TmapUISDKManager().stopDriving();
    if (mounted) {
      widget.onExit();
    }
  }

  RouteRequestData _routeRequestData() {
    return RouteRequestData(
      source: _toRoutePoint(widget.origin),
      destination: _toRoutePoint(widget.destination),
      routeOption: _planningOptionsFor(widget.route.searchOption),
      guideWithoutPreview: true,
    );
  }

  RoutePoint? _toRoutePoint(Coordinate? coordinate) {
    if (coordinate == null) {
      return null;
    }
    return RoutePoint(
      latitude: coordinate.lat,
      longitude: coordinate.lon,
      name: coordinate.name ?? '',
    );
  }

  List<PlanningOption> _planningOptionsFor(int searchOption) {
    switch (searchOption) {
      case 1:
        return [PlanningOption.free];
      case 2:
        return [PlanningOption.minTime];
      case 3:
        return [PlanningOption.firstTime];
      case 4:
        return [PlanningOption.highway];
      case 10:
        return [PlanningOption.shortest];
      case 12:
        return [PlanningOption.generalRoad];
      case 19:
        return [PlanningOption.avoidSchoolZone];
      default:
        return [PlanningOption.recommend];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildSdkBody()),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 14,
          right: 14,
          child: _TmapTopOverlay(
            statusText: _statusText,
            driveGuide: _driveGuide,
            route: widget.route,
            pregnancyMode: widget.pregnancyMode,
            onExit: _stopAndExit,
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
          child: _TmapBottomOverlay(
            route: widget.route,
            destinationName: widget.destination?.name ?? '목적지',
            driveGuide: _driveGuide,
            pregnancyMode: widget.pregnancyMode,
          ),
        ),
      ],
    );
  }

  Widget _buildSdkBody() {
    final palette = NavModePalette.of(context);
    if (_ready) {
      return TmapViewWidget(data: _routeRequestData());
    }

    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_initializing)
                CircularProgressIndicator(color: palette.primary)
              else
                Icon(Icons.error_rounded, color: palette.primary, size: 42),
              const SizedBox(height: 16),
              Text(
                _error ?? _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _tmapInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed:
                      _error!.contains('권한') ? openAppSettings : _prepareSdk,
                  child: Text(_error!.contains('권한') ? '설정 열기' : '다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TmapTopOverlay extends StatelessWidget {
  const _TmapTopOverlay({
    required this.statusText,
    required this.driveGuide,
    required this.route,
    required this.pregnancyMode,
    required this.onExit,
  });

  final String statusText;
  final TmapDriveGuide? driveGuide;
  final CandidateRoute route;
  final bool pregnancyMode;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final guide = driveGuide;
    final distance = guide == null
        ? route.summary.totalDistanceM
        : guide.remainDistanceToDestinationInMeter.toDouble();
    final seconds = guide == null
        ? route.summary.totalTimeS
        : guide.remainTimeToDestinationInSec.toDouble();

    return Material(
      color: Colors.white,
      elevation: 6,
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
                color: palette.soft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.navigation_rounded,
                  color: palette.primary, size: 27),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pregnancyMode ? 'TMAP 안심 안내' : 'TMAP 기본경로 안내',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _tmapInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    guide?.currentRoadName.isNotEmpty == true
                        ? guide!.currentRoadName
                        : statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _tmapMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _OverlayMetric(
                          label: '남은거리', value: _formatDistance(distance)),
                      const SizedBox(width: 10),
                      _OverlayMetric(
                          label: '도착까지', value: _formatDuration(seconds)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '안내 종료',
              onPressed: onExit,
              icon: const Icon(Icons.close_rounded, color: _tmapMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TmapBottomOverlay extends StatelessWidget {
  const _TmapBottomOverlay({
    required this.route,
    required this.destinationName,
    required this.driveGuide,
    required this.pregnancyMode,
  });

  final CandidateRoute route;
  final String destinationName;
  final TmapDriveGuide? driveGuide;
  final bool pregnancyMode;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final nextDistance =
        pregnancyMode ? _nextWarningDistance(route, driveGuide) : null;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    pregnancyMode
                        ? Icons.health_and_safety_rounded
                        : Icons.navigation_rounded,
                    color: palette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pregnancyMode ? '안심경로 선택' : '기본경로 선택',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.dark,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        destinationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _tmapMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _Pill(
                    label: '3D 안내',
                    color: palette.primary,
                    textColor: Colors.white),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    label: pregnancyMode ? '방지턱' : '경로',
                    value: pregnancyMode ? '${route.bumpCount}개' : '최속',
                    accent: palette.dark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoTile(
                    label: pregnancyMode ? '알림' : '경로 유형',
                    value: pregnancyMode ? '${route.warnings.length}개' : '기본',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoTile(
                    label: pregnancyMode ? '다음 알림' : '안내',
                    value: pregnancyMode
                        ? nextDistance == null
                            ? '없음'
                            : _formatDistance(nextDistance)
                        : '3D',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double? _nextWarningDistance(CandidateRoute route, TmapDriveGuide? guide) {
    if (route.warnings.isEmpty) {
      return null;
    }
    if (guide == null || guide.remainDistanceToDestinationInMeter <= 0) {
      return route.warnings.first.distanceAlongRouteM;
    }

    final drivenM = math.max(
      0.0,
      route.summary.totalDistanceM - guide.remainDistanceToDestinationInMeter,
    );
    for (final warning in route.warnings) {
      final remaining = warning.distanceAlongRouteM - drivenM;
      if (remaining >= 0) {
        return remaining;
      }
    }
    return null;
  }
}

class _OverlayMetric extends StatelessWidget {
  const _OverlayMetric({required this.label, required this.value});

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
              color: _tmapMuted, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
              color: _tmapInk, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.accent = _tmapInk,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: _tmapSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tmapLine),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
                color: _tmapMuted, fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: accent, fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(
            color: textColor, fontSize: 11, fontWeight: FontWeight.w900),
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
