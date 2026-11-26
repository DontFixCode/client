import 'package:flutter/material.dart';

import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/data_reason.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/route_card.dart';
import 'route_preview_page.dart';

class RouteResultsPage extends StatefulWidget {
  const RouteResultsPage({super.key});
  @override
  State<RouteResultsPage> createState() => _RouteResultsPageState();
}

class _RouteResultsPageState extends State<RouteResultsPage> {
  int _sort = 0;
  AppState? _state;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state == null) {
      _state = AppScope.of(context);
      if (!_state!.demoMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _state!.searchRoutes();
        });
      }
    }
  }

  @override
  void dispose() {
    _state?.stopSearchPolling();
    super.dispose();
  }

  int _time(TravelRoute a, TravelRoute b) =>
      (a.minutes ?? 0x7fffffff).compareTo(b.minutes ?? 0x7fffffff);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final routes = List<TravelRoute>.of(state.routeOptions);
    if (_sort == 1) routes.sort((a, b) => _time(a, b));
    if (_sort == 2) {
      routes.sort((a, b) {
        final transfers = a.transfers.compareTo(b.transfers);
        return transfers == 0 ? _time(a, b) : transfers;
      });
    }
    final samePlace = state.destination?.id == state.origin.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 비교'),
        actions: [
          if (!state.demoMode)
            IconButton(
              tooltip: '새로 검색',
              onPressed: state.searchLoading ? null : state.searchRoutes,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          state.origin.name,
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          state.destination?.name ?? '도착지 미선택',
                          style: Theme.of(context).textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    routes.isEmpty
                        ? '검색 결과와 안내를 확인해 주세요.'
                        : '나에게 맞는 이동을 선택해 보세요.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(['추천순', '빠른순', '환승 적은순'][i]),
                              selected: _sort == i,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _sort = i),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _sort == i
                                    ? AppColors.primaryDark
                                    : AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!state.demoMode && state.searchResult != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  _searchMessage(state),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            Expanded(
              child: !state.demoMode && state.searchLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !state.demoMode &&
                        (state.searchError != null || routes.isEmpty)
                  ? EmptyState(
                      icon: Icons.route_outlined,
                      title: state.searchError != null
                          ? '경로 검색을 완료하지 못했어요'
                          : '검색 결과 안내',
                      message: state.searchError ?? _searchMessage(state),
                      action: FilledButton(
                        onPressed: state.searchResult?['status'] == 'processing'
                            ? state.refreshSearch
                            : state.searchRoutes,
                        child: Text(
                          state.searchResult?['status'] == 'processing'
                              ? '결과 다시 확인'
                              : '다시 검색',
                        ),
                      ),
                    )
                  : routes.isEmpty
                  ? EmptyState(
                      icon: samePlace
                          ? Icons.trip_origin_rounded
                          : Icons.location_off_outlined,
                      title: samePlace ? '출발지와 도착지가 같아요' : '아직 안내할 수 없는 구간이에요',
                      message: samePlace
                          ? '다른 도착지를 선택하면\n이동 경로를 비교할 수 있어요.'
                          : '출발지와 도착지를 바꿔\n다시 찾아보세요.',
                      action: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('장소 다시 선택하기'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: routes.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => index == routes.length
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: DemoNotice(
                                message: state.demoMode
                                    ? '예시 노선·시간·확률이며 실제 운행정보가 아니에요'
                                    : '확률은 특정 연결 버스의 시간상 탑승 가능성이에요. 자료가 없으면 확인 불가로 표시해요.',
                              ),
                            )
                          : RouteCard(
                              route: routes[index],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RoutePreviewPage(
                                    routes: routes,
                                    initialIndex: index,
                                  ),
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

String _searchMessage(AppState state) {
  final result = state.searchResult;
  if (result?['expired'] == true) return '검색 유효기간이 지났어요. 새로 검색해 주세요.';
  final message = switch (result?['status']) {
    'processing' => '서버에서 경로를 계산하고 있어요. 잠시 후 결과를 다시 확인해 주세요.',
    'data_limited' => '자료가 부족해 일부 시간·확률 또는 지원 범위를 확인할 수 없어요.',
    'no_path' => '설정된 탐색 범위 안에서 경로를 찾지 못했어요.',
    'out_of_scope' => '출발지 또는 도착지가 지원 구간 밖이에요.',
    'error' => '서버에서 검색을 완료하지 못했어요. 다시 검색해 주세요.',
    'ready' => '서버에서 계산한 경로예요.',
    _ => '출발지와 도착지를 확인해 주세요.',
  };
  final coverage = result?['coverage'];
  final truncated =
      coverage?['searchTruncated'] == true ||
      coverage?['evaluationTruncated'] == true;
  final reasons = List<String>.from(result?['reasonCodes'] ?? [])
      .where(
        (code) =>
            code == 'headway_estimates_only' ||
            code == 'ranked_with_headway_estimate',
      )
      .map(dataReason)
      .toSet();
  return [
    '$message${truncated ? ' 탐색이 일부 제한되어 전체 최적 경로를 보장하지 않아요.' : ''}',
    ...reasons,
  ].join('\n');
}
