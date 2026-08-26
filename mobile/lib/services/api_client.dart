import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/route_models.dart';

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000',
            );

  final http.Client _httpClient;
  final String _baseUrl;

  Future<List<Place>> searchPlaces(String query) async {
    final uri = Uri.parse('$_baseUrl/api/places/search').replace(
      queryParameters: {
        'q': query,
        'count': '8',
      },
    );
    final response = await _httpClient.get(uri);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['places'] as List<dynamic>)
        .map((item) => Place.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<RouteRecommendResponse> recommendRoutes({
    required Coordinate origin,
    required Coordinate destination,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/api/routes/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'search_options': [0, 1, 2, 4, 10, 12],
        'buffer_m': 10,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    return RouteRecommendResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<List<NearbyBump>> nearbyBumps({
    required double lat,
    required double lon,
    double radiusM = 30,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/bumps/nearby').replace(
      queryParameters: {
        'lat': lat.toStringAsFixed(7),
        'lon': lon.toStringAsFixed(7),
        'radius_m': radiusM.toStringAsFixed(1),
      },
    );
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (data['bumps'] as List<dynamic>)
        .map((item) => NearbyBump.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}
