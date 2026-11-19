import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../data/bus_api.dart';
import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/api_action.dart';
import '../../widgets/app_card.dart';
import '../../widgets/data_reason.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/route_geometry.dart';
import '../../widgets/route_timeline.dart';
import '../../widgets/transfer_results.dart';

class LiveJourneyGuide extends StatelessWidget {
  const LiveJourneyGuide({super.key});
  Future<void> _board(
    BuildContext context,
    AppState state,
    Json leg, {
    bool correction = false,
  }) async {
    final journeyId = state.journeyId;
    final boarded = correction ? state.progress['boarded'] as Json? : null;
    if (journeyId == null || (correction && boarded == null)) return;
    final payload = await showDialog<Json>(
      context: context,
      builder: (_) =>
          _BoardingDialog(leg: leg, journeyId: journeyId, boarded: boarded),
    );
    if (payload == null || !context.mounted || state.journeyId != journeyId) {
      return;
    }
    await apiAction(
      context,
      () => state.sendJourneyEvent(correction ? 'correction' : 'board', {
        if (correction)
          'supersedesEventId': boarded?['eventId']
        else
          'legIndex': leg['legIndex'],
        ...payload,
      }),
    );
  }

  Future<void> _end(
    BuildContext context,
    AppState state, {
    required bool completed,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(completed ? '목적지에 도착했나요?' : '이동 안내를 종료할까요?'),
        content: Text(
          completed
              ? '도착 확인을 서버에 저장해요. 환승 결과는 이용기록에서도 입력·수정할 수 있어요.'
              : '취소 상태를 서버에 저장해요. 잠시 화면을 나가도 이동은 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 안내'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(completed ? '도착 확인' : '안내 종료'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) {
      return;
    }
    if (await apiAction(
          context,
          () => state.sendJourneyEvent(
            completed ? 'completed' : 'cancelled',
            completed ? {} : {'reason': 'user_requested'},
          ),
        ) &&
        context.mounted) {
      Navigator.popUntil(
        context,
        (r) => r.settings.name == AppRoutes.main || r.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final route = state.activeRoute;
    if (route == null || state.journey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('이동 안내')),
        body: const EmptyState(
          icon: Icons.route_outlined,
          title: '진행 중인 이동이 없어요',
          message: '이동이 종료되었거나 로그인이 필요해요.',
        ),
      );
    }
    final progress = state.progress;
    final boarded = progress['boarded'] as Json?;
    final onboard = state.journey!['movementState'] == 'onboard';
    final index = onboard
        ? (boarded?['legIndex'])
        : progress['nextBusLegIndex'];
    final leg = route.busLegs.where((l) => l['legIndex'] == index).firstOrNull;
    final guidance = state.guidance;
    final arrival = guidance?['arrival'] as Json?;
    final next = guidance?['nextBoarding'] as Json?;
    final alightEta = guidance?['onboard']?['alightEta'] as Json?;
    final mismatched =
        boarded != null &&
        (boarded['matchesPlannedRoute'] == false ||
            (leg != null &&
                (boarded['patternKey'] != leg['patternKey'] ||
                    boarded['directionCode'] !=
                        leg['board']?['directionCode'])));
    final title = leg == null
        ? '목적지까지 마지막 도보로 이동해요'
        : onboard
        ? (mismatched
              ? '확인한 버스로 이동 중이에요'
              : '${leg['route']?['routeNo'] ?? ''}번 버스로 이동 중이에요')
        : '${leg['board']?['name'] ?? '승차 정류소'}에서 버스에 탑승해요';
    return Scaffold(
      appBar: AppBar(
        title: const Text('함께 가는 중'),
        actions: [
          IconButton(
            tooltip: '서버 상태 새로고침',
            onPressed: state.busy
                ? null
                : () => apiAction(
                    context,
                    () => state.restoreJourney(state.journeyId!),
                  ),
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: state.busy || state.hasPendingEvent
                ? null
                : () => _end(context, state, completed: false),
            child: const Text('안내 종료'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            state.streamConnected
                ? '실시간 안내 연결됨'
                : state.streamError ?? '실시간 안내 연결 중…',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (leg != null && onboard)
            AppCard(
              color: AppColors.amberLight,
              child: Text(
                mismatched
                    ? '탑승 정보가 계획과 달라 하차 안내를 확인할 수 없어요.\n계획 하차: ${leg['alight']?['name'] ?? '미확인'} · 실제 경유 여부를 확인해 주세요.'
                    : '하차: ${leg['alight']?['name'] ?? '하차 정류소'}\n남은 정류장 수·하차 임박 알림은 아직 제공하지 않아요.',
              ),
            ),
          if (state.hasPendingEvent)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('전송 결과를 확인하지 못했어요. 같은 요청을 안전하게 다시 확인할 수 있어요.'),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => apiAction(context, state.retryPendingEvent),
                    child: const Text('이동 확인 재전송'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guidance == null ? '최신 상태로 다시 계산 중이에요.' : '남은 이동 평가',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '평가 시점 남은 시간: ${mismatched ? '확인 불가' : _minutes(arrival?['remainingSeconds'])}',
                ),
                if (!mismatched && arrival?['plannedArrivalAt'] != null)
                  Text('목적지 도착 예상: ${_time(arrival!['plannedArrivalAt'])}'),
                if (leg == null)
                  Text('마지막 도보: ${_minutes(arrival?['finalWalkSeconds'])}'),
                if (onboard && !mismatched) ...[
                  Text(
                    '하차 정류소 도착 예상: ${_time(alightEta?['predictedArrivalAt'])}',
                  ),
                  if (alightEta != null)
                    Text(
                      '평가 시점 하차까지 ${_minutes(alightEta['waitSeconds'])} · ${etaSourceLabel(alightEta)}',
                    ),
                  Text('확인한 차량: ${boarded?['vehicleId'] ?? '미확인'}'),
                ],
                if (!onboard && leg != null)
                  Text('다음 버스 대기: ${_minutes(next?['waitSeconds'])}'),
                if (!onboard && leg != null) ...[
                  Text('승차 정류소 도착 예상: ${_time(next?['predictedArrivalAt'])}'),
                  Text('평가한 차량: ${next?['vehicle']?['vehicleId'] ?? '미확인'}'),
                  if (next?['upcoming'] case final List upcoming)
                    for (final eta in upcoming.cast<Json>())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '다가오는 버스 · ${_time(eta['predictedArrivalAt'])} · 차량 ${eta['vehicleId'] ?? '미확인'}\n${etaSourceLabel(eta)} · 평가 시점 ${_minutes(eta['waitSeconds'])}',
                        ),
                      ),
                ],
                if (leg != null && !onboard)
                  Text('승차 여유: ${secondsLabel(next?['slackSeconds'])}'),
                if (!mismatched)
                  if (arrival?['transferProbabilities']
                      case final List probabilities)
                    for (var i = 0; i < probabilities.length; i++)
                      Text(
                        '남은 ${i + 1}번째 환승: ${_probability(probabilities[i])}',
                      ),
                if (mismatched)
                  const Text('확인한 노선·방향이 계획과 달라 현재 경로의 예측을 사용할 수 없어요.'),
                if (guidance?['evaluatedAt'] != null)
                  Text(
                    '평가 시각: ${_time(guidance!['evaluatedAt'])}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final reason in List<String>.from(
                  guidance?['reasonCodes'] ?? [],
                ).map(dataReason).toSet())
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      reason,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                if (onboard)
                  TextButton(
                    onPressed:
                        state.busy || state.hasPendingEvent || leg == null
                        ? null
                        : () => _board(context, state, leg, correction: true),
                    child: const Text('탑승 노선·방향·차량 수정'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.busy
                ? null
                : () => apiAction(context, state.startLocationSharing),
            icon: const Icon(Icons.my_location),
            label: const Text('현재 위치 전송·안내에 사용'),
          ),
          if (state.locationError != null)
            Text(
              state.locationError!,
              style: const TextStyle(color: AppColors.error),
            ),
          const Text(
            '위치는 앱을 사용하는 동안 전송합니다. 백그라운드 위치·시스템 알림은 준비 중이며, 연결이 끊겨도 서버 이동은 유지됩니다.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          RouteGeometry(
            legs: route.legs,
            origin: route.origin,
            destination: route.destination,
            api: state.api,
          ),
          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text('선택 당시 경로·환승 평가'),
            children: [RouteTimeline(route: route)],
          ),
          if ((state.journey!['transferResults'] as List? ?? [])
              .isNotEmpty) ...[
            const SizedBox(height: 24),
            TransferResults(journey: state.journey!),
          ],
          const SizedBox(height: 12),
          const Text(
            '버스를 놓쳤거나 목적지가 바뀌었을 때의 대체 경로 추천은 준비 중이에요.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton(
            onPressed: state.busy || state.hasPendingEvent
                ? null
                : () async {
                    if (leg == null) {
                      await _end(context, state, completed: true);
                    } else if (!onboard) {
                      await _board(context, state, leg);
                    } else {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('이 정류소에서 내렸나요?'),
                          content: Text(
                            '${leg['alight']?['name'] ?? '계획 하차 정류소'}에서 실제 하차한 뒤 확인해 주세요.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('하차 확인'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && context.mounted) {
                        await apiAction(
                          context,
                          () => state.sendJourneyEvent('alight', {
                            'legIndex': leg['legIndex'],
                            if (leg['alight']?['stopId'] != null)
                              'stopId': leg['alight']['stopId'],
                            if (leg['alight']?['seq'] != null)
                              'seq': leg['alight']['seq'],
                          }),
                        );
                      }
                    }
                  },
            child: Text(
              state.busy
                  ? '서버에 확인 중…'
                  : leg == null
                  ? '목적지 도착 확인'
                  : onboard
                  ? '이 정류소에서 내렸어요'
                  : '버스에 탑승했어요',
            ),
          ),
        ),
      ),
    );
  }
}

String? _suggestedVehicle(AppState state, Json leg) {
  final next = state.guidance?['nextBoarding'];
  if (next is! Map || next['legIndex'] != leg['legIndex']) return null;
  final routeId = next['routeId'];
  final pattern = next['patternKey'];
  if ((routeId != null && routeId != leg['route']?['id']) ||
      (pattern != null && pattern != leg['patternKey'])) {
    return null;
  }

  String? number(Object? value) {
    if (value is! String) return null;
    final plate = value.trim();
    return plate.isNotEmpty && plate.length <= 50 ? plate : null;
  }

  final evaluated = next['vehicle'];
  final selected = number(evaluated is Map ? evaluated['vehicleId'] : null);
  if (selected != null) return selected;

  final upcoming = next['upcoming'];
  if (upcoming is! List) return null;
  final plates = {
    for (final candidate in upcoming.whereType<Map>())
      ?number(candidate['vehicleId']),
  };
  return plates.length == 1 ? plates.single : null;
}

String _minutes(dynamic seconds) =>
    seconds is num ? '${minutesFromSeconds(seconds)}분' : '확인 불가';
String _probability(dynamic value) {
  final p = probabilityPercent(value);
  return p == null ? '확인 불가' : '$p% · ${transferProbabilityLabel(p)}';
}

String _time(dynamic value) {
  final t = DateTime.tryParse(value.toString())?.toLocal();
  return t == null
      ? '확인 불가'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _BoardingDialog extends StatefulWidget {
  const _BoardingDialog({
    required this.leg,
    required this.journeyId,
    this.boarded,
  });
  final Json leg;
  final String journeyId;
  final Json? boarded;
  @override
  State<_BoardingDialog> createState() => _BoardingDialogState();
}

class _BoardingDialogState extends State<_BoardingDialog> {
  final _number = TextEditingController();
  final _vehicle = TextEditingController();
  Json? _route, _pattern;
  List<Json> _routes = [], _patterns = [];
  bool _loading = false;
  bool _allowPrefill = true;
  String? _prefilledVehicle;
  String? _error;
  @override
  void initState() {
    super.initState();
    final plannedRoute = widget.leg['route'] as Json;
    final boarded = widget.boarded;
    _route = boarded == null || boarded['routeId'] == plannedRoute['id']
        ? plannedRoute
        : {'id': boarded['routeId']};
    _number.text = _route!['routeNo']?.toString() ?? '';
    if (boarded != null) {
      _pattern = {
        'patternKey': boarded['patternKey'],
        'directionCode': boarded['directionCode'],
      };
    }
    _vehicle.text = boarded?['vehicleId'] as String? ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (widget.boarded != null ||
        !_allowPrefill ||
        state.journeyId != widget.journeyId ||
        state.progress['nextBusLegIndex'] != widget.leg['legIndex']) {
      return;
    }
    final vehicle = _suggestedVehicle(state, widget.leg);
    if (vehicle == null) return;
    _allowPrefill = false;
    _prefilledVehicle = vehicle;
    _vehicle.text = vehicle;
  }

  @override
  void dispose() {
    _number.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  void _resetRouteSelection() {
    if (_vehicle.text.trim() == _prefilledVehicle) _vehicle.clear();
    _allowPrefill = false;
    _prefilledVehicle = null;
    _route = null;
    _pattern = null;
    _patterns = [];
  }

  Future<void> _lookup() async {
    final api = AppScope.of(context).api;
    setState(() {
      _loading = true;
      _error = null;
      _resetRouteSelection();
      _routes = [];
    });
    try {
      final result = await api.request(
        'GET',
        '/routes',
        query: {'routeNo': _number.text.trim()},
      );
      if (mounted) {
        setState(() => _routes = (result['items'] as List).cast<Json>());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(Json route) async {
    final api = AppScope.of(context).api;
    setState(() {
      _route = route;
      _pattern = null;
      _patterns = [];
      _loading = true;
      _error = null;
    });
    try {
      final result = await api.request(
        'GET',
        '/routes/${route['id']}/patterns',
      );
      if (mounted) {
        setState(() => _patterns = (result['items'] as List).cast<Json>());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    final vehicle = _vehicle.text.trim();
    Navigator.pop(context, <String, dynamic>{
      'routeId': _route!['id'],
      'patternKey': _pattern != null
          ? _pattern!['patternKey']
          : widget.leg['patternKey'],
      'directionCode': _pattern != null
          ? _pattern!['directionCode']
          : widget.leg['board']?['directionCode'],
      'vehicleId': vehicle.isEmpty ? null : vehicle,
      if (widget.boarded == null)
        'confirmation': vehicle.isEmpty
            ? 'user_selected_route'
            : vehicle == _prefilledVehicle
            ? 'user_confirmed'
            : 'user_entered_vehicle',
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final planned =
        _route?['id'] == widget.leg['route']?['id'] && _patterns.isEmpty;
    final canConfirm =
        _route != null && (planned || _pattern != null) && !_loading;
    return AlertDialog(
      title: const Text('탑승한 버스 직접 확인'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '계획: ${widget.leg['route']?['routeNo']}번 · ${widget.leg['board']?['name']} → ${widget.leg['alight']?['name']}',
              ),
              const SizedBox(height: 8),
              Text(
                _prefilledVehicle != null
                    ? '안내 차량번호를 미리 채웠어요. 노선·방향과 실제 차량번호를 확인해 주세요. 번호가 다르면 수정하고, 모르면 비워 두세요.'
                    : '노선·방향을 실제로 확인한 뒤 저장해 주세요. 차량번호를 모르면 비워 두세요.',
              ),
              if (widget.boarded == null &&
                  _allowPrefill &&
                  state.guidance == null)
                const Text('도착 예정 차량번호를 확인 중이에요.'),
              if (widget.boarded != null)
                const Text(
                  '차량번호만 수정하면 저장된 노선·방향을 유지해요. 노선·방향을 바꾸려면 번호로 다시 검색해 주세요.',
                ),
              TextField(
                controller: _number,
                onChanged: (_) => setState(_resetRouteSelection),
                decoration: const InputDecoration(labelText: '버스 번호'),
                maxLength: 30,
              ),
              TextButton(
                onPressed: _loading ? null : _lookup,
                child: const Text('다른 노선 검색'),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              for (final route in _routes)
                ListTile(
                  title: Text(
                    '${route['routeNo']} · ${route['startName']} → ${route['endName']}',
                  ),
                  selected: _route?['id'] == route['id'],
                  onTap: _loading ? null : () => _select(route),
                ),
              for (final pattern in _patterns)
                ListTile(
                  title: Text(
                    '${pattern['firstStop']?['name']} → ${pattern['lastStop']?['name']}',
                  ),
                  selected: _pattern == pattern,
                  onTap: () => setState(() => _pattern = pattern),
                ),
              TextField(
                controller: _vehicle,
                onChanged: (_) {
                  if (_allowPrefill) setState(() => _allowPrefill = false);
                },
                maxLength: 50,
                decoration: const InputDecoration(labelText: '실제 차량번호 (선택)'),
              ),
              const Text(
                '노선·방향 확인 불가 응답의 서버 저장은 아직 지원하지 않아요. 확인이 어려우면 안내를 유지해 주세요.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('지금은 확인하기 어려워요'),
        ),
        FilledButton(
          onPressed: canConfirm ? _confirm : null,
          child: const Text('확인한 정보 저장'),
        ),
      ],
    );
  }
}
