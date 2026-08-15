import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/route_models.dart';

class CurrentLocationException implements Exception {
  const CurrentLocationException(this.message, {this.openSettings = false});

  final String message;
  final bool openSettings;

  @override
  String toString() => message;
}

class CurrentLocationService {
  const CurrentLocationService();

  Future<Place> getCurrentPlace() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const CurrentLocationException(
        '기기의 위치 서비스를 켜 주세요.',
        openSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const CurrentLocationException('현재 위치 권한이 필요합니다.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const CurrentLocationException(
        '앱 설정에서 현재 위치 권한을 허용해 주세요.',
        openSettings: true,
      );
    }

    final cachedPosition = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: _isAndroid,
    );
    if (cachedPosition != null && _isRecent(cachedPosition)) {
      return _toPlace(cachedPosition);
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
    } on TimeoutException {
      if (cachedPosition == null) {
        rethrow;
      }
      position = cachedPosition;
    }
    return _toPlace(position);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  LocationSettings get _locationSettings => _isAndroid
      ? AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 12),
        )
      : const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        );

  bool _isRecent(Position position) {
    return DateTime.now().difference(position.timestamp).abs() <=
        const Duration(minutes: 2);
  }

  Place _toPlace(Position position) {
    return Place(
      name: '현재 위치',
      address: 'GPS 현재 위치',
      lat: position.latitude,
      lon: position.longitude,
      category: '현재 위치',
    );
  }

  Future<bool> openRelevantSettings() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Geolocator.openLocationSettings();
    }
    return Geolocator.openAppSettings();
  }
}
