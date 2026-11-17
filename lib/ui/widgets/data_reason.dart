import '../../data/bus_api.dart';

String secondsLabel(dynamic value) =>
    value is num && value.isFinite ? '${value.round()}초' : '확인 불가';

String etaSourceLabel(Json eta) => switch (eta['etaSource']) {
  'headway_estimate' => '배차간격 기반 추정 · 실제 차량·시각 미확정',
  'leading_vehicle_gap' => '앞차 간격 기반 추정 · 검증 전',
  'historical_segments' => '과거 구간 주행시간 기반 추정',
  'provider' =>
    eta['basisSource'] == 'server_received_at_approx'
        ? '제공처 예상 · 수집 시각 기준 근사'
        : '제공처 예상',
  _ => '예상 근거 미제공',
};

String dataReason(String code) => switch (code) {
  'location_not_received' => '현재 위치를 아직 받지 못했어요.',
  'location_stale' => '최근 위치가 없어 이동 평가는 제한돼요.',
  'onboard_vehicle_unconfirmed' => '탑승 차량을 확인하지 못해 도착·환승 예측이 제한돼요.',
  'onboard_alight_eta_unavailable' => '탑승 차량의 하차 도착정보가 없어요.',
  'eta_basis_unconfirmed' => '도착정보의 기준 시각을 확인하지 못했어요.',
  'next_boarding_eta_unavailable' => '다음 버스의 도착시간을 확인할 수 없어요.',
  'negative_slack' => '기준 도착시간으로는 연결 버스에 탑승하기 어려워요.',
  'confirmed_infeasible' => '현재 자료로는 이동 연결이 어려워요.',
  'access_walk_progress_unknown_full_duration_assumed' =>
    '도보 진행을 몰라 전체 도보시간으로 계산했어요.',
  'no_remaining_bus_leg' => '남은 버스 구간 없이 마지막 도보를 안내해요.',
  'service_area_unavailable' => '지원 범위를 판단할 자료가 부족해요.',
  'SEARCH_EXPIRED' => '검색 유효기간이 지났어요. 새로 검색해 주세요.',
  'CANDIDATE_NOT_STARTABLE' => '현재 시작할 수 없는 연결이에요.',
  'ranked_with_headway_estimate' => '배차간격으로 예상한 후보는 실시간 예측 후보 다음에 추천해요.',
  'headway_estimates_only' => '현재는 배차간격으로 예상한 경로만 비교할 수 있어요.',
  'later_headway_estimate_not_ranked' => '같은 경로의 더 이른 예상 차량을 먼저 추천해요.',
  'board_eta_by_headway_estimate' ||
  'alight_eta_by_headway_estimate' => '배차간격으로 예상한 도착시각이에요. 실제 운행과 다를 수 있어요.',
  'next_vehicle_not_departed' => '다음 차량은 아직 출발이 확인되지 않았어요.',
  'headway_reference_alight_absent' => '기준 차량의 하차시각이 없어 예상 하차시간을 계산하지 못했어요.',
  'board_eta_by_leading_vehicle_gap' ||
  'alight_eta_by_leading_vehicle_gap' => '앞차 도착정보와 차량 간격으로 추정한 시각이에요.',
  'alight_linked_by_vehicle_without_run_key' =>
    '운행 회차를 확인하지 못해 차량 식별자로 하차 정보를 연결했어요.',
  'pattern_shape_not_collected' => '이 운행 방향의 경로 형상은 아직 수집되지 않았어요.',
  'shape_route_not_in_provider' => '제공처에서 이 노선의 경로 형상을 찾지 못했어요.',
  'shape_stop_mapping_unavailable' ||
  'shape_stop_alignment_failed' ||
  'shape_segment_order_invalid' => '승하차 정류소와 경로 형상을 연결하지 못했어요.',
  'shape_not_provided' => '이 구간의 경로 형상이 제공되지 않았어요.',
  'shape_provider_not_configured' => '서버의 경로 형상 제공처 설정이 필요해요.',
  _ => '시간·차량·예측 근거 자료가 부족해 일부 평가를 확인할 수 없어요.',
};
