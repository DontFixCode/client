import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import 'data_reason.dart';

import '../../models/travel_route.dart';
import '../theme/app_theme.dart';
import 'route_card.dart';
import 'status_pill.dart';

class RouteTimeline extends StatelessWidget {
  const RouteTimeline({super.key, required this.route});
  final TravelRoute route;

  @override
  Widget build(BuildContext context) => route.isLive
      ? _live(context)
      : Column(
          children: [
            _TimelineStop(
              title: route.origin.name,
              subtitle: '출발 · 승차 정류장까지 도보',
              icon: Icons.trip_origin_rounded,
              detail: '도보 ${route.walkMinutes! ~/ 2}분',
            ),
            _TimelineStop(
              title: route.boardingStop,
              subtitle: '${route.waitMinutes}분 대기 후 탑승',
              icon: Icons.directions_bus_rounded,
              badge: BusNumberChip(route.busNumbers.first),
              detail: route.transfers == 0
                  ? '버스 ${route.minutes! - route.walkMinutes! - route.waitMinutes!}분'
                  : '첫 번째 버스 이용',
            ),
            if (route.transferStop != null)
              _TimelineStop(
                title: route.transferStop!,
                subtitle: '하차 후 연결 정류장으로 이동',
                icon: Icons.transfer_within_a_station_rounded,
                badge: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    BusNumberChip(route.busNumbers.last, blue: true),
                    TransferProbabilityPill(route.probability),
                  ],
                ),
                detail: route.marginMinutes == null
                    ? '환승 여유 확인 불가'
                    : '환승 여유 ${route.marginMinutes}분',
                blue: true,
              ),
            _TimelineStop(
              title: route.arrivalStop,
              subtitle: '버스에서 내려 목적지로 이동',
              icon: Icons.directions_walk_rounded,
              detail: '도보 ${route.walkMinutes! - route.walkMinutes! ~/ 2}분',
              blue: route.transfers > 0,
            ),
            _TimelineStop(
              title: route.destination.name,
              subtitle: '목적지 도착',
              icon: Icons.location_on_rounded,
              last: true,
            ),
          ],
        );
  Widget _live(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (route.estimated)
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text('배차간격 기반 예상 경로 · 실제 운행 시각과 다를 수 있어요.'),
        ),
      for (final leg in route.legs) ...[
        if (leg['kind'] == 'walk')
          _TimelineStop(
            title:
                '${leg['from']?['name'] ?? '출발 위치'} → ${leg['to']?['name'] ?? '도착 위치'}',
            subtitle:
                leg['status'] == 'available' || leg['status'] == 'same_stop'
                ? '도보 이동'
                : '도보 경로 확인 불가',
            icon: Icons.directions_walk_rounded,
            detail: leg['durationSeconds'] == null
                ? '도보시간 확인 불가'
                : '도보 ${minutesFromSeconds(leg['durationSeconds'])}분',
            last: leg == route.legs.last,
          ),
        if (leg['kind'] == 'bus')
          _TimelineStop(
            title:
                '${leg['board']?['name'] ?? '승차 정류소'} → ${leg['alight']?['name'] ?? '하차 정류소'}',
            subtitle:
                '승차 ${leg['board']?['seq'] ?? '?'}번째 → 하차 ${leg['alight']?['seq'] ?? '?'}번째 경유',
            icon: Icons.directions_bus_rounded,
            badge: BusNumberChip(
              '${leg['route']?['routeNo'] ?? '미확인'}',
              type: leg['route']?['routeType']?.toString(),
            ),
            detail: _busDetail(leg),
            last: leg == route.legs.last,
          ),
      ],
      if (route.transferEvaluations.isNotEmpty) ...[
        const Divider(),
        const SizedBox(height: 12),
        Text('연결 버스별 환승 평가', style: Theme.of(context).textTheme.titleSmall),
        for (var i = 0; i < route.transferEvaluations.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _transfer(route.transferEvaluations[i], i),
          ),
      ],
      for (final reason in route.reasonCodes.map(dataReason).toSet())
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(reason, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
  String _busDetail(Json leg) => [
    leg['rideSeconds'] == null
        ? '버스시간 확인 불가'
        : '버스 ${minutesFromSeconds(leg['rideSeconds'])}분',
    for (final (label, key) in [('승차', 'boardEta'), ('하차', 'alightEta')])
      if (leg[key] case final Json eta) ...[
        '$label 예상: ${_time(eta['predictedArrivalAt'])} · ${etaSourceLabel(eta)}',
        '예측 기준: ${_time(eta['basisAt'])}',
      ],
  ].join('\n');

  String _time(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')
          ?.toLocal()
          .toString()
          .split('.')
          .first ??
      '확인 불가';

  Widget _transfer(Json transfer, int i) {
    final next = route.legs
        .where((l) => l['legIndex'] == transfer['nextLegIndex'])
        .firstOrNull;
    final probability = probabilityPercent(transfer['probability']);
    final slack = transfer['slackSeconds'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${i + 1}번째 환승 · ${next?['route']?['routeNo'] ?? '연결'}번 · ${next?['board']?['name'] ?? ''}',
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            TransferProbabilityPill(probability),
            Text(
              slack == null
                  ? '환승 여유 확인 불가'
                  : '환승 여유 ${(slack as num) < 60 ? secondsLabel(slack) : '${minutesFromSeconds(slack)}분'}',
            ),
          ],
        ),
        for (final reason in List<String>.from(
          transfer['reasonCodes'] ?? [],
        ).map(dataReason).toSet())
          Text(
            reason,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.detail,
    this.badge,
    this.last = false,
    this.blue = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? detail;
  final Widget? badge;
  final bool last;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    final color = blue ? AppColors.blue : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: blue ? AppColors.blueLight : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: color.withValues(alpha: .25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  if (badge != null) ...[const SizedBox(height: 9), badge!],
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(detail!, style: TextStyle(fontSize: 12, color: color)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
