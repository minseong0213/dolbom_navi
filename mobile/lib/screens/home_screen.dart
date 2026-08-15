import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_models.dart';
import '../services/api_client.dart';
import '../services/current_location_service.dart';
import '../theme/nav_mode_palette.dart';
import 'drive_test_screen.dart';
import 'guidance_screen.dart';
import 'tmap_navi_guidance_screen.dart';

enum _PlaceTarget { origin, destination }

const _emergency = Color(0xFFE5325C);
const _ink = Color(0xFF17171B);
const _muted = Color(0xFF8B8B94);
const _line = Color(0xFFECECF0);
const _soft = Color(0xFFF5F5F8);
const _useTmapNaviSdk = bool.fromEnvironment('USE_TMAP_NAVI_SDK');
const _showDriveRecordTab = bool.fromEnvironment(
  'SHOW_DRIVE_RECORD_TAB',
  defaultValue: true,
);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.autoLocateOrigin = true,
  });

  final bool autoLocateOrigin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiClient = ApiClient();
  final _currentLocationService = const CurrentLocationService();
  final _mapController = MapController();
  final _initialCenter = const LatLng(37.50648437, 126.72126839);
  static const _defaultOrigin = Place(
    name: '부평구청',
    address: '인천 부평구 부평동',
    lat: 37.5064566,
    lon: 126.72160169,
    category: '행정기관',
  );

  Place? _origin;
  Place? _destination;
  bool _loading = false;
  String? _error;
  List<CandidateRoute> _routes = [];
  CandidateRoute? _selectedRoute;
  CandidateRoute? _guidanceRoute;
  bool _locatingOrigin = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoLocateOrigin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _useCurrentLocation(automatic: true);
      });
    }
  }

  Future<void> _useCurrentLocation({bool automatic = false}) async {
    if (_locatingOrigin) {
      return;
    }
    setState(() => _locatingOrigin = true);

    try {
      final currentPlace = await _currentLocationService.getCurrentPlace();
      if (!mounted || (automatic && _origin != null)) {
        return;
      }
      setState(() {
        _origin = currentPlace;
        _routes = [];
        _selectedRoute = null;
        _guidanceRoute = null;
        _error = null;
      });
      _moveToSelectedPlaces();
    } on CurrentLocationException catch (error) {
      debugPrint('Current location unavailable: $error');
      if (!automatic && mounted) {
        _showLocationError(error);
      }
    } catch (error) {
      debugPrint('Current location failed: $error');
      if (!automatic && mounted) {
        _showLocationError(
          const CurrentLocationException('현재 위치를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locatingOrigin = false);
      }
    }
  }

  void _showLocationError(CurrentLocationException error) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message),
        action: error.openSettings
            ? SnackBarAction(
                label: '설정',
                onPressed: _currentLocationService.openRelevantSettings,
              )
            : null,
      ),
    );
  }

  Future<void> _pickPlace(_PlaceTarget target) async {
    final selected = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        const palette = NavModePalette.pregnancy;
        final baseTheme = Theme.of(context);
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: baseTheme.colorScheme.copyWith(
              primary: palette.primary,
              primaryContainer: palette.soft,
            ),
            extensions: <ThemeExtension<dynamic>>[palette],
          ),
          child: _PlaceSearchSheet(
            apiClient: _apiClient,
            title: target == _PlaceTarget.origin ? '출발지 검색' : '도착지 검색',
            hintText: target == _PlaceTarget.origin ? '예: 부평구청' : '예: 삼산 엠코타운',
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      if (target == _PlaceTarget.origin) {
        _origin = selected;
      } else {
        _destination = selected;
      }
      _routes = [];
      _selectedRoute = null;
      _guidanceRoute = null;
      _error = null;
      _tabIndex = 0;
    });
    _moveToSelectedPlaces();
  }

  Future<void> _loadRoutes() async {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
      setState(() => _error = '출발지와 도착지를 모두 선택해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _tabIndex = 0;
    });

    try {
      final response = await _apiClient.recommendRoutes(
        origin: origin.toCoordinate(),
        destination: destination.toCoordinate(),
      );
      final selectedRoute = _routeById(
        response.candidates,
        response.recommendedRouteId,
      );
      setState(() {
        _routes = response.candidates;
        _selectedRoute = selectedRoute;
      });
      _fitSelectedRoute();
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  CandidateRoute? _routeById(
    List<CandidateRoute> routes,
    String? routeId,
  ) {
    if (routes.isEmpty) {
      return null;
    }
    for (final route in routes) {
      if (route.id == routeId) {
        return route;
      }
    }
    return routes.first;
  }

  CandidateRoute? get _safeRoute {
    if (_routes.isEmpty) {
      return null;
    }
    return _routes.firstWhere(
      (route) => route.rank == 1,
      orElse: () => _routes.first,
    );
  }

  bool _isSafeRoute(CandidateRoute? route) {
    final safeRoute = _safeRoute;
    return route == null || safeRoute == null || route.id == safeRoute.id;
  }

  void _selectRoute(CandidateRoute route) {
    setState(() => _selectedRoute = route);
    _fitSelectedRoute();
  }

  void _clearRoute() {
    setState(() {
      _routes = [];
      _selectedRoute = null;
      _guidanceRoute = null;
      _error = null;
    });
    _moveToSelectedPlaces();
  }

  void _quickRecommendTo(Place destination) {
    setState(() {
      _origin ??= _defaultOrigin;
      _destination = destination;
      _routes = [];
      _selectedRoute = null;
      _guidanceRoute = null;
      _error = null;
      _tabIndex = 0;
    });
    _moveToSelectedPlaces();
    _loadRoutes();
  }

  void _startGuidance() {
    final route = _selectedRoute;
    if (route == null) {
      return;
    }
    setState(() => _guidanceRoute = route);
  }

  void _endGuidance() {
    setState(() => _guidanceRoute = null);
    _fitSelectedRoute();
  }

  void _moveToSelectedPlaces() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final points = [
        if (_origin != null) LatLng(_origin!.lat, _origin!.lon),
        if (_destination != null) LatLng(_destination!.lat, _destination!.lon),
      ];
      if (points.length >= 2) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(42, 160, 42, 300),
          ),
        );
      } else if (points.length == 1) {
        _mapController.move(points.first, 15);
      }
    });
  }

  void _fitSelectedRoute() {
    final route = _selectedRoute;
    if (route == null || route.polyline.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final points =
          route.polyline.map((item) => LatLng(item.lat, item.lon)).toList();
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(42, 145, 42, 430),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final guidanceRoute = _guidanceRoute;
    final safeRouteSelected = _isSafeRoute(guidanceRoute ?? _selectedRoute);
    final palette =
        safeRouteSelected ? NavModePalette.pregnancy : NavModePalette.general;
    final parentTheme = Theme.of(context);
    final useTmapNavi = _useTmapNaviSdk &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return Theme(
      data: parentTheme.copyWith(
        colorScheme: parentTheme.colorScheme.copyWith(
          primary: palette.primary,
          primaryContainer: palette.soft,
        ),
        extensions: <ThemeExtension<dynamic>>[palette],
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F4),
        body: Center(
          child: _PhoneFrame(
            child: guidanceRoute == null
                ? IndexedStack(
                    index: _tabIndex,
                    children: [
                      _MapShell(
                        mapController: _mapController,
                        initialCenter: _initialCenter,
                        origin: _origin,
                        destination: _destination,
                        selectedRoute: _selectedRoute,
                        routes: _routes,
                        loading: _loading,
                        error: _error,
                        locatingOrigin: _locatingOrigin,
                        safeRouteSelected: safeRouteSelected,
                        onPickOrigin: () => _pickPlace(_PlaceTarget.origin),
                        onUseCurrentLocation: _useCurrentLocation,
                        onPickDestination: () =>
                            _pickPlace(_PlaceTarget.destination),
                        onRecommend: _loadRoutes,
                        onSelectRoute: _selectRoute,
                        onBackToHome: _clearRoute,
                        onStartGuidance: _startGuidance,
                        onQuickRecommendTo: _quickRecommendTo,
                        onChangeTab: (index) =>
                            setState(() => _tabIndex = index),
                      ),
                      _SimpleTabScreen(
                        title: '주변 안심 정보',
                        subtitle: '주변 병원, 약국, 휴게 가능한 장소를 모아 보여줄 예정이에요.',
                        selectedIndex: _tabIndex,
                        onChangeTab: (index) =>
                            setState(() => _tabIndex = index),
                      ),
                      _EmergencyScreen(
                        selectedIndex: _tabIndex,
                        onChangeTab: (index) =>
                            setState(() => _tabIndex = index),
                      ),
                      if (_showDriveRecordTab)
                        DriveTestScreen(
                          onExit: () => setState(() => _tabIndex = 0),
                        ),
                    ],
                  )
                : useTmapNavi
                    ? TmapNaviGuidanceScreen(
                        route: guidanceRoute,
                        origin: _origin?.toCoordinate(),
                        destination: _destination?.toCoordinate(),
                        pregnancyMode: safeRouteSelected,
                        onExit: _endGuidance,
                      )
                    : GuidanceScreen(
                        route: guidanceRoute,
                        origin: _origin?.toCoordinate(),
                        destination: _destination?.toCoordinate(),
                        pregnancyMode: safeRouteSelected,
                        onExit: _endGuidance,
                      ),
          ),
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usePhoneFrame = constraints.maxWidth > 520;
        return Container(
          width: usePhoneFrame ? 390 : constraints.maxWidth,
          height: constraints.maxHeight,
          decoration: usePhoneFrame
              ? BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 32,
                      offset: Offset(0, 8),
                    ),
                  ],
                )
              : null,
          clipBehavior: usePhoneFrame ? Clip.antiAlias : Clip.none,
          child: child,
        );
      },
    );
  }
}

class _MapShell extends StatelessWidget {
  const _MapShell({
    required this.mapController,
    required this.initialCenter,
    required this.origin,
    required this.destination,
    required this.selectedRoute,
    required this.routes,
    required this.loading,
    required this.error,
    required this.locatingOrigin,
    required this.safeRouteSelected,
    required this.onPickOrigin,
    required this.onUseCurrentLocation,
    required this.onPickDestination,
    required this.onRecommend,
    required this.onSelectRoute,
    required this.onBackToHome,
    required this.onStartGuidance,
    required this.onQuickRecommendTo,
    required this.onChangeTab,
  });

  final MapController mapController;
  final LatLng initialCenter;
  final Place? origin;
  final Place? destination;
  final CandidateRoute? selectedRoute;
  final List<CandidateRoute> routes;
  final bool loading;
  final String? error;
  final bool locatingOrigin;
  final bool safeRouteSelected;
  final VoidCallback onPickOrigin;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickDestination;
  final VoidCallback onRecommend;
  final ValueChanged<CandidateRoute> onSelectRoute;
  final VoidCallback onBackToHome;
  final VoidCallback onStartGuidance;
  final ValueChanged<Place> onQuickRecommendTo;
  final ValueChanged<int> onChangeTab;

  bool get _hasRoutes => routes.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final routePoints = selectedRoute?.polyline
            .map((point) => LatLng(point.lat, point.lon))
            .toList() ??
        const <LatLng>[];

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(initialCenter: initialCenter, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.pregnantnav.mvp',
            ),
            if (routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    color: palette.primary,
                    strokeWidth: 8,
                  ),
                  Polyline(
                    points: routePoints,
                    color: Colors.white.withValues(alpha: 0.72),
                    strokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (origin != null)
                  Marker(
                    point: LatLng(origin!.lat, origin!.lon),
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.trip_origin_rounded,
                      color: palette.dark,
                    ),
                  ),
                if (destination != null)
                  Marker(
                    point: LatLng(destination!.lat, destination!.lon),
                    width: 42,
                    height: 42,
                    child: const Icon(Icons.location_on_rounded,
                        color: Color(0xFFFF8A3D)),
                  ),
              ],
            ),
          ],
        ),
        if (_hasRoutes)
          Positioned(
            top: MediaQuery.of(context).padding.top + 22,
            left: 16,
            right: 16,
            child: _RouteHeader(
              origin: origin,
              destination: destination,
              safeRouteSelected: safeRouteSelected,
              onBack: onBackToHome,
            ),
          )
        else
          Positioned(
            top: MediaQuery.of(context).padding.top + 22,
            left: 16,
            right: 16,
            child: _HomeSearchCard(
              origin: origin,
              destination: destination,
              loading: loading,
              locatingOrigin: locatingOrigin,
              onPickOrigin: onPickOrigin,
              onUseCurrentLocation: onUseCurrentLocation,
              onPickDestination: onPickDestination,
              onRecommend: onRecommend,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _hasRoutes
              ? _RouteCompareSheet(
                  routes: routes,
                  selectedRoute: selectedRoute,
                  error: error,
                  safeRouteSelected: safeRouteSelected,
                  onSelectRoute: onSelectRoute,
                  onStartGuidance: onStartGuidance,
                )
              : _HomeBottomSheet(
                  error: error,
                  loading: loading,
                  onPickDestination: onPickDestination,
                  onQuickRecommendTo: onQuickRecommendTo,
                  onChangeTab: onChangeTab,
                ),
        ),
      ],
    );
  }
}

class _HomeSearchCard extends StatelessWidget {
  const _HomeSearchCard({
    required this.origin,
    required this.destination,
    required this.loading,
    required this.locatingOrigin,
    required this.onPickOrigin,
    required this.onUseCurrentLocation,
    required this.onPickDestination,
    required this.onRecommend,
  });

  final Place? origin;
  final Place? destination;
  final bool loading;
  final bool locatingOrigin;
  final VoidCallback onPickOrigin;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onPickDestination;
  final VoidCallback onRecommend;

  bool get _canRecommend => origin != null && destination != null && !loading;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  color: palette.primary,
                  size: 19,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '돌봄 내비게이션',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _PlaceField(
              icon: Icons.trip_origin_rounded,
              iconColor: palette.dark,
              label: '출발',
              value: locatingOrigin ? '현재 위치 확인 중...' : origin?.name,
              placeholder: '현재 위치 또는 출발지 검색',
              onTap: onPickOrigin,
              trailingIcon: Icons.my_location_rounded,
              trailingTooltip: '현재 위치 사용',
              trailingLoading: locatingOrigin,
              onTrailingTap: onUseCurrentLocation,
            ),
            const SizedBox(height: 6),
            _PlaceField(
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFFF8A3D),
              label: '도착',
              value: destination?.name,
              placeholder: '어디로 갈까요?',
              onTap: onPickDestination,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.primary,
                  disabledBackgroundColor: const Color(0xFFE4E4EA),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _canRecommend ? onRecommend : null,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route_rounded, size: 18),
                label: const Text(
                  '안심경로 추천',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.trailingIcon = Icons.search_rounded,
    this.trailingTooltip,
    this.trailingLoading = false,
    this.onTrailingTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final String? trailingTooltip;
  final bool trailingLoading;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              SizedBox(
                width: 34,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value == null ? _muted : _ink,
                    fontSize: 14,
                    fontWeight:
                        value == null ? FontWeight.w500 : FontWeight.w800,
                  ),
                ),
              ),
              if (trailingLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onTrailingTap != null)
                IconButton(
                  tooltip: trailingTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  onPressed: onTrailingTap,
                  icon: Icon(trailingIcon, color: iconColor, size: 20),
                )
              else
                Icon(trailingIcon, color: _muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBottomSheet extends StatelessWidget {
  const _HomeBottomSheet({
    required this.error,
    required this.loading,
    required this.onPickDestination,
    required this.onQuickRecommendTo,
    required this.onChangeTab,
  });

  final String? error;
  final bool loading;
  final VoidCallback onPickDestination;
  final ValueChanged<Place> onQuickRecommendTo;
  final ValueChanged<int> onChangeTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _Handle()),
          const SizedBox(height: 14),
          if (error != null) _ErrorBanner(error: error!),
          _ModeBanner(onTap: onPickDestination),
          const SizedBox(height: 14),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MiniChip(label: '집', icon: Icons.home_rounded),
                SizedBox(width: 8),
                _MiniChip(
                    label: '연세산부인과',
                    icon: Icons.local_hospital_rounded,
                    active: true),
                SizedBox(width: 8),
                _MiniChip(label: '검진 병원', icon: Icons.star_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '최근 목적지',
            style: TextStyle(
                color: _ink, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _RecentRow(
            title: '연세산부인과',
            subtitle: '공항대로 260 · 6.2km',
            onTap: () => onQuickRecommendTo(
              const Place(
                name: '연세산부인과',
                address: '공항대로 260',
                lat: 37.558934,
                lon: 126.833185,
                category: '병원',
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RecentRow(
            title: '부평삼산엠코타운',
            subtitle: '인천 부평구 삼산동 · 바로 추천',
            onTap: () => onQuickRecommendTo(
              const Place(
                name: '부평삼산엠코타운아파트',
                address: '인천 부평구 삼산동',
                lat: 37.52053851,
                lon: 126.73362798,
                category: '주요건물',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BottomNav(selectedIndex: 0, onChange: onChangeTab),
        ],
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: palette.soft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: palette.primary,
              child: const Icon(
                Icons.favorite_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안심경로를 먼저 추천해요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: palette.dark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    '방지턱·급경사를 피한 경로를 우선 안내해요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.origin,
    required this.destination,
    required this.safeRouteSelected,
    required this.onBack,
  });

  final Place? origin;
  final Place? destination;
  final bool safeRouteSelected;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final title = '${origin?.name ?? '출발지'} → ${destination?.name ?? '도착지'}';
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            IconButton(
              tooltip: '홈으로',
              visualDensity: VisualDensity.compact,
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
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
                        color: _ink, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    safeRouteSelected ? '안심경로 선택' : '기본경로 선택',
                    style: TextStyle(
                        color: palette.dark,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: palette.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    safeRouteSelected
                        ? Icons.health_and_safety_rounded
                        : Icons.navigation_rounded,
                    size: 15,
                    color: palette.dark,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    safeRouteSelected ? '안심' : '기본',
                    style: TextStyle(
                      color: palette.dark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCompareSheet extends StatelessWidget {
  const _RouteCompareSheet({
    required this.routes,
    required this.selectedRoute,
    required this.error,
    required this.safeRouteSelected,
    required this.onSelectRoute,
    required this.onStartGuidance,
  });

  final List<CandidateRoute> routes;
  final CandidateRoute? selectedRoute;
  final String? error;
  final bool safeRouteSelected;
  final ValueChanged<CandidateRoute> onSelectRoute;
  final VoidCallback onStartGuidance;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final safeRoute = routes.firstWhere(
      (route) => route.rank == 1,
      orElse: () => routes.first,
    );
    final normalRoute = routes.reduce(
      (current, route) => route.summary.totalTimeS < current.summary.totalTimeS
          ? route
          : current,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
          const _Handle(),
          const SizedBox(height: 10),
          if (error != null) _ErrorBanner(error: error!),
          _RouteChoiceCard(
            route: safeRoute,
            selected: selectedRoute?.id == safeRoute.id,
            routeType: '안심경로',
            description: '저충격 우선 추천',
            icon: Icons.health_and_safety_rounded,
            accent: NavModePalette.pregnancy.primary,
            chips: [
              '방지턱 ${safeRoute.bumpCount}개',
              '안심점수 ${safeRoute.score.round()}점'
            ],
            onTap: () => onSelectRoute(safeRoute),
          ),
          const SizedBox(height: 10),
          if (normalRoute.id != safeRoute.id)
            _RouteChoiceCard(
              route: normalRoute,
              selected: selectedRoute?.id == normalRoute.id,
              routeType: '기본경로',
              description: '도착시간 우선',
              icon: Icons.navigation_rounded,
              accent: NavModePalette.general.primary,
              chips: [
                '방지턱 ${normalRoute.bumpCount}개',
                '안심점수 ${normalRoute.score.round()}점'
              ],
              onTap: () => onSelectRoute(normalRoute),
            ),
          const SizedBox(height: 10),
          _InsightPill(
            safeRoute: safeRoute,
            normalRoute: normalRoute,
            safeRouteSelected: safeRouteSelected,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 51,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.28),
              ),
              onPressed: onStartGuidance,
              child: Text(
                safeRouteSelected ? '안심경로로 안내 시작' : '기본경로로 안내 시작',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChoiceCard extends StatelessWidget {
  const _RouteChoiceCard({
    required this.route,
    required this.selected,
    required this.routeType,
    required this.description,
    required this.icon,
    required this.accent,
    required this.chips,
    required this.onTap,
  });

  final CandidateRoute route;
  final bool selected;
  final String routeType;
  final String description;
  final IconData icon;
  final Color accent;
  final List<String> chips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutes = (route.summary.totalTimeS / 60).round();
    final km = route.summary.totalDistanceM / 1000;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.09) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? accent : _line, width: selected ? 2 : 1),
          boxShadow: selected
              ? const [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4)),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? accent : accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.white : accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              routeType,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? accent : _ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (routeType == '안심경로') ...[
                            const SizedBox(width: 6),
                            _LabelChip(
                              label: '추천',
                              color: accent,
                              textColor: Colors.white,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$minutes분',
                      style: TextStyle(
                        color: selected ? accent : _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${km.toStringAsFixed(1)}km',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: accent,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chips.map((chip) {
                final isBump = chip.startsWith('방지턱');
                return _LabelChip(
                  label: chip,
                  color: selected
                      ? Colors.white
                      : (isBump ? const Color(0xFFFFF1E7) : _soft),
                  textColor: selected && isBump
                      ? accent
                      : (isBump ? const Color(0xFFFF8A3D) : _muted),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({
    required this.safeRoute,
    required this.normalRoute,
    required this.safeRouteSelected,
  });

  final CandidateRoute safeRoute;
  final CandidateRoute normalRoute;
  final bool safeRouteSelected;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final safeScore = safeRoute.score.round();
    final normalScore = normalRoute.score.round();
    final avoidedBumps = normalRoute.bumpCount - safeRoute.bumpCount;
    final addedMinutes =
        ((safeRoute.summary.totalTimeS - normalRoute.summary.totalTimeS) / 60)
            .ceil();
    final text = safeRouteSelected
        ? safeRoute.id == normalRoute.id
            ? '안심경로와 기본경로가 동일해요'
            : avoidedBumps > 0 && addedMinutes > 0
                ? '안심 점수 $safeScore점 vs $normalScore점 · +$addedMinutes분, 방지턱 $avoidedBumps개 감소'
                : '안심 점수 $safeScore점 vs $normalScore점'
        : safeRoute.id == normalRoute.id
            ? '현재 경로가 기본경로와 동일해요'
            : '기본경로 선택 · 안심경로는 ${addedMinutes > 0 ? '+$addedMinutes분' : '비슷한 시간'}';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: palette.soft, borderRadius: BorderRadius.circular(12)),
        child: Text(
          text,
          style: TextStyle(
              color: palette.dark, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _EmergencyScreen extends StatelessWidget {
  const _EmergencyScreen({
    required this.selectedIndex,
    required this.onChangeTab,
  });

  final int selectedIndex;
  final ValueChanged<int> onChangeTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                22, MediaQuery.of(context).padding.top + 28, 22, 22),
            color: _emergency,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '응급 모드',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  '침착하세요. 분만 가능한 가장 가까운 병원으로 안내할게요.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 51,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD01F49),
                        side: const BorderSide(color: _emergency, width: 1.5),
                        backgroundColor: const Color(0xFFFDE8EE),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.call_rounded),
                      label: const Text(
                        '119 바로 연결',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '분만 가능 · 가까운 순',
                    style: TextStyle(
                        color: _ink, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const _HospitalCard(
                    title: '이대서울병원',
                    subtitle: '3.1km · 9분 · 분만실 운영',
                    highlighted: true,
                  ),
                  const SizedBox(height: 12),
                  const _HospitalCard(
                    title: '부천성모병원',
                    subtitle: '4.8km · 13분 · 분만실 운영',
                  ),
                  const SizedBox(height: 12),
                  const _HospitalCard(
                    title: '연세산부인과',
                    subtitle: '6.2km · 17분 · 야간 휴진',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: _soft, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '보호자에게 위치 공유',
                                style: TextStyle(
                                    color: _ink,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '응급 모드 시작 시 자동 문자 발송',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: true,
                          onChanged: (_) {},
                          activeThumbColor: const Color(0xFF21B573),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _emergency,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {},
                      child: const Text(
                        '이대서울병원으로 안내 시작',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomNav(selectedIndex: selectedIndex, onChange: onChangeTab),
        ],
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  const _HospitalCard({
    required this.title,
    required this.subtitle,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFDE8EE) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: highlighted ? _emergency : _line,
            width: highlighted ? 2 : 1),
        boxShadow: highlighted
            ? const [
                BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4))
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (highlighted) ...[
                      const SizedBox(width: 6),
                      const _LabelChip(
                          label: '가장 가까움',
                          color: _emergency,
                          textColor: Colors.white),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _LabelChip(
            label: '안내',
            color: highlighted ? _emergency : _soft,
            textColor: highlighted ? Colors.white : _muted,
            horizontalPadding: 14,
            verticalPadding: 8,
          ),
        ],
      ),
    );
  }
}

class _SimpleTabScreen extends StatelessWidget {
  const _SimpleTabScreen({
    required this.title,
    required this.subtitle,
    required this.selectedIndex,
    required this.onChangeTab,
  });

  final String title;
  final String subtitle;
  final int selectedIndex;
  final ValueChanged<int> onChangeTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  22, MediaQuery.of(context).padding.top + 32, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        color: _ink, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: _muted, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: _soft, borderRadius: BorderRadius.circular(18)),
                    child: const Text(
                      '디자인 확정 후 상세 기능을 연결합니다.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomNav(selectedIndex: selectedIndex, onChange: onChangeTab),
        ],
      ),
    );
  }
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({
    required this.apiClient,
    required this.title,
    required this.hintText,
  });

  final ApiClient apiClient;
  final String title;
  final String hintText;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Place> _places = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() => _error = '두 글자 이상 입력해 주세요.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final places = await widget.apiClient.searchPlaces(query);
      setState(() {
        _places = places;
        if (places.isEmpty) {
          _error = '검색 결과가 없습니다.';
        }
      });
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _Handle()),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: '검색',
                      onPressed: _loading ? null : _search,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: palette.primary,
                        width: 1.5,
                      ),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _emergency, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _places.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.place_rounded,
                          color: palette.primary,
                        ),
                        title: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _ink, fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, place),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onChange,
  });

  final int selectedIndex;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
              index: 0,
              selectedIndex: selectedIndex,
              icon: Icons.circle,
              label: '홈',
              onChange: onChange),
          _NavItem(
              index: 1,
              selectedIndex: selectedIndex,
              icon: Icons.circle,
              label: '주변',
              onChange: onChange),
          _NavItem(
              index: 2,
              selectedIndex: selectedIndex,
              icon: Icons.circle,
              label: '응급',
              onChange: onChange),
          if (_showDriveRecordTab)
            _NavItem(
                index: 3,
                selectedIndex: selectedIndex,
                icon: Icons.monitor_heart_rounded,
                label: '기록',
                onChange: onChange),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onChange,
  });

  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    final selected = selectedIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChange(index),
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? palette.primary : const Color(0xFFE4E4EA),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? palette.dark : _muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.label,
    required this.icon,
    this.active = false,
  });

  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = NavModePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? palette.soft : _soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: active ? palette.dark : _ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? palette.dark : _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.color,
    required this.textColor,
    this.horizontalPadding = 12,
    this.verticalPadding = 6,
  });

  final String label;
  final Color color;
  final Color textColor;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: textColor, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: _soft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _ink, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        error,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _emergency, fontSize: 12),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 4,
      decoration:
          BoxDecoration(color: _line, borderRadius: BorderRadius.circular(2)),
    );
  }
}
