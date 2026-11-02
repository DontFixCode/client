import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../models/journey_record.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_pill.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  String _date(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _delete(
    BuildContext context,
    AppState state,
    JourneyRecord record,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이동 기록을 삭제할까요?'),
        content: Text(
          '${record.route.origin.name} → ${record.route.destination.name}\n삭제한 기록은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (delete == true && context.mounted) {
      state.deleteRecord(record.id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이동 기록을 삭제했어요.')));
    }
  }

  Future<void> _details(
    BuildContext context,
    AppState state,
    JourneyRecord record,
  ) async {
    final route = record.route;
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('이용기록', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  _outcome(record),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_date(record.completedAt)} ${_time(record.completedAt)} 완료',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              AppCard(
                color: AppColors.primaryLight,
                borderColor: AppColors.primaryLight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.origin.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Icon(
                        Icons.south_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      route.destination.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _detailRow(
                '이용 버스',
                route.busNumbers.map((bus) => '$bus번').join(' → '),
              ),
              _detailRow('예상 이동시간', '${route.minutes}분'),
              _detailRow('도보', '${route.walkMinutes}분'),
              _detailRow(
                '환승',
                route.transfers == 0
                    ? '없음'
                    : '${route.transfers}회 · ${route.transferStop}',
              ),
              if (route.transfers > 0)
                _detailRow('직접 입력한 결과', record.outcome.label),
              const SizedBox(height: 20),
              const DemoNotice(message: '체험용 이동 기록 · 실제 이동시간이 아니에요'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('이 기록 삭제하기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (delete == true && context.mounted) {
      await _delete(context, state, record);
    }
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _outcome(JourneyRecord record) {
    if (record.route.transfers == 0) {
      return const StatusPill(
        '환승 없음',
        color: AppColors.blue,
        background: AppColors.blueLight,
      );
    }
    return StatusPill(
      record.outcome.label,
      color: record.outcome == JourneyOutcome.success
          ? AppColors.primary
          : record.outcome == JourneyOutcome.missed
          ? AppColors.amber
          : AppColors.muted,
      background: record.outcome == JourneyOutcome.success
          ? AppColors.primaryLight
          : record.outcome == JourneyOutcome.missed
          ? AppColors.amberLight
          : AppColors.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final records = state.history;
    return Scaffold(
      appBar: AppBar(
        title: const Text('이용기록'),
        automaticallyImplyLeading: false,
      ),
      body: records.isEmpty
          ? EmptyState(
              icon: Icons.route_rounded,
              title: '우리의 첫 번째 이동을 기다려요',
              message: '이동 안내를 완료하면\n지나온 길과 환승 결과를 여기서 볼 수 있어요.\n체험 기록은 앱 실행 중에만 보관돼요.',
              action: FilledButton.icon(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.main,
                  (_) => false,
                ),
                icon: const Icon(Icons.search_rounded, size: 19),
                label: const Text('새로운 길 찾아보기'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              itemCount: records.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '차곡차곡 쌓이는\n나의 버스 여행',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '총 ${records.length}번의 이동을 함께했어요.',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 16),
                        const DemoNotice(message: '체험 기록 · 앱을 종료하면 초기화돼요'),
                      ],
                    ),
                  );
                }
                final record = records[index - 1];
                final route = record.route;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: AppCard(
                    onTap: () => _details(context, state, record),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_date(record.completedAt)} · ${_time(record.completedAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            _outcome(record),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.directions_bus_rounded,
                                size: 23,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${route.origin.name} → ${route.destination.name}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${route.minutes}분 · ${route.transfers == 0 ? '환승 없음' : '환승 ${route.transfers}회'} · ${route.busNumbers.join(' → ')}',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
