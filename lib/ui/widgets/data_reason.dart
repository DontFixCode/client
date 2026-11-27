import '../../data/bus_api.dart';

String secondsLabel(dynamic value) =>
    value is num && value.isFinite ? '${value.round()}초' : '확인 불가';

String slackLabel(dynamic value) {
  if (value is! num || !value.isFinite) return '확인 불가';
  if (value < 0) return '버스를 놓칠 수 있어요';
  return '${(value / 60).floor()}분';
}

String clockLabel(dynamic value) {
  final time = value is DateTime
      ? value.toLocal()
      : DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (time == null) return '확인 불가';
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String etaSourceLabel(Json eta) => switch (eta['etaSource']) {
  'headway_estimate' => '배차간격으로 예상한 시간',
  'leading_vehicle_gap' => '앞차 기준으로 예상한 시간',
  'historical_segments' => '과거 기록으로 예상한 시간',
  'provider' =>
    eta['basisSource'] == 'server_received_at_approx'
        ? '실시간 도착정보 · 대략적인 시각'
        : '실시간 도착정보',
  _ => '예상 근거 없음',
};

String dataReason(String code) => switch (code) {
  'location_not_received' => '현재 위치를 아직 받지 못했어요.',
  'location_stale' => '최근 위치가 없어 이동 평가는 제한돼요.',
  'onboard_vehicle_unconfirmed' => '탑승 차량을 확인하지 못해 도착·환승 예측이 제한돼요.',
  'onboard_alight_eta_unavailable' => '탑승 차량의 하차 도착정보가 없어요.',
  'eta_basis_unconfirmed' => '도착정보의 기준 시각을 확인하지 못했어요.',
  'next_boarding_eta_unavailable' => '다음 버스의 도착시간을 확인할 수 없어요.',
  'next_boarding_no_catchable_vehicle' => '정류소에 도착한 뒤 탈 수 있는 차량을 아직 확인하지 못했어요.',
  'negative_slack' => '기준 도착시간으로는 연결 버스에 탑승하기 어려워요.',
  'confirmed_infeasible' => '현재 자료로는 이동 연결이 어려워요.',
  'access_walk_progress_unknown_full_duration_assumed' =>
    '도보 진행을 몰라 전체 도보시간으로 계산했어요.',
  'access_walk_progress_assumed_from_elapsed_time' =>
    '걷기 시작한 뒤 지난 시간을 반영해 정류소 도착시각을 예상했어요.',
  'no_remaining_bus_leg' => '남은 버스 구간 없이 마지막 도보를 안내해요.',
  'fresh_location_required_for_destination_change' ||
  'fresh_location_required_after_alight' =>
    '새 목적지까지 검색하려면 최근 위치가 필요해요. 현재 위치 전송을 눌러 주세요.',
  'confirmed_onboard_segment_fixed_until_alight' =>
    '탑승 중인 구간을 계속 안내해요. 하차 확인 후 새 경로를 찾을 수 있어요.',
  'destination_reroute_pending' => '새 목적지까지의 경로를 계산하고 있어요.',
  'missed_bus_reroute_pending' =>
    '놓친 차량을 제외하고 새 경로를 찾고 있어요. 기존 경로의 다음 버스 안내는 계속돼요.',
  'destination_reroute_preview_until_alight' =>
    '계획 하차 정류소에서 이어 갈 경로를 미리 보여 드려요. 하차 확인 후 실제 내린 정류소와 시각으로 다시 찾아요.',
  'destination_changed_route_proposed' => '새 목적지에 가장 일찍 도착할 것으로 예상한 경로예요.',
  'destination_changed_route_proposed_time_unconfirmed' =>
    '새 목적지까지의 경로를 찾았지만 도착시각은 아직 확인하지 못했어요.',
  'destination_changed_arrival_follows_new_route' =>
    '새 목적지의 도착 예상은 변경 경로를 기준으로 확인해 주세요.',
  'current_route_arrival_unconfirmed_alternative_available' =>
    '현재 경로의 도착시각은 불확실하지만 도착 예상이 있는 대체 경로를 찾았어요.',
  'alternative_has_lower_comparable_cost' => '현재 경로보다 일찍 도착할 것으로 예상한 경로예요.',
  'reroute_start_from_planned_alight_eta' => '계획된 하차 예상시각을 기준으로 이어 갈 경로를 찾았어요.',
  'reroute_start_time_unconfirmed_until_alight' =>
    '하차시각을 확인하지 못해 이어 갈 경로의 소요시간은 아직 확정할 수 없어요.',
  'arrival_from_reroute_search_evaluation' => '재검색 당시의 도착 예상시각을 사용했어요.',
  'arrival_from_reevaluated' => '최근 자료로 도착 예상시각을 다시 계산했어요.',
  'current_route_not_comparable_for_destination' =>
    '새 목적지까지 현재 경로와 비교할 수 있는 자료가 없어 경로를 유지해요.',
  'destination_reroute_no_candidates' => '새 목적지까지 이용할 수 있는 새 경로를 찾지 못했어요.',
  'destination_reroute_no_usable_candidate' =>
    '새 목적지까지 지금 이용할 수 있는 경로를 찾지 못했어요.',
  'missed_bus_reroute_no_candidates' => '버스를 놓친 뒤 이용할 수 있는 새 경로를 찾지 못했어요.',
  'destination_reroute_search_missing' ||
  'missed_bus_reroute_search_missing' => '재검색 결과를 불러올 수 없어요.',
  'destination_reroute_search_failed' ||
  'missed_bus_reroute_search_failed' => '새 경로를 검색하는 중 오류가 발생했어요.',
  'destination_reroute_not_queued' ||
  'missed_bus_reroute_not_queued' ||
  'search_settings_unavailable' ||
  'route_search_unavailable' => '새 경로 검색을 시작하지 못했어요.',
  'current_route_not_comparable' =>
    '현재 경로의 전체 시간이나 연결 정보를 확인하지 못해 대안과 비교할 수 없어요.',
  'current_route_not_evaluated' => '현재 경로를 아직 평가하지 못해 대안과 비교할 수 없어요.',
  'no_comparable_alternative' => '현재 경로와 비교할 수 있는 대체 경로가 없어요.',
  'current_route_not_slower' ||
  'improvement_below_or_equal_threshold' => '현재 경로를 유지하는 편이 좋아요.',
  'phase5_reevaluation_not_implemented' => '현재 서버에서는 이동 중 경로 변경을 지원하지 않아요.',
  'service_area_unavailable' => '지원 범위를 판단할 자료가 부족해요.',
  'SEARCH_EXPIRED' => '검색 유효기간이 지났어요. 새로 검색해 주세요.',
  'CANDIDATE_NOT_STARTABLE' => '현재 시작할 수 없는 연결이에요.',
  'ranked_with_headway_estimate' => '배차간격으로 예상한 후보는 실시간 예측 후보 다음에 추천해요.',
  'headway_estimates_only' => '현재는 배차간격으로 예상한 경로만 비교할 수 있어요.',
  'congestion_bias_applied' => '예상 혼잡도를 추천 순위에 반영했어요.',
  'board_eta_from_selection_snapshot' => '선택 당시 계획 차량의 도착시각으로 예상했어요.',
  'board_eta_after_passed_vehicle_by_headway' => '지나간 차량의 도착시각과 배차간격으로 예상했어요.',
  'transfer_probability_by_marginal_errors' => '두 차량의 도착 오차 표본을 결합했어요.',
  'marginal_error_samples_insufficient' => '차량별 도착 오차 표본이 부족해요.',
  'marginal_error_source_unsupported' => '이 예측 방식에 사용할 도착 오차 표본이 없어요.',
  'marginal_error_source_approximated' => '실시간 도착정보의 오차 표본으로 근사했어요.',
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
