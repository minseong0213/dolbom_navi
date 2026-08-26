class Coordinate {
  const Coordinate({
    required this.lat,
    required this.lon,
    this.name,
  });

  final double lat;
  final double lon;
  final String? name;

  factory Coordinate.fromJson(Map<String, dynamic> json) {
    return Coordinate(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      if (name != null) 'name': name,
    };
  }
}

class Place {
  const Place({
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    this.category,
  });

  final String name;
  final String address;
  final double lat;
  final double lon;
  final String? category;

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      category: json['category'] as String?,
    );
  }

  Coordinate toCoordinate() {
    return Coordinate(lat: lat, lon: lon, name: name);
  }
}

class RouteWarning {
  const RouteWarning({
    required this.kind,
    required this.message,
    required this.distanceAlongRouteM,
    required this.lat,
    required this.lon,
    required this.bumpCount,
    required this.impactSum,
    this.triggerDistancesM = const [300, 100],
  });

  final String kind;
  final String message;
  final double distanceAlongRouteM;
  final double lat;
  final double lon;
  final int bumpCount;
  final double impactSum;
  final List<int> triggerDistancesM;

  factory RouteWarning.fromJson(Map<String, dynamic> json) {
    return RouteWarning(
      kind: json['kind'] as String,
      message: json['message'] as String,
      distanceAlongRouteM: (json['distance_along_route_m'] as num).toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      bumpCount: json['bump_count'] as int,
      impactSum: (json['impact_sum'] as num).toDouble(),
      triggerDistancesM:
          (json['trigger_distances_m'] as List<dynamic>? ?? const [300, 100])
              .map((item) => (item as num).toInt())
              .toList(),
    );
  }
}

class NearbyBump {
  const NearbyBump({
    required this.id,
    required this.densityCount,
    required this.distanceM,
  });

  final int id;
  final int densityCount;
  final double distanceM;

  factory NearbyBump.fromJson(Map<String, dynamic> json) {
    return NearbyBump(
      id: json['id'] as int,
      densityCount: json['density_count'] as int,
      distanceM: (json['distance_from_route_m'] as num).toDouble(),
    );
  }
}

class RouteSummary {
  const RouteSummary({
    required this.totalDistanceM,
    required this.totalTimeS,
  });

  final double totalDistanceM;
  final double totalTimeS;

  factory RouteSummary.fromJson(Map<String, dynamic> json) {
    return RouteSummary(
      totalDistanceM: (json['total_distance_m'] as num).toDouble(),
      totalTimeS: (json['total_time_s'] as num).toDouble(),
    );
  }
}

class CandidateRoute {
  const CandidateRoute({
    required this.id,
    required this.searchOption,
    required this.searchOptionLabel,
    required this.rank,
    required this.score,
    required this.rawScore,
    required this.distanceNormalizedScore,
    required this.isExpressway,
    required this.summary,
    required this.addedTimeS,
    required this.bumpCount,
    required this.impactSum,
    required this.warnings,
    required this.polyline,
  });

  final String id;
  final int searchOption;
  final String searchOptionLabel;
  final int rank;
  final double score;
  final double rawScore;
  final double distanceNormalizedScore;
  final bool isExpressway;
  final RouteSummary summary;
  final double addedTimeS;
  final int bumpCount;
  final double impactSum;
  final List<RouteWarning> warnings;
  final List<Coordinate> polyline;

  factory CandidateRoute.fromJson(Map<String, dynamic> json) {
    return CandidateRoute(
      id: json['id'] as String,
      searchOption: json['search_option'] as int,
      searchOptionLabel: json['search_option_label'] as String,
      rank: json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      rawScore: ((json['raw_score'] ?? json['score']) as num).toDouble(),
      distanceNormalizedScore:
          ((json['distance_normalized_score'] ?? json['score']) as num)
              .toDouble(),
      isExpressway: json['is_expressway'] as bool? ?? false,
      summary: RouteSummary.fromJson(json['summary'] as Map<String, dynamic>),
      addedTimeS: (json['added_time_s'] as num).toDouble(),
      bumpCount: json['bump_count'] as int,
      impactSum: (json['impact_sum'] as num).toDouble(),
      warnings: (json['warnings'] as List<dynamic>)
          .map((item) => RouteWarning.fromJson(item as Map<String, dynamic>))
          .toList(),
      polyline: (json['polyline'] as List<dynamic>)
          .map((item) => Coordinate.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouteRecommendResponse {
  const RouteRecommendResponse({
    required this.recommendedRouteId,
    required this.fastestRouteId,
    required this.candidates,
  });

  final String? recommendedRouteId;
  final String? fastestRouteId;
  final List<CandidateRoute> candidates;

  factory RouteRecommendResponse.fromJson(Map<String, dynamic> json) {
    return RouteRecommendResponse(
      recommendedRouteId: json['recommended_route_id'] as String?,
      fastestRouteId: json['fastest_route_id'] as String?,
      candidates: (json['candidates'] as List<dynamic>)
          .map((item) => CandidateRoute.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
