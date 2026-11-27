import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../data/demo_data.dart';
import '../../../models/place.dart';
import '../../../models/stop_arrival.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/bus_logo.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/route_map.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';
import '../search/place_search_page.dart';
import '../transit/transit_page.dart';
import '../../widgets/api_action.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _locationScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationScheduled) return;
    _locationScheduled = true;
    final state = AppScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(state.locateOrigin());
    });
  }

  void _findRoute(BuildContext context, Place place) {
    AppScope.of(context).setDestination(place);
    Navigator.pushNamed(context, AppRoutes.results);
  }

  Future<void> _pickPlace(BuildContext context, bool isOrigin) async {
    final state = AppScope.of(context);
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => PlaceSearchPage(isOrigin: isOrigin)),
    );
    if (place == null || !context.mounted) return;
    if (isOrigin) {
      state.setOrigin(place);
    } else {
      state.setDestination(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final arrivals = DemoData.stopArrivals;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BusLogo(size: 32),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '대전',
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        tooltip: '알림 안내',
                        onPressed: () => _showNotifications(context),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    state.isLoggedIn
                        ? '${state.userName}님, 반가워요'
                        : '반가워요, 오늘은 어디로 가세요?',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '오늘도 편하게 갈아타슈.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '환승 가능성과 여유 시간을 함께 확인해요.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            const Icon(
                              Icons.radio_button_checked_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            Container(
                              width: 1,
                              height: 35,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              color: AppColors.border,
                            ),
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              _PlaceField(
                                label: '출발',
                                value:
                                    state.locatingOrigin &&
                                        state.origin.id == 'unset'
                                    ? '현재 위치를 찾는 중…'
                                    : state.origin.name,
                                onTap: () => _pickPlace(context, true),
                              ),
                              const Divider(),
                              _PlaceField(
                                label: '도착',
                                value: state.destination?.name,
                                onTap: () => _pickPlace(context, false),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '출발지와 도착지 바꾸기',
                          onPressed: state.destination == null
                              ? null
                              : state.swapPlaces,
                          icon: const Icon(
                            Icons.swap_vert_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.origin.id == 'unset' &&
                      state.originLocationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.originLocationError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => state.locateOrigin(retry: true),
                            child: const Text('다시 찾기'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('searchRoutesButton'),
                      onPressed: () {
                        if (state.destination == null) {
                          _pickPlace(context, false);
                          return;
                        }
                        Navigator.pushNamed(context, AppRoutes.results);
                      },
                      icon: const Icon(Icons.search_rounded, size: 20),
                      label: const Text('버스 경로 찾기'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    '자주 가는 곳',
                    action: '관리',
                    onAction: () => _pickPlace(context, false),
                  ),
                  const SizedBox(height: 10),
                  if (state.favoritePlaces.isEmpty)
                    AppCard(
                      onTap: () => _pickPlace(context, false),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.bookmark_add_outlined,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '검색한 장소를 즐겨찾기에 담아보세요',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 105,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.favoritePlaces.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final place = state.favoritePlaces[index];
                          return SizedBox(
                            width: 158,
                            child: AppCard(
                              onTap: () => _findRoute(context, place),
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        place.category == '공원'
                                            ? Icons.park_outlined
                                            : Icons.school_outlined,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        Icons.north_east_rounded,
                                        size: 14,
                                        color: AppColors.muted,
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    place.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    place.category,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 25),
                  if (!state.demoMode) ...[
                    AppCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const TransitPage(),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.directions_bus_outlined,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '정류소·노선 정보',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '주변 정류소, 도착정보, 노선 경유 순서 조회',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!state.authConfigured)
                      const Text(
                        '인증 서버 연결 설정이 필요해요. 실행 설정을 확인해 주세요.',
                        style: TextStyle(color: AppColors.error),
                      ),
                    if (!state.isLoggedIn)
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.login),
                        child: const Text('로그인하고 서버 기능 이용하기'),
                      ),
                    if (state.syncError != null) ...[
                      Text(
                        state.syncError!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      TextButton(
                        onPressed: state.busy
                            ? null
                            : () => apiAction(context, state.refreshAccount),
                        child: const Text('회원정보·진행 중 이동 다시 불러오기'),
                      ),
                    ],
                    const Text(
                      '시스템 알림·백그라운드 위치 안내는 준비 중이에요.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ] else ...[
                    SectionHeader(
                      '정류장 미리보기',
                      action: '지도 보기',
                      onAction: () => _showStop(context),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus_outlined,
                                    color: AppColors.primary,
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${state.origin.name} 정류장',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const Text(
                                        '예시 정류장 · 도보 3분',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const StatusPill('시연 데이터'),
                              ],
                            ),
                          ),
                          const Divider(),
                          for (var i = 0; i < arrivals.length; i++) ...[
                            if (i > 0)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 18),
                                child: Divider(),
                              ),
                            _ArrivalRow(
                              arrival: arrivals[i],
                              color: i.isEven
                                  ? AppColors.primary
                                  : AppColors.blue,
                              onTap: () => _showStop(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const DemoNotice(),
                  ],
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이동에 필요한 순간만 알려드려요',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Text(
              AppScope.of(context).demoMode
                  ? '하차할 때, 환승 상황이 바뀔 때 안내 화면에서 확인할 수 있어요. 지금은 체험 버전으로 시스템 알림은 발송하지 않아요.'
                  : '진행 중 이동의 상태와 평가를 안내 화면에서 확인할 수 있어요. 하차 임박·환승 시스템 알림은 준비 중이에요.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            if (AppScope.of(context).demoMode) const DemoNotice(),
          ],
        ),
      ),
    ),
  );

  Future<void> _showStop(BuildContext context) async {
    final state = AppScope.of(context);
    final pickDestination = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.origin.name} 정류장',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                '첫 승차 정류장 위치를 확인해 보세요.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              RouteMap(height: 200, origin: state.origin),
              const SizedBox(height: 18),
              const DemoNotice(message: '예시 정류장·도착 시간입니다. 실제 운행정보가 아닙니다.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('이곳에서 길찾기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (pickDestination == true && context.mounted) {
      await _pickPlace(context, false);
    }
  }
}

class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: SizedBox(
      height: 66,
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value ?? '도착지를 입력해 주세요',
              style: TextStyle(
                fontSize: 16,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                color: value == null ? AppColors.muted : AppColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ArrivalRow extends StatelessWidget {
  const _ArrivalRow({
    required this.arrival,
    required this.color,
    required this.onTap,
  });
  final StopArrival arrival;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Icon(Icons.directions_bus_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              arrival.routeNo,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              arrival.stopsAwayText,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Text(
            arrival.minutesText,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.muted,
            size: 15,
          ),
        ],
      ),
    ),
  );
}
