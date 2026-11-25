import 'package:flutter/material.dart';

import '../../data/bus_api.dart';
import '../../models/travel_route.dart';
import '../../state/app_state.dart';
import 'api_action.dart';
import 'app_card.dart';
import 'data_reason.dart';

class TransferResults extends StatelessWidget {
  const TransferResults({super.key, required this.journey, this.onUpdated});

  final Json journey;
  final ValueChanged<Json>? onUpdated;

  Future<void> _perform(
    BuildContext context,
    Future<Json?> Function(AppState state) action,
  ) async {
    final state = AppScope.of(context);
    Json? updated;
    await apiAction(context, () async {
      try {
        updated = await action(state);
      } on ApiException catch (error) {
        if (onUpdated != null && error.status == 409) {
          try {
            updated = await state.api.request(
              'GET',
              '/journeys/${Uri.encodeComponent(journey['journeyId'] as String)}',
            );
          } catch (_) {
            // 기존 결과를 유지하고 다음 조회에서 복구합니다.
          }
        }
        rethrow;
      }
    });
    if (context.mounted && updated != null) onUpdated?.call(updated!);
  }

  Future<void> _edit(BuildContext context, Json transfer) async {
    final previous = transfer['result'] as Json?;
    String? result = previous?['value'] as String?;
    var connection = 'keep';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${transfer['transferIndex']}번째 환승 결과'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('실제로 확인한 결과를 알려 주세요. 잘 모르겠다면 확인 불가로 남길 수 있어요.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: result,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '환승 결과'),
                  items: const [
                    DropdownMenuItem(value: 'success', child: Text('환승 성공')),
                    DropdownMenuItem(value: 'failure', child: Text('환승 실패')),
                    DropdownMenuItem(value: 'unknown', child: Text('확인 불가')),
                  ],
                  onChanged: (value) => setState(() => result = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: connection,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '이용한 버스 연결'),
                  items: [
                    DropdownMenuItem(
                      value: 'keep',
                      child: Text(previous == null ? '따로 지정하지 않음' : '기존 정보 유지'),
                    ),
                    const DropdownMenuItem(
                      value: 'planned',
                      child: Text('계획한 버스 연결 이용'),
                    ),
                    const DropdownMenuItem(
                      value: 'other',
                      child: Text('다른 버스 연결 이용'),
                    ),
                  ],
                  onChanged: (value) => setState(() => connection = value!),
                ),
                const SizedBox(height: 12),
                const Text('다른 연결을 이용한 결과는 당시 경로의 예측과 대조하지 않아요.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: result == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('결과 저장'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _perform(
      context,
      (state) => state.submitTransferResult(
        journey,
        transfer,
        result: result!,
        usedPlanned: switch (connection) {
          'planned' => true,
          'other' => false,
          _ => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = journey['lifecycleStatus'] == 'active';
    final selection = journey['selectionVersion'];
    bool previousRoute(Json transfer) =>
        selection is int &&
        transfer['selectionVersion'] is int &&
        transfer['selectionVersion'] != selection;
    final transfers = (journey['transferResults'] as List? ?? [])
        .cast<Json>()
        .where(
          (transfer) =>
              !active || !previousRoute(transfer) || transfer['result'] != null,
        );
    final completed =
        journey['currentProgress']?['completedBusLegs'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('실제 환승 결과', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('이동 시작 때 저장한 예측과 실제 결과를 함께 확인해요.'),
        if (transfers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('저장된 환승 예측이 없어 결과를 입력할 항목이 없어요.'),
          ),
        if (onUpdated != null &&
            state.hasPendingEvent &&
            state.pendingEventJourneyId == journey['journeyId'])
          TextButton(
            onPressed: state.busy
                ? null
                : () => _perform(context, (state) => state.retryPendingEvent()),
            child: const Text('전송 결과 다시 확인'),
          ),
        for (final transfer in transfers)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${transfer['transferIndex']}번째 환승${previousRoute(transfer) ? ' · 이전 경로' : ''}',
                  ),
                  Text(
                    '당시 예측: ${_probability(transfer['prediction']?['probability'])} · 여유 ${secondsLabel(transfer['prediction']?['slackSeconds'])}',
                  ),
                  Text(
                    '예측 저장 시각: ${_date(transfer['prediction']?['fixedAt'])}',
                  ),
                  const SizedBox(height: 8),
                  Text('기록한 결과: ${_result(transfer['result']?['value'])}'),
                  Text(switch (transfer['evaluationStatus']) {
                    'counted' => '당시 예측과 대조할 결과로 기록했어요.',
                    'excluded' => '이 결과는 당시 예측과의 대조에서 제외됐어요.',
                    'unknown' => '확인 불가로 기록했어요.',
                    _ => '아직 결과를 입력하지 않았어요.',
                  }),
                  if (transfer['result'] == null &&
                      journey['lifecycleStatus'] == 'active' &&
                      !completed.contains(transfer['frontLegIndex']))
                    const Text('앞 버스에서 하차한 뒤 입력할 수 있어요.'),
                  TextButton(
                    onPressed:
                        state.busy ||
                            state.hasPendingEvent ||
                            (transfer['result'] == null &&
                                journey['lifecycleStatus'] == 'active' &&
                                !completed.contains(transfer['frontLegIndex']))
                        ? null
                        : () => _edit(context, transfer),
                    child: Text(transfer['result'] == null ? '결과 입력' : '결과 수정'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _result(dynamic value) => switch (value) {
  'success' => '환승 성공',
  'failure' => '환승 실패',
  'unknown' => '확인 불가',
  _ => '미입력',
};
String _probability(dynamic value) {
  final percent = probabilityPercent(value);
  return percent == null ? '확률 확인 불가' : '$percent%';
}

String _date(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')
        ?.toLocal()
        .toString()
        .split('.')
        .first ??
    '확인 불가';
