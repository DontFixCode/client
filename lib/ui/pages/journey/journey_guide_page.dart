import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../models/journey_record.dart';
import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/route_card.dart';
import '../../widgets/route_map.dart';
import '../../widgets/status_pill.dart';

class JourneyGuidePage extends StatefulWidget {
  const JourneyGuidePage({super.key});

  @override
  State<JourneyGuidePage> createState() => _JourneyGuidePageState();
}

class _JourneyGuidePageState extends State<JourneyGuidePage> {
  Future<void> _offerFasterTransfer(AppState state) async {
    final route = state.activeRoute;
    final alternative = state.fasterTransfer;
    if (route == null || alternative == null) return;
    state.markTransferSuggestionSeen();
    final change = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatusPill('새 환승 제안', icon: Icons.alt_route_rounded),
              const SizedBox(height: 16),
              Text(
                '${route.minutes - alternative.minutes}분 더 빠른 환승 경로가 있어요',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: AppColors.primaryDark),
              ),
              const SizedBox(height: 8),
              Text(
                '${route.transferStop}에서 ${alternative.busNumbers.last}번으로 갈아타면 더 일찍 도착해요.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TransferOption(route: route, recommended: false),
                    const Divider(),
                    _TransferOption(route: alternative, recommended: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const DemoNotice(message: '새 환승 제안은 예시 운행정보로 체험해요'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('유지'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: Text('${alternative.busNumbers.last}번으로 변경'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (change == true && mounted && identical(state.activeRoute, route)) {
      state.acceptFasterTransfer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${alternative.busNumbers.last}번 환승 경로로 변경했어요.'),
        ),
      );
    }
  }

  Future<void> _nextDemoStop(AppState state) async {
    state.passDemoStop();
    if (!state.transferSuggestionSeen && state.fasterTransfer != null) {
      await _offerFasterTransfer(state);
    }
  }

  void _returnHome() {
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.main || route.isFirst,
    );
  }

  Future<void> _endJourney(AppState state) async {
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이동 안내를 종료할까요?'),
        content: const Text('완료하지 않은 이동은 기록에 저장되지 않아요. 잠시 나가려면 뒤로 가기를 눌러주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 안내받기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('안내 종료'),
          ),
        ],
      ),
    );
    if (end == true && mounted) {
      state.cancelJourney();
      _returnHome();
    }
  }

  Future<bool> _confirmBoarding(
    TravelRoute route, {
    bool connecting = false,
  }) async {
    final state = AppScope.of(context);
    final expected = connecting
        ? route.busNumbers.last
        : route.busNumbers.first;
    var number = state.confirmedBus ?? expected;
    var heading =
        state.confirmedDirection ??
        (connecting
            ? route.arrivalStop
            : route.transferStop ?? route.arrivalStop);
    final form = GlobalKey<FormState>();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '탑승한 버스를 확인해주세요',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '자동 식별을 대신하는 체험 화면이에요.\n버스 번호와 방향을 직접 확인하거나 수정할 수 있어요.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    initialValue: number,
                    onChanged: (value) => number = value,
                    decoration: const InputDecoration(
                      labelText: '탑승 노선',
                      prefixIcon: Icon(Icons.directions_bus_rounded),
                    ),
                    textInputAction: TextInputAction.next,
                    maxLength: 12,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '탑승한 버스 번호를 입력해주세요.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: heading,
                    onChanged: (value) => heading = value,
                    decoration: const InputDecoration(
                      labelText: '운행 방향',
                      prefixIcon: Icon(Icons.arrow_forward_rounded),
                    ),
                    maxLength: 40,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '버스의 운행 방향을 입력해주세요.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (form.currentState!.validate()) {
                          Navigator.pop(sheetContext, 'confirmed');
                        }
                      },
                      child: const Text('이 버스에 탑승했어요'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext, 'uncertain'),
                      child: const Text('지금은 확인하기 어려워요'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || result == null) {
      return false;
    }
    state.setBoardingInfo(
      bus: number.trim(),
      direction: heading.trim(),
      uncertain: result == 'uncertain',
    );
    return true;
  }

  Future<void> _missedBus(AppState state, TravelRoute route) async {
    final findAlternative = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.alt_route_rounded,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                '괜찮아요, 다른 길을 찾아볼게요',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                '현재 안내는 유지한 채 예시 경로를 다시 비교해요. 실제 위치에 따른 재탐색은 교통정보 연결 후 제공돼요.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('대체 경로 살펴보기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (findAlternative == true && mounted) {
      state.setOrigin(route.origin);
      state.setDestination(route.destination);
      Navigator.pushNamed(context, AppRoutes.results);
    }
  }

  Future<void> _complete(AppState state, TravelRoute route) async {
    JourneyOutcome? selected = route.transfers == 0
        ? JourneyOutcome.unknown
        : null;
    final result = await showModalBottomSheet<JourneyOutcome>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 이동은 어땠나요?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  route.transfers == 0
                      ? '환승 없는 이동을 완료했어요. 기록에 남겨둘게요.'
                      : '직접 알려주신 환승 결과를 이동 기록에 남겨요.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                if (route.transfers > 0)
                  ...JourneyOutcome.values.map(
                    (outcome) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => setSheetState(() => selected = outcome),
                        borderColor: selected == outcome
                            ? AppColors.primary
                            : AppColors.border,
                        color: selected == outcome
                            ? AppColors.primaryLight
                            : AppColors.surface,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              outcome == JourneyOutcome.success
                                  ? Icons.check_circle_outline_rounded
                                  : outcome == JourneyOutcome.missed
                                  ? Icons.schedule_rounded
                                  : Icons.help_outline_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                outcome.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (selected == outcome)
                              const Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(context, selected),
                    child: const Text('이동 완료하고 저장하기'),
                  ),
                ),
                const SizedBox(height: 12),
                const DemoNotice(message: '체험 기록은 앱을 종료하면 초기화돼요'),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      state.finishJourney(result);
      _returnHome();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('수고했어요! 이동 기록에 저장했어요.')));
    }
  }

  Future<void> _advance(AppState state, TravelRoute route) async {
    switch (state.guideStep) {
      case 1:
        if (await _confirmBoarding(route) && mounted) {
          state.setGuideStep(2);
        }
      case 2:
        state.setGuideStep(route.transfers == 0 ? 5 : 3);
      case 3:
        if (await _confirmBoarding(route, connecting: true) && mounted) {
          state.setGuideStep(4);
        }
      case 6:
        await _complete(state, route);
      default:
        state.advanceJourney();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final route = state.activeRoute;
    if (route == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('이동 안내')),
        body: EmptyState(
          icon: Icons.route_rounded,
          title: '진행 중인 이동이 없어요',
          message: '목적지를 정하고 나에게 맞는 경로를 찾아보세요.',
          action: FilledButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.main,
              (_) => false,
            ),
            child: const Text('길찾기 시작하기'),
          ),
        ),
      );
    }
    final step = state.guideStep;
    final predictionUnavailable = !state.boardingMatchesRoute;
    final riding = (step == 2 || step == 4) && !predictionUnavailable;
    final stages = route.transfers == 0
        ? [0, 1, 2, 5, 6]
        : [0, 1, 2, 3, 4, 5, 6];
    final stageIndex = stages.indexOf(step).clamp(0, stages.length - 1);
    final title = switch (step) {
      0 => '첫 정류장으로 걸어가요',
      1 => '${route.busNumbers.first}번 버스를 기다려요',
      2 => '${state.confirmedBus ?? route.busNumbers.first}번 버스로 이동 중이에요',
      3 => '이제 갈아탈 준비를 해요',
      4 => '${state.confirmedBus ?? route.busNumbers.last}번 버스로 이동 중이에요',
      5 => '목적지까지 조금만 더 걸어요',
      _ => '목적지에 도착했어요!',
    };
    final description = switch (step) {
      0 => '${route.boardingStop}까지\n천천히 걸어서 이동해주세요.',
      1 => '${route.transferStop ?? route.arrivalStop} 방향\n승차 전 버스 번호를 확인해주세요.',
      2 =>
        '${route.transferStop ?? route.arrivalStop}에서 내려주세요.\n하차 전 소지품을 챙겨주세요.',
      3 => '${route.transferStop}에서 내려\n${route.busNumbers.last}번 버스로 갈아타요.',
      4 => '${route.arrivalStop}에서 내려주세요.\n목적지가 가까워지고 있어요.',
      5 => '${route.destination.name}까지\n마지막 도보 구간을 따라가세요.',
      _ => '오늘도 버스로 함께해주셔서 고마워요.\n이동 결과를 기록해볼까요?',
    };
    final cta = switch (step) {
      0 => '정류장에 도착했어요',
      1 => '버스에 탑승했어요',
      2 => '하차 정류장에 도착했어요',
      3 => '연결 버스에 탑승했어요',
      4 => '버스에서 내렸어요',
      5 => '목적지에 도착했어요',
      _ => '이동 기록 남기기',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('함께 가는 중'),
        actions: [
          TextButton(
            onPressed: () => _endJourney(state),
            child: const Text('안내 종료'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (riding)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  key: const ValueKey('alightingBanner'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber.withValues(alpha: .16),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.directions_bus_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.remainingStops == 0
                                  ? '이번 정류장에서 하차'
                                  : '${state.remainingStops}정류장 후 하차',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step == 2
                                  ? route.transferStop ?? route.arrivalStop
                                  : route.arrivalStop,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const StatusPill(
                        '체험 안내',
                        icon: Icons.play_circle_outline_rounded,
                      ),
                      const Spacer(),
                      Text(
                        '${stageIndex + 1} / ${stages.length} 단계',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (stageIndex + 1) / stages.length,
                      minHeight: 5,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(color: AppColors.muted, height: 1.7),
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RouteMap(
                      height: 220,
                      originLabel: route.origin.name,
                      destinationLabel: route.destination.name,
                      activeStep: step,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    color: AppColors.primaryDark,
                    borderColor: AppColors.primaryDark,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              step == 6
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.directions_bus_rounded,
                              color: AppColors.lime,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                step == 6 ? '오늘의 이동' : '선택한 경로',
                                style: const TextStyle(
                                  color: AppColors.lime,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Text(
                              '예시 정보',
                              style: TextStyle(
                                color: AppColors.lime,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Text(
                          '${route.origin.name}  →  ${route.destination.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _GuideMetric(
                                label: '총 이동',
                                value: '${route.minutes}분',
                              ),
                            ),
                            Expanded(
                              child: _GuideMetric(
                                label: '환승 여유',
                                value: route.transfers == 0
                                    ? '환승 없음'
                                    : '${route.marginMinutes ?? '-'}분',
                              ),
                            ),
                            Expanded(
                              child: _GuideMetric(
                                label: '환승 가능성',
                                value: route.transfers == 0
                                    ? '해당 없음'
                                    : route.probability == null ||
                                          predictionUnavailable
                                    ? '확인 불가'
                                    : route.probabilityLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (step == 1) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '예시 도착 예상 ${route.waitMinutes}분\n${route.boardingStop}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (step == 2 || step == 4) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      color: state.boardingUncertain
                          ? AppColors.amberLight
                          : AppColors.surface,
                      child: Row(
                        children: [
                          Icon(
                            state.boardingUncertain
                                ? Icons.help_outline_rounded
                                : Icons.verified_outlined,
                            color: state.boardingUncertain
                                ? AppColors.amber
                                : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.boardingUncertain
                                      ? '탑승 정보 확인이 필요해요'
                                      : '${state.confirmedBus ?? (step == 2 ? route.busNumbers.first : route.busNumbers.last)}번 · 직접 확인',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (predictionUnavailable)
                                  const Text(
                                    '탑승 정보가 달라 환승 확률을 평가할 수 없어요.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                if (state.confirmedDirection != null)
                                  Text(
                                    '${state.confirmedDirection!} 방향',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _confirmBoarding(route, connecting: step == 4),
                            child: const Text('수정'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (step == 3) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.primaryLight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.swap_calls_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              route.probability == null
                                  ? '예시 차량 정보가 부족해요.\n환승 확률은 확인 불가로 표시해요.'
                                  : '예시 환승 여유 ${route.marginMinutes}분\n주변을 살피며 안전하게 이동해주세요.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '예시 데이터 · 버튼을 눌러 다음 단계를 체험해요',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '실시간 위치·운행정보와 하차 알림은 아직 연결되지 않았어요. 화면을 나가도 앱 실행 중에는 안내를 이어갈 수 있어요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (riding || state.fasterTransfer != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    if (riding)
                      TextButton.icon(
                        key: const ValueKey('nextDemoStopButton'),
                        onPressed: state.remainingStops > 0
                            ? () => _nextDemoStop(state)
                            : null,
                        icon: const Icon(Icons.skip_next_rounded, size: 17),
                        label: const Text('다음 정류장'),
                      ),
                    if (state.fasterTransfer != null)
                      TextButton.icon(
                        key: const ValueKey('previewFasterTransferButton'),
                        onPressed: () => _offerFasterTransfer(state),
                        icon: const Icon(Icons.alt_route_rounded, size: 17),
                        label: const Text('새 환승 경로'),
                      ),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _advance(state, route),
                  child: Text(cta),
                ),
              ),
              if (step == 1 || step == 3)
                TextButton(
                  onPressed: () => _missedBus(state, route),
                  child: const Text(
                    '버스를 놓쳤어요',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferOption extends StatelessWidget {
  const _TransferOption({required this.route, required this.recommended});
  final TravelRoute route;
  final bool recommended;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: recommended ? AppColors.primaryLight : AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BusNumberChip(route.busNumbers.last, blue: true),
              Text(
                recommended ? '새 추천' : '지금 경로',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TransferProbabilityPill(route.probability),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${route.transferStop} 환승 · 총 ${route.minutes}분',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            route.marginMinutes == null
                ? '환승 여유 확인 불가'
                : '환승 여유 ${route.marginMinutes}분',
            style: const TextStyle(color: AppColors.amber, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _GuideMetric extends StatelessWidget {
  const _GuideMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.lime, fontSize: 11)),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
