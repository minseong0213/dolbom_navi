import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/route_models.dart';
import 'api_client.dart';
import 'drive_csv_store.dart';
import 'drive_csv_writer.dart';

enum DriveRecorderState { idle, recording, stopping, completed, error }

enum DriveSampleLabel { normal, bump, excluded }

class DriveDataRecorder extends ChangeNotifier {
  DriveDataRecorder({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  static const minSpeedKmh = 10.0;
  static const maxAccelMps2 = 15.0;
  static const cooldown = Duration(seconds: 2);
  static const manualLabelWindow = Duration(seconds: 2);
  static const sensorPeriod = Duration(milliseconds: 20);

  final ApiClient _apiClient;
  final Queue<_DriveSample> _pendingSamples = Queue<_DriveSample>();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<UserAccelerometerEvent>? _sensorSubscription;
  DriveCsvWriter? _writer;
  Position? _position;
  Position? _lastLookupPosition;
  DateTime? _lastLookupAt;
  DateTime? _startedAt;
  DateTime? _lastUiUpdate;
  bool _lookupInFlight = false;
  _NearbyLabel _nearbyLabel = const _NearbyLabel.pending();
  int? _activeAutoBumpId;

  DriveRecorderState state = DriveRecorderState.idle;
  String? errorMessage;
  String? filePath;
  int sampleCount = 0;
  int manualLabelCount = 0;
  int autoLabelCount = 0;
  double latestX = 0;
  double latestY = 0;
  double latestZ = 0;

  bool get isRecording => state == DriveRecorderState.recording;

  double get speedKmh => math.max(0, (_position?.speed ?? 0) * 3.6);

  double? get latitude => _position?.latitude;

  double? get longitude => _position?.longitude;

  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  String get nearbyStatus => _nearbyLabel.description;

  Future<void> start() async {
    if (isRecording) {
      return;
    }

    state = DriveRecorderState.idle;
    errorMessage = null;
    filePath = null;
    sampleCount = 0;
    manualLabelCount = 0;
    autoLabelCount = 0;
    _pendingSamples.clear();
    _nearbyLabel = const _NearbyLabel.pending();
    _activeAutoBumpId = null;
    notifyListeners();

    try {
      await _ensureLocationPermission();
      final filename = 'drive_${_filenameTimestamp(DateTime.now())}.csv';
      _writer = await createDriveCsvWriter(filename);
      filePath = _writer!.path;
      _writer!.write(
        'timestamp_utc_ms,z_accel,x_accel,y_accel,gps_lat,gps_lon,'
        'gps_speed_kmh,label,label_source,filter_state\n',
      );

      _startedAt = DateTime.now();
      state = DriveRecorderState.recording;
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        _onPosition,
        onError: (Object error) {
          errorMessage = 'GPS 업데이트 오류: $error';
          _notifyNow();
        },
      );
      _sensorSubscription = userAccelerometerEventStream(
        samplingPeriod: sensorPeriod,
      ).listen(
        _onSensor,
        onError: (Object error) {
          errorMessage = '가속도 센서 오류: $error';
          state = DriveRecorderState.error;
          _notifyNow();
        },
      );
      notifyListeners();
    } catch (error) {
      state = DriveRecorderState.error;
      errorMessage = '$error';
      await _closeResources();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!isRecording && state != DriveRecorderState.error) {
      return;
    }
    state = DriveRecorderState.stopping;
    notifyListeners();
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _flushAll();
    await _writer?.close();
    _writer = null;
    state = errorMessage == null
        ? DriveRecorderState.completed
        : DriveRecorderState.error;
    notifyListeners();
  }

  void markManualBump() {
    if (!isRecording || _pendingSamples.isEmpty) {
      return;
    }
    final cutoff = DateTime.now().toUtc().subtract(manualLabelWindow);
    for (final sample in _pendingSamples) {
      if (!sample.timestampUtc.isBefore(cutoff)) {
        sample.label = DriveSampleLabel.bump;
        sample.labelSource = 'manual';
      }
    }
    manualLabelCount += 1;
    _notifyNow();
  }

  void _onPosition(Position position) {
    _position = position;
    if (_shouldLookupNearby(position)) {
      unawaited(_refreshNearbyLabel(position));
    }
    _notifyThrottled();
  }

  void _onSensor(UserAccelerometerEvent event) {
    if (!isRecording || _writer == null) {
      return;
    }
    latestX = event.x;
    latestY = event.y;
    latestZ = event.z;

    final auto = _automaticLabelFor(event);
    final sample = _DriveSample(
      timestampUtc: DateTime.now().toUtc(),
      x: event.x,
      y: event.y,
      z: event.z,
      latitude: _position?.latitude,
      longitude: _position?.longitude,
      speedKmh: speedKmh,
      label: auto.label,
      labelSource: auto.source,
      filterState: auto.filterState,
    );
    _pendingSamples.add(sample);
    sampleCount += 1;
    _flushExpired(sample.timestampUtc);
    _notifyThrottled();
  }

  _SampleClassification _automaticLabelFor(UserAccelerometerEvent event) {
    final peak =
        math.max(event.x.abs(), math.max(event.y.abs(), event.z.abs()));
    if (peak > maxAccelMps2) {
      return const _SampleClassification(
        DriveSampleLabel.excluded,
        'filter',
        'accel_over_limit',
      );
    }
    if (_position == null) {
      return const _SampleClassification(
        DriveSampleLabel.excluded,
        'filter',
        'gps_unavailable',
      );
    }
    if (speedKmh <= minSpeedKmh) {
      return const _SampleClassification(
        DriveSampleLabel.excluded,
        'filter',
        'speed_below_min',
      );
    }
    if (_nearbyLabel.unavailable) {
      return const _SampleClassification(
        DriveSampleLabel.excluded,
        'filter',
        'db_unavailable',
      );
    }
    if (_nearbyLabel.excluded) {
      return const _SampleClassification(
        DriveSampleLabel.excluded,
        'db',
        'dense_bump_excluded',
      );
    }
    if (_nearbyLabel.isBump) {
      return const _SampleClassification(
        DriveSampleLabel.bump,
        'db',
        'eligible',
      );
    }
    return const _SampleClassification(
      DriveSampleLabel.normal,
      'auto',
      'eligible',
    );
  }

  bool _shouldLookupNearby(Position position) {
    if (_lookupInFlight) {
      return false;
    }
    final now = DateTime.now();
    if (_lastLookupAt == null || _lastLookupPosition == null) {
      return true;
    }
    final movedM = Geolocator.distanceBetween(
      _lastLookupPosition!.latitude,
      _lastLookupPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    return movedM >= 8 ||
        now.difference(_lastLookupAt!) >= const Duration(seconds: 2);
  }

  Future<void> _refreshNearbyLabel(Position position) async {
    _lookupInFlight = true;
    _lastLookupAt = DateTime.now();
    _lastLookupPosition = position;
    try {
      final bumps = await _apiClient.nearbyBumps(
        lat: position.latitude,
        lon: position.longitude,
      );
      if (bumps.isEmpty) {
        _nearbyLabel = const _NearbyLabel.normal();
        _activeAutoBumpId = null;
      } else {
        final nearest = bumps.first;
        if (nearest.densityCount >= 2) {
          _nearbyLabel = _NearbyLabel.excluded(nearest);
          _activeAutoBumpId = null;
        } else {
          _nearbyLabel = _NearbyLabel.bump(nearest);
          if (speedKmh > minSpeedKmh && _activeAutoBumpId != nearest.id) {
            autoLabelCount += 1;
            _activeAutoBumpId = nearest.id;
          } else if (speedKmh <= minSpeedKmh) {
            _activeAutoBumpId = null;
          }
        }
      }
    } catch (_) {
      _nearbyLabel = const _NearbyLabel.lookupFailed();
      _activeAutoBumpId = null;
    } finally {
      _lookupInFlight = false;
      _notifyNow();
    }
  }

  void _flushExpired(DateTime nowUtc) {
    final cutoff = nowUtc.subtract(manualLabelWindow);
    while (_pendingSamples.isNotEmpty &&
        _pendingSamples.first.timestampUtc.isBefore(cutoff)) {
      _writeSample(_pendingSamples.removeFirst());
    }
  }

  void _flushAll() {
    while (_pendingSamples.isNotEmpty) {
      _writeSample(_pendingSamples.removeFirst());
    }
  }

  void _writeSample(_DriveSample sample) {
    _writer?.write('${sample.toCsv()}\n');
  }

  Future<void> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('기기의 위치 서비스를 켜 주세요.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('실주행 기록을 위해 위치 권한이 필요합니다.');
    }
  }

  LocationSettings get _locationSettings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
        intervalDuration: const Duration(seconds: 1),
        forceLocationManager: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (_lastUiUpdate == null ||
        now.difference(_lastUiUpdate!) >= const Duration(milliseconds: 250)) {
      _lastUiUpdate = now;
      notifyListeners();
    }
  }

  void _notifyNow() {
    _lastUiUpdate = DateTime.now();
    notifyListeners();
  }

  Future<void> _closeResources() async {
    await _sensorSubscription?.cancel();
    _sensorSubscription = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _flushAll();
    await _writer?.close();
    _writer = null;
  }

  @override
  void dispose() {
    unawaited(_closeResources());
    super.dispose();
  }

  static String _filenameTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}

class _DriveSample {
  _DriveSample({
    required this.timestampUtc,
    required this.x,
    required this.y,
    required this.z,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.label,
    required this.labelSource,
    required this.filterState,
  });

  final DateTime timestampUtc;
  final double x;
  final double y;
  final double z;
  final double? latitude;
  final double? longitude;
  final double speedKmh;
  DriveSampleLabel label;
  String labelSource;
  final String filterState;

  String toCsv() {
    String coordinate(double? value) => value?.toStringAsFixed(7) ?? '';
    return [
      timestampUtc.millisecondsSinceEpoch,
      z.toStringAsFixed(6),
      x.toStringAsFixed(6),
      y.toStringAsFixed(6),
      coordinate(latitude),
      coordinate(longitude),
      speedKmh.toStringAsFixed(3),
      label.name,
      labelSource,
      filterState,
    ].join(',');
  }
}

class _SampleClassification {
  const _SampleClassification(this.label, this.source, this.filterState);

  final DriveSampleLabel label;
  final String source;
  final String filterState;
}

class _NearbyLabel {
  const _NearbyLabel._({
    required this.description,
    this.isBump = false,
    this.excluded = false,
    this.unavailable = false,
  });

  const _NearbyLabel.pending()
      : this._(description: '방지턱 DB 확인 중', unavailable: true);

  const _NearbyLabel.normal() : this._(description: '주변 독립 방지턱 없음');

  const _NearbyLabel.lookupFailed()
      : this._(description: '방지턱 DB 확인 실패', unavailable: true);

  factory _NearbyLabel.bump(NearbyBump bump) {
    return _NearbyLabel._(
      description: '독립 방지턱 ${bump.distanceM.toStringAsFixed(0)}m',
      isBump: true,
    );
  }

  factory _NearbyLabel.excluded(NearbyBump bump) {
    return _NearbyLabel._(
      description: '밀집 구간 제외 ${bump.distanceM.toStringAsFixed(0)}m',
      excluded: true,
    );
  }

  final String description;
  final bool isBump;
  final bool excluded;
  final bool unavailable;
}
