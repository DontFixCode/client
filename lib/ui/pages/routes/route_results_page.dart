import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/route_card.dart';

class RouteResultsPage extends StatefulWidget {
  const RouteResultsPage({super.key});
  @override
  State<RouteResultsPage> createState() => _RouteResultsPageState();
}

class _RouteResultsPageState extends State<RouteResultsPage> {
  int _sort = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final routes = List<TravelRoute>.of(state.routeOptions);
    if (_sort == 1) routes.sort((a, b) => a.minutes.compareTo(b.minutes));
    if (_sort == 2) {
      routes.sort((a, b) {
        final transfers = a.transfers.compareTo(b.transfers);
        return transfers == 0 ? a.minutes.compareTo(b.minutes) : transfers;
      });
    }
    final samePlace = state.destination?.id == state.origin.id;
    return Scaffold(
      appBar: AppBar(title: const Text('경로 비교')),
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
                        ? '출발지와 도착지를 다시 확인해 주세요.'
                        : '나에게 맞는 이동을 선택해 보세요.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
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
            Expanded(
              child: routes.isEmpty
                  ? EmptyState(
                      icon: samePlace
                          ? Icons.trip_origin_rounded
                          : Icons.location_off_outlined,
                      title: samePlace ? '출발지와 도착지가 같아요' : '아직 안내할 수 없는 구간이에요',
                      message: samePlace
                          ? '다른 도착지를 선택하면\n이동 경로를 비교할 수 있어요.'
                          : '체험은 대전의 주요 장소 사이에서 가능해요.\n출발지와 도착지를 바꿔 다시 찾아보세요.',
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
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: DemoNotice(
                                message: '예시 노선·시간·확률이며 실제 운행정보가 아니에요',
                              ),
                            )
                          : RouteCard(
                              route: routes[index],
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.routeDetail,
                                arguments: routes[index],
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
