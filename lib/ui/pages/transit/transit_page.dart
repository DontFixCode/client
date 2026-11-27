import 'package:flutter/material.dart';

import '../../../data/bus_api.dart';
import '../../../models/congestion.dart';
import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../widgets/api_action.dart';
import '../../widgets/route_geometry.dart';

class TransitPage extends StatefulWidget {
  const TransitPage({super.key});
  @override
  State<TransitPage> createState() => _TransitPageState();
}

class _TransitPageState extends State<TransitPage> {
  final _number = TextEditingController();
  List<Json>? _stops, _routes;
  Json? _version;
  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _nearby() async {
    final state = AppScope.of(context);
    await apiAction(context, () async {
      if (!state.origin.hasCoordinates) {
        throw const ApiException('LOCATION_REQUIRED', '홈에서 출발지를 먼저 지정해 주세요.');
      }
      final data = await state.api.request(
        'GET',
        '/stops/nearby',
        query: {
          'latitude': '${state.origin.latitude}',
          'longitude': '${state.origin.longitude}',
        },
      );
      if (mounted) {
        setState(() => _stops = (data['items'] as List).cast<Json>());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('정류소·노선 정보')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('출발지: ${state.origin.name}'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.busy ? null : _nearby,
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('출발지 주변 정류소 조회'),
          ),
          if (_stops?.isEmpty == true)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('검색 반경 안에 정류소가 없어요.'),
            ),
          for (final stop in _stops ?? <Json>[])
            ListTile(
              title: Text(stop['name'] as String? ?? '정류소'),
              subtitle: Text(
                '직선거리 ${(stop['straightDistanceM'] as num?)?.round() ?? '?'}m · 실제 도보 경로와 다를 수 있어요.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openStop(context, stop),
            ),
          const Divider(height: 32),
          TextField(
            controller: _number,
            maxLength: 30,
            decoration: const InputDecoration(
              labelText: '버스 번호',
              hintText: '605',
            ),
          ),
          OutlinedButton(
            onPressed: state.busy
                ? null
                : () async {
                    if (_number.text.trim().isEmpty) return;
                    await apiAction(context, () async {
                      final data = await state.api.request(
                        'GET',
                        '/routes',
                        query: {'routeNo': _number.text.trim()},
                      );
                      if (mounted) {
                        setState(
                          () => _routes = (data['items'] as List).cast<Json>(),
                        );
                      }
                    });
                  },
            child: const Text('노선 검색'),
          ),
          if (_routes?.isEmpty == true) const Text('일치하는 노선이 없어요.'),
          for (final route in _routes ?? <Json>[])
            ListTile(
              title: Text('${route['routeNo']}번'),
              subtitle: Text(
                '${route['startName'] ?? ''} → ${route['endName'] ?? ''}',
              ),
              onTap: () => _openRoute(context, route),
            ),
          const Divider(height: 32),
          TextButton(
            onPressed: state.busy
                ? null
                : () => apiAction(context, () async {
                    final data = await state.api.request(
                      'GET',
                      '/static-data/version',
                    );
                    if (mounted) setState(() => _version = data);
                  }),
            child: const Text('정적 교통정보 공개 상태 확인'),
          ),
          if (_version != null)
            Text(
              _version!['mixedVersions'] == true
                  ? '여러 공개본이 혼재되어 있어요.'
                  : _version!['dataVersion'] == null
                  ? '정적 공개본이 없어요.'
                  : '교통정보 공개 시각: ${_date(_version!['publishedAt'])}',
            ),
        ],
      ),
    );
  }
}

void _openStop(BuildContext context, Json stop) {
  final api = AppScope.of(context).api;
  final id = Uri.encodeComponent(stop['id'] as String);
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _TransitDetail(
        title: stop['name'] as String? ?? '정류소',
        load: () async {
          final results = await Future.wait([
            api.request('GET', '/stops/$id'),
            api.request('GET', '/stops/$id/routes'),
            api.request('GET', '/stops/$id/arrivals'),
          ]);
          return {
            'stop': results[0],
            'routes': results[1],
            'arrivals': results[2],
          };
        },
        content: (context, data) => [
          Text('정류소 번호: ${data['stop']['stopNo'] ?? '미제공'}'),
          const SizedBox(height: 16),
          ...arrivalWidgets(data['arrivals'] as Json),
          const Divider(height: 32),
          Text('경유 노선', style: Theme.of(context).textTheme.titleMedium),
          for (final visit in data['routes']['items'] as List)
            ListTile(
              title: Text('${visit['route']['routeNo']}번'),
              subtitle: Text('${visit['towardStopName'] ?? '방향 미제공'} 방면'),
              onTap: () => _openRoute(context, visit['route'] as Json),
            ),
        ],
      ),
    ),
  );
}

void _openRoute(BuildContext context, Json route) {
  final api = AppScope.of(context).api;
  final id = Uri.encodeComponent(route['id'] as String);
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _TransitDetail(
        title: '${route['routeNo']}번 노선',
        load: () async {
          final results = await Future.wait([
            api.request('GET', '/routes/$id'),
            api.request('GET', '/routes/$id/patterns'),
            api.request('GET', '/routes/$id/positions'),
          ]);
          return {
            'route': results[0],
            'patterns': results[1],
            'positions': results[2],
          };
        },
        content: (context, data) => [
          Text(
            '${data['route']['startName'] ?? ''} → ${data['route']['endName'] ?? ''}',
          ),
          const SizedBox(height: 16),
          Text('운행 순서', style: Theme.of(context).textTheme.titleMedium),
          for (final pattern in data['patterns']['items'] as List)
            ListTile(
              title: Text(
                '${pattern['firstStop']?['name']} → ${pattern['lastStop']?['name']}',
              ),
              subtitle: Text('경유 ${pattern['stopCount']}곳'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openPattern(context, route, pattern as Json),
            ),
          const Divider(height: 32),
          Text('수집된 버스 위치', style: Theme.of(context).textTheme.titleMedium),
          Text(_status(data['positions']['dataStatus'] as Json)),
          for (final position in data['positions']['items'] as List)
            ListTile(
              title: Text('차량 ${position['vehicleNo'] ?? '미확인'}'),
              subtitle: Text(
                '경유 순서 ${position['seq'] ?? '미확인'} · 수집 ${_date(position['collectedAt'])}\n${position['location'] == null ? '좌표 미제공' : '${position['location']['latitude']}, ${position['location']['longitude']}'}',
              ),
            ),
        ],
      ),
    ),
  );
}

void _openPattern(BuildContext context, Json route, Json pattern) {
  final api = AppScope.of(context).api;
  final id = Uri.encodeComponent(route['id'] as String),
      key = Uri.encodeComponent(pattern['patternKey'] as String);
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => _TransitDetail(
        title: '${route['routeNo']}번 경유 정류소',
        load: () async {
          final r = await Future.wait([
            api.request('GET', '/routes/$id/patterns/$key/stops'),
            api.request('GET', '/routes/$id/shapes/$key'),
          ]);
          return {'stops': r[0], 'shape': r[1]};
        },
        content: (context, data) => [
          RouteGeometry(
            legs: [
              {
                'kind': 'bus',
                'route': route,
                'geometry': data['shape']['geometry'],
                'geometryStatus': (data['shape']['status'] as String?)
                    ?.toLowerCase(),
                'geometrySource': data['shape']['source'],
                'geometryVersion': data['shape']['version'],
                'geometryFetchedAt': data['shape']['fetchedAt'],
                'geometryReason': data['shape']['reason'],
              },
            ],
          ),
          for (final item in data['stops']['items'] as List)
            ListTile(
              title: Text('${item['seq']}. ${item['stop']['name']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openStop(context, item['stop'] as Json),
            ),
        ],
      ),
    ),
  );
}

List<Widget> arrivalWidgets(Json arrivals) => [
  Text(_status(arrivals['dataStatus'] as Json)),
  for (final item in arrivals['items'] as List)
    ListTile(
      title: Text('${item['route']?['routeNo'] ?? '노선 미확인'}번'),
      subtitle: Text(
        [
          item['predictedArrivalAt'] == null
              ? '기준 시각 미확인 · 원천 예상 ${minutesFromSeconds(item['remainingSeconds']) ?? '?'}분'
              : '도착 예상 ${_date(item['predictedArrivalAt'])}',
          '차량 ${item['vehicle']?['vehicleNo'] ?? '미확인'} · ${item['stopsAway'] ?? '?'}정류소 전',
          ?congestionDetail(item['congestion']),
        ].join('\n'),
      ),
    ),
];
String _status(Json data) {
  final state = switch (data['availability']) {
    'empty' => '수집 결과 도착·위치 정보가 없어요.',
    'available' => '공유 수집 자료',
    _ => '아직 수집된 정보가 없어요. 잠시 후 새로고침해 주세요.',
  };
  return '$state${data['isStale'] == true ? ' · 오래된 자료예요.' : ''}${data['lastAttemptFailed'] == true ? ' · 최근 수집에 실패했어요.' : ''}${data['collectedAt'] == null ? '' : '\n수집 ${_date(data['collectedAt'])}'}';
}

String _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')
        ?.toLocal()
        .toString()
        .split('.')
        .first ??
    '확인 불가';

class _TransitDetail extends StatefulWidget {
  const _TransitDetail({
    required this.title,
    required this.load,
    required this.content,
  });
  final String title;
  final Future<Json> Function() load;
  final List<Widget> Function(BuildContext, Json) content;
  @override
  State<_TransitDetail> createState() => _TransitDetailState();
}

class _TransitDetailState extends State<_TransitDetail> {
  late Future<Json> _data;
  @override
  void initState() {
    super.initState();
    _data = widget.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: '최신 자료 조회',
          onPressed: () => setState(() {
            _data = widget.load();
          }),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Json>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(snapshot.error.toString()),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: widget.content(context, snapshot.data!),
        );
      },
    ),
  );
}
