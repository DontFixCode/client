import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'data_reason.dart';

class BoardingEstimate extends StatelessWidget {
  const BoardingEstimate({
    super.key,
    required this.estimate,
    this.plannedLeg,
    this.enabled = true,
    required this.onConfirm,
    required this.onEdit,
  });

  final Json estimate;
  final Json? plannedLeg;
  final bool enabled;
  final ValueChanged<Json> onConfirm, onEdit;

  Json? _payload(Json? suggestion) {
    if (estimate['status'] != 'suggested' || suggestion == null) return null;
    final index = suggestion['legIndex'];
    final route = suggestion['routeId'];
    final pattern = suggestion['patternKey'];
    final direction = suggestion['directionCode'];
    final vehicle = suggestion['vehicleId'];
    if (suggestion['requiresUserConfirmation'] != true ||
        index is! int ||
        index < 0 ||
        (plannedLeg != null && index != plannedLeg!['legIndex']) ||
        route is! String ||
        !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(route) ||
        pattern is! String ||
        pattern.trim().isEmpty ||
        pattern.length > 200 ||
        (direction != null &&
            (direction is! String || direction.length > 20)) ||
        vehicle is! String ||
        vehicle.trim().isEmpty ||
        vehicle.length > 50) {
      return null;
    }
    return {
      'legIndex': index,
      'routeId': route,
      'patternKey': pattern,
      'directionCode': direction,
      'vehicleId': vehicle,
      'confirmation': 'user_confirmed',
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = estimate['status'];
    if (status == 'not_applicable') return const SizedBox.shrink();
    final suggestion = estimate['suggestion'] is Json
        ? estimate['suggestion'] as Json
        : null;
    final payload = _payload(suggestion);
    final suggested = status == 'suggested';
    final plannedRoute = plannedLeg?['route'];
    final sameRoute =
        suggestion != null &&
        plannedRoute is Map &&
        suggestion['routeId'] == plannedRoute['id'];
    final samePattern =
        sameRoute &&
        suggestion['patternKey'] == plannedLeg?['patternKey'] &&
        suggestion['directionCode'] == plannedLeg?['board']?['directionCode'];
    final evaluatedAt = DateTime.tryParse(
      estimate['evaluatedAt']?.toString() ?? '',
    )?.toLocal();
    final reasons = (estimate['reasonCodes'] as List? ?? [])
        .whereType<String>()
        .map(_reason)
        .toSet();
    return AppCard(
      color: suggested ? AppColors.primaryLight : AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (status) {
            'suggested' => '탑승 추정 차량을 찾았어요',
            'no_match' => '탑승 차량을 추정하지 못했어요',
            'insufficient_evidence' => '탑승 추정에 필요한 자료를 모으고 있어요',
            _ => '탑승 추정을 아직 확인할 수 없어요',
          }, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (suggested) ...[
            Text(
              '${sameRoute && plannedRoute['routeNo'] != null ? '${plannedRoute['routeNo']}번 · ' : ''}차량 ${suggestion?['vehicleId'] ?? '미확인'}',
            ),
            const SizedBox(height: 8),
            const Text('위치와 버스 이동을 비교한 추정이에요. 실제로 탑승한 노선·방향·차량인지 확인해 주세요.'),
            if (estimate['confidence'] == 'high' ||
                estimate['confidence'] == 'possible')
              Text(
                '추정 신뢰도: ${estimate['confidence'] == 'high' ? '높음' : '가능성 있음'} · 사용자 확인 필요',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (plannedLeg != null && !samePattern)
              const Text('계획한 노선·방향과 다를 수 있어요. 실제 버스를 확인해 주세요.'),
            if (payload == null)
              const Text('추정 차량 정보가 불완전하거나 현재 승차 구간과 달라요. 버스를 직접 확인해 주세요.'),
          ] else if (reasons.isEmpty)
            const Text('아직 탑승을 추정할 자료가 없어요. 실제 탑승한 버스는 직접 확인할 수 있어요.'),
          for (final reason in reasons) Text(reason),
          if (evaluatedAt != null)
            Text(
              '추정 시각: ${clockLabel(evaluatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (suggested) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: enabled && payload != null
                      ? () => onConfirm(payload)
                      : null,
                  child: const Text('이 버스에 탑승했어요'),
                ),
                TextButton(
                  onPressed: enabled ? () => onEdit(payload ?? {}) : null,
                  child: const Text('탑승 버스 직접 확인·수정'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _reason(String code) => switch (code) {
    'need_consecutive_accurate_locations' =>
      '연속된 정확한 위치가 더 필요해요. 위치 전송을 켜고 이동하면 다시 비교해요.',
    'location_stale' => '최근 위치가 없어 탑승을 추정할 수 없어요. 현재 위치 전송 상태를 확인해 주세요.',
    'vehicle_positions_unavailable' => '비교할 버스 위치 정보가 아직 없어요.',
    'no_vehicle_trajectory_match' => '현재 이동과 맞는 버스가 확인되지 않았어요.',
    _ => '탑승 추정에 필요한 자료가 부족해요. 실제 탑승한 버스를 직접 확인해 주세요.',
  };
}
