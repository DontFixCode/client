import 'dart:convert';
import 'dart:ui';

import '../../data/bus_api.dart';
import '../../models/place.dart';

class RouteMapLine {
  const RouteMapLine(
    this.points, {
    required this.walking,
    required this.legIndex,
  });
  final List<Offset> points; // GeoJSON: x = longitude, y = latitude.
  final bool walking;
  final int legIndex;
}

class RouteMapMarker {
  const RouteMapMarker(this.point, this.label, {required this.endpoint});
  final Offset point;
  final String label;
  final bool endpoint;
}

class RouteMapData {
  RouteMapData.fromLegs(List<Json> legs, {Place? origin, Place? destination}) {
    void read(dynamic geometry, int index, bool walking) {
      if (geometry is! Map) return;
      final coordinates = geometry['coordinates'];
      switch (geometry['type']) {
        case 'LineString':
          if (coordinates is! List) return;
          var points = <Offset>[];
          void finish() {
            if (points.length > 1) {
              lines.add(
                RouteMapLine(points, walking: walking, legIndex: index),
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

    void marker(Offset? point, String label, {bool endpoint = false}) {
      if (point == null) return;
      final existing = markers.indexWhere((m) => m.point == point);
      if (existing < 0) {
        markers.add(RouteMapMarker(point, label, endpoint: endpoint));
      } else {
        final old = markers[existing];
        markers[existing] = RouteMapMarker(
          point,
          '${old.label}\n$label',
          endpoint: endpoint || old.endpoint,
        );
      }
    }

    marker(
      _point(origin?.longitude, origin?.latitude),
      '출발 · ${origin?.name}',
      endpoint: true,
    );
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final bus = leg['kind'] == 'bus';
      if (bus
          ? leg['geometryStatus'] == 'available'
          : leg['status'] != 'unavailable') {
        read(leg['geometry'], i, !bus);
      }
      if (!bus) continue;
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
      endpoint: true,
    );
  }

  final List<RouteMapLine> lines = [];
  final List<RouteMapMarker> markers = [];

  // Route objects are recreated on every journey update. Only map content
  // changes should recreate the native map, preserving the user's camera.
  String get fingerprint => jsonEncode([
    for (final line in lines)
      [
        line.walking,
        for (final p in line.points) [p.dx, p.dy],
      ],
    for (final m in markers) [m.point.dx, m.point.dy, m.label, m.endpoint],
  ]);

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
