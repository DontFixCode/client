import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../../models/place.dart';
import '../../models/travel_route.dart';
import '../../state/app_state.dart';
import '../pages/search/place_search_page.dart';
import 'api_action.dart';
import 'app_card.dart';
import 'data_reason.dart';

class JourneyRerouting extends StatelessWidget {
  const JourneyRerouting({super.key});

  bool _available(AppState state) =>
      state.journey?['lifecycleStatus'] == 'active' &&
      !state.busy &&
      !state.hasPendingEvent &&
      !state.journeyRouteSyncing &&
      state.guidance?['alternativesReason'] !=
          'phase5_reevaluation_not_implemented';

  bool _unchanged(AppState state, String? id, Object? version) =>
      _available(state) &&
      state.journeyId == id &&
      state.journey?['stateVersion'] == version;

  Json? _nextLeg(AppState state) => state.activeRoute?.busLegs
      .where((leg) => leg['legIndex'] == state.progress['nextBusLegIndex'])
      .firstOrNull;

  String? _vehicle(AppState state, Json leg) {
    final next = state.guidance?['nextBoarding'];
    if (next is! Map ||
        next['legIndex'] != leg['legIndex'] ||
        (next['routeId'] != null && next['routeId'] != leg['route']?['id']) ||
        (next['patternKey'] != null &&
            next['patternKey'] != leg['patternKey'])) {
      return null;
    }
    final id = next['vehicle']?['vehicleId'];
    return id is String && id.trim().isNotEmpty && id.length <= 50
        ? id.trim()
        : null;
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _missed(BuildContext context, AppState state, Json leg) async {
    final id = state.journeyId;
    final version = state.journey?['stateVersion'];
    final vehicle = _vehicle(state, leg);
    final yes = await _confirm(
      context,
      title: '${leg['route']?['routeNo'] ?? ''}번 버스를 놓쳤나요?',
      message: vehicle == null
          ? '차량 번호를 확인하지 못했어요. 계획 차량을 놓친 것으로 기록하고 다음 연결을 다시 확인해요.'
          : '안내 차량 $vehicle을 실제로 놓쳤는지 확인해 주세요. 이 차량을 제외하고 다음 연결을 다시 확인해요.',
      action: '놓침 확인',
    );
    if (!yes || !context.mounted) return;
    if (!_unchanged(state, id, version) ||
        state.journey?['movementState'] == 'onboard' ||
        _nextLeg(state)?['legIndex'] != leg['legIndex'] ||
        _vehicle(state, leg) != vehicle) {
      _changed(context);
      return;
    }
    await apiAction(
      context,
      () => state.sendJourneyEvent('missed_bus', {
        'legIndex': leg['legIndex'],
        'vehicleId': vehicle,
      }),
    );
  }

  Future<void> _destination(BuildContext context, AppState state) async {
    final id = state.journeyId;
    final version = state.journey?['stateVersion'];
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => const PlaceSearchPage(isOrigin: false)),
    );
    if (place == null || !context.mounted) return;
    if (!_unchanged(state, id, version)) {
      _changed(context);
      return;
    }
    if (!place.hasCoordinates) return;
    final yes = await _confirm(
      context,
      title: '목적지 변경을 요청할까요?',
      message:
          '${place.name}까지의 경로를 요청해요. 새 경로는 제안을 수락한 뒤 적용돼요.'
          '${state.journey?['movementState'] == 'onboard' ? '\n탑승 중인 구간은 유지하고, 하차 확인 후 새 경로를 찾아요.' : '\n최근 위치가 필요하면 현재 위치 전송 버튼을 눌러 주세요.'}',
      action: '변경 요청',
    );
    if (!yes || !context.mounted) return;
    if (!_unchanged(state, id, version)) {
      _changed(context);
      return;
    }
    final sent = await apiAction(
      context,
      () => state.sendJourneyEvent('destination_changed', place.toJson()),
    );
    if (sent && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${place.name}까지의 새 경로를 요청했어요.')));
    }
  }

  bool _currentProposal(AppState state, Json proposal) =>
      proposal['proposalVersion'] is int &&
      (proposal['proposalVersion'] as int) > 0 &&
      proposal['candidateId'] is String &&
      proposal['proposalVersion'] == state.journey?['selectionVersion'] &&
      proposal['baseStateVersion'] == state.journey?['stateVersion'];

  Future<void> _respond(
    BuildContext context,
    AppState state,
    Json proposal, {
    required bool accept,
  }) async {
    final id = state.journeyId;
    final version = state.journey?['stateVersion'];
    final resultVersion = state.journey?['resultVersion'];
    final yes = await _confirm(
      context,
      title: accept ? '제안 경로로 바꿀까요?' : '이 제안을 거절할까요?',
      message: accept
          ? '이미 이동한 구간은 유지하고 남은 경로를 제안대로 바꿔요.'
          : '현재 선택한 경로를 유지해요. 목적지를 변경 요청했다면 새 경로가 적용된 것은 아니에요.',
      action: accept ? '경로 변경' : '제안 거절',
    );
    if (!yes || !context.mounted) return;
    final current = state.journey?['proposedRoute'] as Json?;
    if (!_unchanged(state, id, version) ||
        current == null ||
        !_currentProposal(state, current) ||
        current['proposalVersion'] != proposal['proposalVersion'] ||
        current['candidateId'] != proposal['candidateId'] ||
        current['evaluatedAt'] != proposal['evaluatedAt'] ||
        state.journey?['resultVersion'] != resultVersion ||
        (accept && state.journey?['movementState'] == 'onboard')) {
      _changed(context);
      return;
    }
    await apiAction(
      context,
      () => state.sendJourneyEvent(
        accept ? 'route_accepted' : 'route_rejected',
        {'proposalVersion': proposal['proposalVersion']},
      ),
    );
  }

  void _changed(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(
        const SnackBar(content: Text('안내가 갱신됐어요. 현재 정보를 확인하고 다시 선택해 주세요.')),
      );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.journey == null) return const SizedBox.shrink();
    final onboard = state.journey?['movementState'] == 'onboard';
    final leg = _nextLeg(state);
    final proposal = state.journey?['proposedRoute'] as Json?;
    final valid = proposal != null && _currentProposal(state, proposal);
    final reason = state.guidance?['alternativesReason'] as String?;
    final remaining = (proposal?['legs'] as List? ?? [])
        .whereType<Json>()
        .where(
          (leg) =>
              leg['kind'] == 'bus' &&
              !(state.progress['completedBusLegs'] as List? ?? []).contains(
                leg['legIndex'],
              ),
        );
    final seconds = proposal == null
        ? null
        : proposal['rankingMode'] == 'expected'
        ? proposal['expectedTotalSeconds']
        : proposal['nominalTotalSeconds'];
    final improvement = proposal?['changeDecision']?['improvementSeconds'];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이동 중 경로 변경', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _available(state) && !onboard && leg != null
                      ? () => _missed(context, state, leg)
                      : null,
                  child: const Text('버스를 놓쳤어요'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _available(state)
                      ? () => _destination(context, state)
                      : null,
                  child: const Text('목적지 변경'),
                ),
              ),
            ],
          ),
          if (onboard) const Text('탑승 중인 구간은 유지해요. 하차 확인 후 제안 경로로 바꿀 수 있어요.'),
          const SizedBox(height: 8),
          if (proposal != null) ...[
            Text('대체 경로 제안', style: Theme.of(context).textTheme.titleSmall),
            if (proposal['destination']?['name'] case final String name)
              Text('제안 목적지: $name'),
            for (final bus in remaining)
              Text(
                '${bus['routeNo'] ?? '번호 미제공'}번 · ${bus['board']?['name'] ?? '승차 정류소'} → ${bus['alight']?['name'] ?? '하차 정류소'}',
              ),
            Text(
              seconds is num && seconds.isFinite
                  ? '남은 예상 시간 ${minutesFromSeconds(seconds)}분'
                  : '남은 예상 시간 확인 불가',
            ),
            if (improvement is num && improvement.isFinite && improvement > 0)
              Text('현재 경로보다 약 ${minutesFromSeconds(improvement)}분 단축 예상'),
            const Text('수락하기 전까지 현재 경로를 유지해요.'),
            if (!valid) const Text('상태가 바뀌어 제안을 다시 확인하고 있어요.'),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _available(state) && valid && !onboard
                      ? () => _respond(context, state, proposal, accept: true)
                      : null,
                  child: const Text('제안 수락'),
                ),
                TextButton(
                  onPressed: _available(state) && valid
                      ? () => _respond(context, state, proposal, accept: false)
                      : null,
                  child: const Text('현재 경로 유지'),
                ),
              ],
            ),
          ] else
            Text(
              state.guidance == null
                  ? '경로 변경 정보를 갱신하고 있어요.'
                  : reason == null || reason == 'not_evaluated'
                  ? '현재 위치와 버스 정보를 바탕으로 대체 경로를 확인해요.'
                  : dataReason(reason),
            ),
        ],
      ),
    );
  }
}
