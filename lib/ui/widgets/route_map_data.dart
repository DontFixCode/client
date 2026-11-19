import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../../data/bus_api.dart';
import '../../models/place.dart';

typedef BusPattern = ({String routeId, String patternKey});

class RouteMapLine {
  const RouteMapLine(
    this.points, {
    required this.walking,
    required this.legIndex,
    this.approximate = false,
  });
  final List<Offset> points; // GeoJSON: x = longitude, y = latitude.
  final bool walking;
  final int legIndex;
  final bool approximate;
}

enum RouteEndpoint {
  departure('출발'),
  arrival('도착'),
  both('출발·도착');

  const RouteEndpoint(this.label);
  final String label;
}

class RouteMapMarker {
  const RouteMapMarker(this.point, this.label, {this.endpoint});
  final Offset point;
  final String label;
  final RouteEndpoint? endpoint;
}

class RouteMapData {
  RouteMapData.fromLegs(
    List<Json> legs, {
    Place? origin,
    Place? destination,
    Map<BusPattern, List<Json>> patternStops = const {},
  }) {
    void addLine(
      Iterable<dynamic> coordinates,
      int index, {
      required bool walking,
      bool approximate = false,
    }) {
      var points = <Offset>[];
      void finish() {
        if (points.length > 1) {
          lines.add(
            RouteMapLine(
              points,
              walking: walking,
              legIndex: index,
              approximate: approximate,
            ),
          );
        }
        points = [];
      }

      for (final coordinate in coordinates) {
        final point = coordinate is List && coordinate.length >= 2
            ? _point(coordinate[0], coordinate[1])
            : null;
        if (point == null) {
          // Never bridge a gap left by a bad coordinate.
          finish();
        } else if (points.isEmpty || points.last != point) {
          points.add(point);
        }
      }
      finish();
    }

    void read(dynamic geometry, int index, bool walking) {
      if (geometry is! Map) return;
      final coordinates = geometry['coordinates'];
      switch (geometry['type']) {
        case 'LineString':
          if (coordinates is List) {
            addLine(coordinates, index, walking: walking);
          }
        case 'MultiLineString':
          if (coordinates is List) {
            for (final line in coordinates) {
              read({'type': 'LineString', 'coordinates': line}, index, walking);
            }
          }
        case 'Feature':
          read(geometry['geometry'], index, walking);
        case 'FeatureCollection' || 'GeometryCollection':
          final children = geometry['features'] ?? geometry['geometries'];
          if (children is List) {
            for (final child in children) {
              read(child, index, walking);
            }
          }
      }
    }

    void marker(Offset? point, String label, {RouteEndpoint? endpoint}) {
      if (point == null) return;
      final existing = markers.indexWhere((m) => m.point == point);
      if (existing < 0) {
        markers.add(RouteMapMarker(point, label, endpoint: endpoint));
      } else {
        final old = markers[existing];
        markers[existing] = RouteMapMarker(
          point,
          '${old.label}\n$label',
          endpoint: endpoint != null && old.endpoint != null
              ? RouteEndpoint.both
              : endpoint ?? old.endpoint,
        );
      }
    }

    marker(
      _point(origin?.longitude, origin?.latitude),
      '출발 · ${origin?.name}',
      endpoint: RouteEndpoint.departure,
    );
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final bus = leg['kind'] == 'bus';
      final before = lines.length;
      if (bus
          ? leg['geometryStatus'] == 'available'
          : leg['status'] != 'unavailable') {
        read(leg['geometry'], i, !bus);
      }
      if (!bus) continue;
      final pattern = before == lines.length ? _busPattern(leg) : null;
      if (pattern != null) {
        missingPatterns.add(pattern);
        final stops = patternStops[pattern];
        if (stops != null) {
          addLine(
            _stopCoordinates(leg, stops),
            i,
            walking: false,
            approximate: true,
          );
        }
      }
      for (final entry in {'board': '승차', 'alight': '하차'}.entries) {
        final stop = leg[entry.key];
        if (stop is! Map || stop['location'] is! Map) continue;
        final location = stop['location'] as Map;
        final number = leg['route'] is Map ? leg['route']['routeNo'] : null;
        marker(
          _point(location['longitude'], location['latitude']),
          '${number == null ? '버스' : '$number번'} ${entry.value} · ${stop['name'] ?? '정류소'}',
        );
      }
    }
    marker(
      _point(destination?.longitude, destination?.latitude),
      '도착 · ${destination?.name}',
      endpoint: RouteEndpoint.arrival,
    );
  }

  final List<RouteMapLine> lines = [];
  final List<RouteMapMarker> markers = [];
  final Set<BusPattern> missingPatterns = {};

  ({Offset center, int zoomLevel})? cameraFor(Size viewport) {
    if (!viewport.width.isFinite ||
        !viewport.height.isFinite ||
        viewport.width <= 96 ||
        viewport.height <= 96) {
      return null;
    }
    final points = [
      for (final line in lines) ...line.points,
      for (final marker in markers) marker.point,
    ];
    if (points.isEmpty) return null;
    double projectedY(double latitude) {
      final radians = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
      return (1 - math.log(math.tan(math.pi / 4 + radians / 2)) / math.pi) / 2;
    }

    final minX = points.map((p) => (p.dx + 180) / 360).reduce(math.min);
    final maxX = points.map((p) => (p.dx + 180) / 360).reduce(math.max);
    final minY = points.map((p) => projectedY(p.dy)).reduce(math.min);
    final maxY = points.map((p) => projectedY(p.dy)).reduce(math.max);
    // Use Flutter's laid-out viewport, not iOS's temporary 1x1 native view.
    // Reserve room for the endpoint badges and the map controls.
    final scale = math.max(
      (maxX - minX) * 256 / (viewport.width - 96),
      (maxY - minY) * 256 / (viewport.height - 96),
    );
    final y = math.pi * (1 - minY - maxY);
    return (
      center: Offset(
        (minX + maxX) * 180 - 180,
        (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi,
      ),
      zoomLevel: scale == 0
          ? 16
          : (-math.log(scale) / math.ln2).floor().clamp(6, 16),
    );
  }

  // Route objects are recreated on every journey update. Only map content
  // changes should recreate the native map, preserving the user's camera.
  String get fingerprint => jsonEncode([
    for (final line in lines)
      [
        line.walking,
        line.approximate,
        for (final p in line.points) [p.dx, p.dy],
      ],
    for (final m in markers)
      [m.point.dx, m.point.dy, m.label, m.endpoint?.name],
  ]);

  static BusPattern? _busPattern(Json leg) {
    final route = leg['route'];
    final id = route is Map ? route['id'] : null;
    final key = leg['patternKey'];
    final board = leg['board'], alight = leg['alight'];
    if (id is! String ||
        id.isEmpty ||
        key is! String ||
        key.isEmpty ||
        board is! Map ||
        alight is! Map ||
        board['seq'] is! int ||
        alight['seq'] is! int ||
        board['seq'] >= alight['seq'] ||
        board['stopId'] is! String ||
        alight['stopId'] is! String) {
      return null;
    }
    return (routeId: id, patternKey: key);
  }

  static Iterable<List<dynamic>?> _stopCoordinates(
    Json leg,
    List<Json> stops,
  ) sync* {
    final int first = leg['board']['seq'], last = leg['alight']['seq'];
    final segment = [
      for (final row in stops)
        if (row['seq'] case final int seq when first <= seq && seq <= last) row,
    ]..sort((a, b) => (a['seq'] as int).compareTo(b['seq'] as int));
    if (segment.length < 2 ||
        segment.first['seq'] != first ||
        segment.last['seq'] != last) {
      return;
    }

    Map? stop(Json row) => row['stop'] is Map ? row['stop'] as Map : null;
    // Check IDs as well as sequence numbers for repeated stops and stale data.
    if (stop(segment.first)?['id'] != leg['board']['stopId'] ||
        stop(segment.last)?['id'] != leg['alight']['stopId']) {
      return;
    }

    for (final row in segment) {
      final location = stop(row)?['location'];
      yield location is Map
          ? [location['longitude'], location['latitude']]
          : null;
    }
  }

  static Offset? _point(dynamic longitude, dynamic latitude) {
    if (longitude is! num ||
        latitude is! num ||
        !longitude.isFinite ||
        !latitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        latitude < -90 ||
        latitude > 90) {
      return null;
    }
    return Offset(longitude.toDouble(), latitude.toDouble());
  }
}
