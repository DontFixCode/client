import '../data/bus_api.dart';

const _levels = {
  'empty': '매우 여유',
  'relaxed': '여유',
  'normal': '보통',
  'crowded': '혼잡',
  'very_crowded': '매우 혼잡',
};

String? congestionLabel(Object? data) =>
    data is Json && data['status'] == 'available'
    ? _levels[data['level']]
    : null;

String? rankingCostLabel(Json? cost) {
  if (cost
      case {
        'timeSeconds': final num time,
        'equilibriumBiasSeconds': final num bias,
        'costSeconds': final num total,
      }
      when time.isFinite && bias.isFinite && total.isFinite) {
    String duration(num value) {
      final minutes = value.round() ~/ 60, seconds = value.round() % 60;
      if (minutes == 0) return '$seconds초';
      return seconds == 0 ? '$minutes분' : '$minutes분 $seconds초';
    }

    return '추천 순위 계산값 ${duration(total)} · 이동 ${duration(time)} + 혼잡 가중 ${duration(bias)}';
  }
  return null;
}

String? routeCongestionSummary(List<Json> buses) {
  final levels = [
    for (final bus in buses)
      if (congestionLabel(bus['congestion']) != null)
        bus['congestion']['level'] as String,
  ];
  if (levels.isEmpty) return null;
  final highest = _levels.keys.lastWhere(levels.contains);
  final coverage = levels.length == buses.length
      ? ''
      : ' (${levels.length}/${buses.length}구간 확인)';
  return '평소 이 시간대 예상 혼잡도 · ${_levels[highest]}$coverage';
}

String? congestionDetail(Object? value) {
  if (value is! Json) return null;
  final label = congestionLabel(value);
  if (label == null) {
    final reason = switch (value['reason']) {
      'congestion_not_configured' => '좌석·정원 정보 부족',
      'congestion_profile_missing' => '노선 승하차 집계 없음',
      'congestion_profile_missing_for_time' => '해당 시간대의 승하차 집계 없음',
      'congestion_trips_unknown' => '운행 횟수 미확인',
      'congestion_time_unknown' => '탑승 시각 미확인',
      _ => null,
    };
    return ['예상 혼잡도 확인 불가', ?reason].join(' · ');
  }
  final day = switch (value['dayType']) {
    'weekday' => '평일',
    'saturday' => '토요일',
    'holiday' => '일요일·공휴일',
    _ => null,
  };
  final period = [
    ?day,
    if (value['hour'] case final int hour) '$hour시',
  ].join(' ');
  return [
    '평소 ${period.isEmpty ? '이 시간대' : period} 예상 혼잡도 · $label',
    if (value['loadPerVehicle'] case final num load)
      '1대당 약 ${load.toStringAsFixed(1)}명',
    if (value['guidedRiders'] case final num guided when guided > 0)
      '앱 안내 인원 반영',
    if (value['fallback'] == 'adjacent_hours') '인접 시간대 집계 사용',
    if (value['fallback'] == 'weekday') '평일 같은 시간대 집계 사용',
    if (value['lowConfidence'] == true) '표본 일수 부족',
  ].join(' · ');
}
